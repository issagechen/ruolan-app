# llama.cpp Android 集成 Setup 脚本
# 在项目根目录执行此脚本

$ErrorActionPreference = "Stop"

$projectRoot = "D:\codex-project2\chat-agent-app2"
$cppDir = "$projectRoot\android\app\src\main\cpp"
$modelSource = "D:\codex-project2\本地大模型\DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf"
$modelTargetDir = "$projectRoot\assets\models"

Write-Host "=== llama.cpp Android Setup ===" -ForegroundColor Cyan

# Step 1: Clone llama.cpp
Write-Host "`n[1/3] Cloning llama.cpp..." -ForegroundColor Yellow
if (Test-Path "$cppDir\llama.cpp") {
    Write-Host "  llama.cpp already exists, pulling latest..."
    Push-Location "$cppDir\llama.cpp"
    git pull
    Pop-Location
} else {
    Push-Location $cppDir
    git clone --depth 1 https://github.com/ggerganov/llama.cpp.git
    Pop-Location
}

# Step 2: Copy model
Write-Host "`n[2/3] Copying model to assets..." -ForegroundColor Yellow
if (Test-Path $modelSource) {
    New-Item -ItemType Directory -Force -Path $modelTargetDir | Out-Null
    Copy-Item $modelSource $modelTargetDir -Force
    Write-Host "  Model copied to assets/models/"
} else {
    Write-Host "  WARNING: Model not found at $modelSource" -ForegroundColor Red
    Write-Host "  Please place your GGUF model in assets/models/model.gguf"
}

# Step 3: Verify CMake
Write-Host "`n[3/3] Verifying CMake setup..." -ForegroundColor Yellow
if (Test-Path "$cppDir\CMakeLists.txt") {
    Write-Host "  CMakeLists.txt found"
}
if (Test-Path "$cppDir\llama_wrapper.cpp") {
    Write-Host "  llama_wrapper.cpp found"
}

Write-Host "`n=== Setup complete ===" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor White
Write-Host "  1. Run: flutter clean"
Write-Host "  2. Run: flutter build apk --debug  (first build takes ~10-15 min)"
Write-Host "  3. Install APK on tablet"
