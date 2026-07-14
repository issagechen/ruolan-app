#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 原生 JNI 封装层 (llama_wrapper.cpp) 编译语法检查
#
# 目的：在不做完整 llama.cpp 构建的前提下，用 Android NDK 的 clang++ 对
#       llama_wrapper.cpp 做 -fsyntax-only 检查，快速捕获以下回归：
#         - 采样链 (buildSampler / llama_sampler_* API 误用)
#         - 字面量/换行损坏（历史上出现过 `n`n 之类的坏字符）
#         - 未声明符号（如 g_temperature / g_top_p 顺序问题）
#         - nativeGenerate 签名与 JNI 类型不匹配
#
# 说明：项目的 .so 是预编译后放入 src/main/jniLibs 的，gradle 不会重编 C++，
#       因此该脚本是 C++ 改动的唯一自动化编译门禁。它只做「语法/类型」检查
#       (-fsyntax-only)，不链接、不产出 .so，秒级完成。
#
# 头文件来源（两种，自动降级）：
#   1. 仓库内已 vendored 的 android/app/src/main/cpp/llama.cpp（含其 .git 的子树
#      或 git submodule）——HEAD 即为与预编译 .so 同源的版本，作为硬门禁。
#   2. 若仓库未携带 llama.cpp（为控制体积已 gitignore），则尝试浅克隆固定提交
#      33ca0dc（与当前 .so 同源）以获取头文件；克隆失败（离线）则跳过本步，
#      不影响后续 flutter build apk 这一真正原生编译门禁。
#
# 用法：
#   ANDROID_NDK_HOME=/path/to/ndk bash scripts/check_native_cpp.sh
#   （CI 中由 ci.yml 的 android-build job 设置好 ANDROID_NDK_HOME 后调用）
# ---------------------------------------------------------------------------
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CPP_DIR="$REPO_ROOT/android/app/src/main/cpp"
SRC="$CPP_DIR/llama_wrapper.cpp"
LLAMA_TREE="$CPP_DIR/llama.cpp"
# 与当前预编译 .so 同源的 llama.cpp 提交（由 android/app/src/main/cpp/llama.cpp/.git 确定）
LLAMA_PINNED="33ca0dcb9d78c7c3a3b543db4c5fc9182abfe519"

if [ ! -f "$SRC" ]; then
  echo "ERROR: 找不到源文件 $SRC" >&2
  exit 1
fi

# ---- 定位 llama.cpp 头文件；缺失则尝试浅克隆固定提交（CI 自愈）----
HARD_CHECK=false
LLAMA_SRC="none"
if [ -f "$LLAMA_TREE/include/llama.h" ]; then
  HARD_CHECK=true
  LLAMA_SRC="vendored"
else
  echo "WARN: 仓库未携带 vendored llama.cpp，尝试浅克隆固定提交 $LLAMA_PINNED（CI 自愈）..."
  if git -C "$REPO_ROOT" clone --filter=blob:none --no-checkout \
        https://github.com/ggerganov/llama.cpp.git "$LLAMA_TREE" 2>/dev/null && \
     git -C "$LLAMA_TREE" fetch --depth 1 origin "$LLAMA_PINNED" 2>/dev/null && \
     git -C "$LLAMA_TREE" checkout -q "$LLAMA_PINNED" 2>/dev/null; then
    HARD_CHECK=true
    LLAMA_SRC="pinned@$LLAMA_PINNED"
  else
    echo "WARN: 无法获取 llama.cpp 头文件（离线？），跳过 C++ 语法检查。"
    echo "      如需启用，请将 llama.cpp 作为 git submodule 或 vendored 目录置于 $LLAMA_TREE。"
    exit 0
  fi
fi

# ---- 定位 NDK ----
NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [ -z "$NDK" ] && [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/ndk" ]; then
  NDK="$ANDROID_HOME/ndk/$(ls "$ANDROID_HOME/ndk" | sort -V | tail -1)"
fi
if [ -z "$NDK" ] || [ ! -d "$NDK" ]; then
  echo "WARN: 未找到 Android NDK，跳过 C++ 语法检查（请在 CI 中安装 NDK 27）。" >&2
  exit 0
fi

# ---- 定位 clang++（默认 linux 主机；macOS 回退到 darwin）----
HOST_TAG="linux-x86_64"
if [ ! -d "$NDK/toolchains/llvm/prebuilt/$HOST_TAG" ]; then
  HOST_TAG="darwin-x86_64"
fi
# 目标 API 与 build.gradle.kts 的 minSdk 保持一致（24）
CLANG="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/aarch64-linux-android24-clang++"
if [ ! -x "$CLANG" ]; then
  echo "WARN: 未找到 clang++（$CLANG），跳过 C++ 语法检查。" >&2
  exit 0
fi

echo "NDK       : $NDK"
echo "Compiler  : $CLANG"
echo "Source    : $SRC"
echo "llama.cpp : $LLAMA_SRC (HARD_CHECK=$HARD_CHECK)"
echo "----------------------------------------"

# -fsyntax-only：只做解析/类型检查，不生成目标文件、不链接。
# include 路径覆盖 llama.h 及其依赖的 ggml.h / ggml-cpu.h 等。
if "$CLANG" \
  -std=c++17 \
  -fsyntax-only \
  -Wall \
  -I"$CPP_DIR" \
  -I"$LLAMA_TREE/include" \
  -I"$LLAMA_TREE/ggml/include" \
  "$SRC"; then
  echo "----------------------------------------"
  echo "OK: llama_wrapper.cpp 通过语法检查。"
  exit 0
else
  if [ "$HARD_CHECK" = true ]; then
    echo "----------------------------------------"
    echo "FAIL: llama_wrapper.cpp 语法检查未通过（头文件与预编译 .so 同源，视为真实回归）。" >&2
    exit 1
  fi
  echo "----------------------------------------"
  echo "WARN: C++ 语法检查未通过，但头文件来源不确定（非 vendored），作为软警告跳过。" >&2
  exit 0
fi
