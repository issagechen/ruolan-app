package com.ruolan.ruolan_app

import android.content.Context
import android.os.Environment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class LlamaBridge(
    private val context: Context,
    private val flutterEngine: FlutterEngine
) {
    companion object {
        init {
            System.loadLibrary("llama_wrapper")
        }

        private const val CHANNEL_NAME = "com.ruolan.llama/method"
        private const val EVENT_CHANNEL_NAME = "com.ruolan.llama/stream"

        interface TokenCallback {
            fun onToken(token: String)
            fun onDone()
            fun onError(error: String)
        }

        private var callback: TokenCallback? = null
        fun setCallback(cb: TokenCallback) { callback = cb }

        @JvmStatic fun onNativeToken(token: String) { callback?.onToken(token) }
        @JvmStatic fun onNativeDone() { callback?.onDone() }
        @JvmStatic fun onNativeError(error: String) { callback?.onError(error) }
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var eventSink: EventChannel.EventSink? = null
    private var isModelLoaded = false

    private val searchPaths = listOf(
        { File(context.filesDir, "models/model.gguf").absolutePath },
        { File(Environment.getExternalStorageDirectory(), "models/model.gguf").absolutePath },
        { "/sdcard/models/model.gguf" },
        { "/storage/emulated/0/models/model.gguf" }
    )

    init { setupChannels() }

    private fun setupChannels() {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                scope.launch {
                    try {
                        when (call.method) {
                            "loadModel" -> {
                                var modelPath = call.argument<String>("modelPath")
                                if (modelPath == null) modelPath = findOrCopyModel()
                                if (modelPath == null) {
                                    result.error("NOT_FOUND", "Model not found in any location", null)
                                    return@launch
                                }
                                val ctxSize = call.argument<Int>("ctxSize") ?: 4096
                                val nThreads = call.argument<Int>("nThreads") ?: 7
                                android.util.Log.i("LlamaBridge", "Loading: $modelPath")
                                val success = nativeLoadModel(modelPath, ctxSize, nThreads)
                                isModelLoaded = success
                                result.success(success)
                            }
                            "generate" -> {
                                if (!isModelLoaded) { result.error("NOT_LOADED", "Model not loaded", null); return@launch }
                                val temperature = call.argument<Double>("temperature") ?: 0.7
                                val topP = call.argument<Double>("topP") ?: 0.9
                                launch(Dispatchers.IO) {
                                    nativeGenerate(
                                        call.argument<String>("prompt") ?: "",
                                        call.argument<Int>("maxTokens") ?: 1024,
                                        temperature.toFloat(),
                                        topP.toFloat()
                                    )
                                }
                                result.success(true)
                            }
                            "stop" -> { nativeStop(); result.success(true) }
                            "unload" -> { nativeUnload(); isModelLoaded = false; result.success(true) }
                            "isLoaded" -> result.success(isModelLoaded)
                            "defaultModelPath" -> result.success(File(context.filesDir, "models/model.gguf").absolutePath)
                            "listModels" -> {
                                val models = mutableListOf<Map<String, Any>>()
                                val dirs = listOf(
                                    File(context.filesDir, "models"),
                                    File(Environment.getExternalStorageDirectory(), "models")
                                )
                                for (dir in dirs) {
                                    if (dir.exists() && dir.isDirectory) {
                                        dir.listFiles { f -> f.isFile && f.extension.equals("gguf", true) }
                                            ?.forEach { f ->
                                                models.add(mapOf(
                                                    "path" to f.absolutePath,
                                                    "name" to f.name,
                                                    "sizeBytes" to f.length()
                                                ))
                                            }
                                    }
                                }
                                result.success(models)
                            }
                            else -> result.notImplemented()
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("LlamaBridge", "Error", e)
                        result.error("ERROR", e.message, null)
                    }
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arg: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                    setCallback(object : TokenCallback {
                        override fun onToken(token: String) {
                            scope.launch(Dispatchers.Main) {
                                eventSink?.success(mapOf("type" to "token", "text" to token))
                            }
                        }
                        override fun onDone() {
                            scope.launch(Dispatchers.Main) {
                                eventSink?.success(mapOf("type" to "done"))
                            }
                        }
                        override fun onError(error: String) {
                            scope.launch(Dispatchers.Main) {
                                eventSink?.error("GEN_ERR", error, null)
                            }
                        }
                    })
                }
                override fun onCancel(arg: Any?) { eventSink = null; nativeStop() }
            })
    }

    private fun findOrCopyModel(): String? {
        for (provider in searchPaths) {
            try {
                val f = File(provider())
                if (f.exists() && f.length() > 100_000_000) {
                    android.util.Log.i("LlamaBridge", "Found: ${f.absolutePath} (${f.length()} bytes)")
                    return if (f.absolutePath.startsWith(context.filesDir.absolutePath))
                        f.absolutePath else copyToInternal(f)
                }
            } catch (e: Exception) {
                android.util.Log.w("LlamaBridge", "Search failed: ${e.message}")
            }
        }
        return null
    }

    private fun copyToInternal(src: File): String? {
        try {
            val destDir = File(context.filesDir, "models")
            destDir.mkdirs()
            val dest = File(destDir, "model.gguf")
            if (dest.exists() && dest.length() == src.length()) return dest.absolutePath
            android.util.Log.i("LlamaBridge", "Copying model...")
            FileInputStream(src).use { cin ->
                FileOutputStream(dest).use { cout ->
                    val buf = ByteArray(8192); var r: Int; var total = 0L
                    while (cin.read(buf).also { r = it } != -1) { cout.write(buf, 0, r); total += r }
                    android.util.Log.i("LlamaBridge", "Copied $total bytes")
                }
            }
            return dest.absolutePath
        } catch (e: Exception) {
            android.util.Log.e("LlamaBridge", "Copy failed", e)
            return null
        }
    }

    fun destroy() { scope.cancel(); nativeUnload() }
    private external fun nativeLoadModel(modelPath: String, nCtx: Int, nThreads: Int): Boolean
    private external fun nativeGenerate(prompt: String, maxTokens: Int, temperature: Float, topP: Float)
    private external fun nativeStop()
    private external fun nativeUnload()
}
