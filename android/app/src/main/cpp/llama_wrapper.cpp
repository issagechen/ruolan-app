#include <jni.h>
#include <string>
#include <thread>
#include <mutex>
#include <atomic>
#include <vector>
#include <chrono>
#include <cstdint>
#include <android/log.h>

#define TAG "llama_wrapper"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

#include "llama.cpp/include/llama.h"

static llama_model*       g_model = nullptr;
static llama_context*     g_ctx = nullptr;
static const llama_vocab* g_vocab = nullptr;
static llama_sampler*     g_sampler = nullptr;
static std::atomic<bool>  g_running{false};
static std::atomic<bool>  g_generating{false};
static std::mutex         g_mutex;
static bool               g_backend_inited = false;
static std::string        g_utf8_buf;

// 采样默认参数（仅模型加载时使用；每次推理会以调用方传入的 temperature/topP 重建）。
static float   g_temperature = 0.7f;
static float   g_top_p       = 0.9f;

static jmethodID g_on_token_method = nullptr;
static jmethodID g_on_done_method  = nullptr;
static jmethodID g_on_error_method = nullptr;
static JavaVM*   g_jvm = nullptr;
static jclass    g_clazz = nullptr;  // cached global reference

// ----- UTF-8 safe emission -----
static void emitTokenSafe(JNIEnv* env, const char* data, int len) {
    if (!g_on_token_method || !data || len <= 0) return;
    g_utf8_buf.append(data, len);

    size_t pos = 0;
    while (pos < g_utf8_buf.size()) {
        unsigned char c = (unsigned char)g_utf8_buf[pos];
        int clen = 1;
        if      ((c & 0x80) == 0x00) clen = 1;
        else if ((c & 0xE0) == 0xC0) clen = 2;
        else if ((c & 0xF0) == 0xE0) clen = 3;
        else if ((c & 0xF8) == 0xF0) clen = 4;
        else { pos++; continue; }

        if (pos + clen > g_utf8_buf.size()) break;

        std::string ch = g_utf8_buf.substr(pos, clen);
        jstring jtoken = env->NewStringUTF(ch.c_str());
        if (g_clazz) {
            env->CallStaticVoidMethod(g_clazz, g_on_token_method, jtoken);
        }
        env->DeleteLocalRef(jtoken);
        pos += clen;
    }
    if (pos > 0) g_utf8_buf.erase(0, pos);
}

static void flushUtf8(JNIEnv* env) {
    if (g_utf8_buf.empty() || !g_on_token_method) { g_utf8_buf.clear(); return; }
    jstring jtoken = env->NewStringUTF(g_utf8_buf.c_str());
    if (g_clazz) {
        env->CallStaticVoidMethod(g_clazz, g_on_token_method, jtoken);
    }
    env->DeleteLocalRef(jtoken);
    g_utf8_buf.clear();
}

static void emitDone(JNIEnv* env) {
    flushUtf8(env);
    if (!g_on_done_method) return;
    if (g_clazz) {
        env->CallStaticVoidMethod(g_clazz, g_on_done_method);
    }
}

static void emitError(JNIEnv* env, const char* error) {
    if (error) LOGE("%s", error);
    if (!g_on_error_method || !error) return;
    jstring jerror = env->NewStringUTF(error);
    if (g_clazz) {
        env->CallStaticVoidMethod(g_clazz, g_on_error_method, jerror);
    }
    env->DeleteLocalRef(jerror);
}

// 构建采样器链：temp<=0 时使用 greedy（确定性）；否则 temperature -> top-p -> dist。
// 注意：通过 llama_sampler_chain_add 加入的子采样器不要单独 free，
// 释放 chain 时会一并释放（见 llama.h 注释）。
static llama_sampler* buildSampler(float temp, float top_p) {
    llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
    llama_sampler* chain = llama_sampler_chain_init(sparams);
    if (!chain) return nullptr;
    if (temp <= 0.0f) {
        llama_sampler_chain_add(chain, llama_sampler_init_greedy());
    } else {
        llama_sampler_chain_add(chain, llama_sampler_init_temp(temp));
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(top_p, 1));
        const uint32_t seed =
            (uint32_t)std::chrono::steady_clock::now().time_since_epoch().count();
        llama_sampler_chain_add(chain, llama_sampler_init_dist(seed));
    }
    return chain;
}

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_ruolan_ruolan_1app_LlamaBridge_nativeLoadModel(
    JNIEnv* env, jclass, jstring modelPath, jint nCtx, jint nThreads) {

    std::lock_guard<std::mutex> lock(g_mutex);
    g_running = false;
    g_utf8_buf.clear();
    if (g_sampler) { llama_sampler_free(g_sampler); g_sampler = nullptr; }
    if (g_ctx)     { llama_free(g_ctx); g_ctx = nullptr; }
    g_vocab = nullptr;
    if (g_model)   { llama_model_free(g_model); g_model = nullptr; }

    const char* path = env->GetStringUTFChars(modelPath, nullptr);
    LOGI("=== Load: %s ===", path);

    if (!g_backend_inited) { llama_backend_init(); g_backend_inited = true; }

    llama_model_params mp = llama_model_default_params();
    mp.n_gpu_layers = 0;
    mp.use_mmap     = false;
    mp.use_mlock    = false;

    g_model = llama_model_load_from_file(path, mp);
    env->ReleaseStringUTFChars(modelPath, path);
    if (!g_model) { LOGE("model load failed"); return JNI_FALSE; }

    g_vocab = llama_model_get_vocab(g_model);
    if (!g_vocab || llama_vocab_n_tokens(g_vocab) <= 0) {
        llama_model_free(g_model); g_model = nullptr; g_vocab = nullptr;
        return JNI_FALSE;
    }
    LOGI("Vocab: %d", llama_vocab_n_tokens(g_vocab));

    int th = nThreads > 0 ? nThreads : 4;
    llama_context_params cp = llama_context_default_params();
    cp.n_ctx     = nCtx > 0 ? (uint32_t)nCtx : 2048;
    cp.n_batch   = 256;
    cp.n_ubatch  = 256;
    cp.n_seq_max = 1;
    cp.n_threads = th;
    cp.n_threads_batch = th;

    g_ctx = llama_init_from_model(g_model, cp);
    if (!g_ctx) {
        llama_model_free(g_model); g_model = nullptr; g_vocab = nullptr;
        return JNI_FALSE;
    }
    LOGI("Ctx: ctx=%u batch=%u ub=%u", llama_n_ctx(g_ctx), llama_n_batch(g_ctx), llama_n_ubatch(g_ctx));

    g_sampler = buildSampler(g_temperature, g_top_p);
    if (!g_sampler) {
        llama_free(g_ctx); g_ctx = nullptr;
        llama_model_free(g_model); g_model = nullptr; g_vocab = nullptr;
        return JNI_FALSE;
    }
    LOGI("Model ready");
    return JNI_TRUE;
}

JNIEXPORT void JNICALL
Java_com_ruolan_ruolan_1app_LlamaBridge_nativeGenerate(
    JNIEnv* env, jclass, jstring prompt, jint maxTokens, jfloat temperature, jfloat topP) {

    std::lock_guard<std::mutex> lock(g_mutex);

    if (!g_model || !g_ctx || !g_vocab || !g_sampler) {
        emitError(env, "Model not loaded");
        return;
    }

    // 按本次推理传入的 temperature / top-p 重建采样器链。
    llama_sampler_free(g_sampler);
    g_sampler = buildSampler(temperature, topP);
    if (!g_sampler) {
        emitError(env, "Sampler init failed");
        return;
    }

    g_running    = true;
    g_generating = true;

    // Clear KV cache to avoid conflicts with previous generation
    llama_memory_clear(llama_get_memory(g_ctx), true);

    const char* text = env->GetStringUTFChars(prompt, nullptr);
    int textLen = (int)strlen(text);
    LOGI("Generate: prompt_len=%d", textLen);

    // Two-pass tokenization
    int n_tokens = -llama_tokenize(g_vocab, text, textLen, nullptr, 0, true, true);
    if (n_tokens <= 0) {
        env->ReleaseStringUTFChars(prompt, text);
        emitError(env, "Tokenize failed: empty or error");
        g_running = false; g_generating = false;
        return;
    }

    std::vector<llama_token> tokens(n_tokens);
    int actual = llama_tokenize(g_vocab, text, textLen, tokens.data(), n_tokens, true, true);
    env->ReleaseStringUTFChars(prompt, text);

    if (actual < 0) {
        emitError(env, "Tokenize error");
        g_running = false; g_generating = false;
        return;
    }
    tokens.resize(actual);
    if (tokens.empty()) {
        emitError(env, "Empty prompt");
        g_running = false; g_generating = false;
        return;
    }
    LOGI("Tokens: %zu", tokens.size());

    int n_ctx    = (int)llama_n_ctx(g_ctx);
    int n_ubatch = (int)llama_n_ubatch(g_ctx);
    if (n_ctx <= 0 || n_ubatch <= 0) {
        emitError(env, "Bad context");
        g_running = false; g_generating = false;
        return;
    }

    int n_past    = 0;
    int n_predict = maxTokens > 0 ? maxTokens : 512;

    if ((int)tokens.size() + n_predict > n_ctx) {
        int trim = (int)tokens.size() + n_predict - n_ctx + 8;
        if (trim >= (int)tokens.size()) trim = (int)tokens.size() - 1;
        if (trim > 0) tokens.erase(tokens.begin(), tokens.begin() + trim);
    }

    // ---- eval prompt ----
    for (size_t i = 0; i < tokens.size() && g_running; i += n_ubatch) {
        int n_eval = (int)(tokens.size() - i);
        if (n_eval > n_ubatch) n_eval = n_ubatch;

        llama_batch batch = llama_batch_get_one(tokens.data() + i, n_eval);
        if (!batch.token) {
            emitError(env, "Batch failed");
            g_running = false; g_generating = false;
            return;
        }
        for (int j = 0; j < n_eval; j++) {
            if (batch.pos)       batch.pos[j]       = n_past + j;
            if (batch.n_seq_id)  batch.n_seq_id[j]  = 1;
            if (batch.seq_id && batch.seq_id[j]) batch.seq_id[j][0] = 0;
            if (batch.logits)    batch.logits[j]    = false;
        }
        if (batch.logits) batch.logits[n_eval - 1] = true;
        batch.n_tokens = n_eval;

        int ret = llama_decode(g_ctx, batch);
        // batch from llama_batch_get_one - no free needed
        if (ret < 0) {
            char buf[128];
            snprintf(buf, sizeof(buf), "Decode err: ret=%d pos=%d/%zu", ret, n_past, tokens.size());
            emitError(env, buf);
            g_running = false; g_generating = false;
            return;
        }
        n_past += n_eval;
    }
    if (!g_running) { g_generating = false; return; }

    // ---- generate ----
    int generated = 0;
    while (g_running && generated < n_predict) {
        llama_token token = llama_sampler_sample(g_sampler, g_ctx, -1);
        if (!g_running) break;

        if (token == llama_vocab_eos(g_vocab) || token == llama_vocab_eot(g_vocab)) break;

        int n_vocab = llama_vocab_n_tokens(g_vocab);
        if (token < 0 || token >= n_vocab) {
            char buf[64];
            snprintf(buf, sizeof(buf), "Bad token %d/%d", token, n_vocab);
            emitError(env, buf);
            break;
        }

        char piece[256];
        int n = llama_token_to_piece(g_vocab, token, piece, sizeof(piece) - 1, 0, true);
        if (n < 0) break;
        piece[n] = '\0';
        emitTokenSafe(env, piece, n);

        llama_batch batch = llama_batch_get_one(&token, 1);
        if (!batch.token) break;
        if (batch.pos)            batch.pos[0]       = n_past;
        if (batch.n_seq_id)       batch.n_seq_id[0]  = 1;
        if (batch.seq_id && batch.seq_id[0]) batch.seq_id[0][0] = 0;
        if (batch.logits)         batch.logits[0]    = true;
        batch.n_tokens     = 1;

        int ret = llama_decode(g_ctx, batch);
        // batch from llama_batch_get_one - no free needed
        if (ret < 0) {
            char ebuf[64];
            snprintf(ebuf, sizeof(ebuf), "Gen err: ret=%d", ret);
            emitError(env, ebuf);
            break;
        }
        n_past++; generated++;
    }

    emitDone(env);
    g_running    = false;
    g_generating = false;
    LOGI("Done: %d tokens", generated);
}

JNIEXPORT void JNICALL
Java_com_ruolan_ruolan_1app_LlamaBridge_nativeStop(JNIEnv*, jclass) {
    g_running = false;
}

JNIEXPORT void JNICALL
Java_com_ruolan_ruolan_1app_LlamaBridge_nativeUnload(JNIEnv*, jclass) {
    g_running = false;
    for (int i = 0; i < 200 && g_generating; i++)
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    std::lock_guard<std::mutex> lock(g_mutex);
    g_utf8_buf.clear();
    if (g_sampler) { llama_sampler_free(g_sampler); g_sampler = nullptr; }
    if (g_ctx)     { llama_free(g_ctx); g_ctx = nullptr; }
    g_vocab = nullptr;
    if (g_model)   { llama_model_free(g_model); g_model = nullptr; }
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
    g_jvm = vm;
    JNIEnv* env;
    if (vm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK) return JNI_ERR;
    jclass localClazz = env->FindClass("com/ruolan/ruolan_app/LlamaBridge");
    if (localClazz) {
        g_clazz = (jclass)env->NewGlobalRef(localClazz);
        g_on_token_method = env->GetStaticMethodID(localClazz, "onNativeToken", "(Ljava/lang/String;)V");
        g_on_done_method  = env->GetStaticMethodID(localClazz, "onNativeDone",  "()V");
        g_on_error_method = env->GetStaticMethodID(localClazz, "onNativeError", "(Ljava/lang/String;)V");
        env->DeleteLocalRef(localClazz);
    }
    return JNI_VERSION_1_6;
}
}