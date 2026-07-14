$ErrorActionPreference = "Stop"
$ninja = "C:\Users\issage\AppData\Local\Android\Sdk\cmake\3.22.1\bin\ninja.exe"
$jniLibs = "D:\codex-project2\chat-agent-app2\android\app\src\main\jniLibs\arm64-v8a"
$buildDir = "D:\codex-project2\chat-agent-app2\android\app\src\main\cpp\build_arm64"
$projectDir = "D:\codex-project2\chat-agent-app2"

Write-Host "=== 1/4 Clean rebuild native ===" -ForegroundColor Cyan
# Touch source to force rebuild
(Get-Item "$projectDir\android\app\src\main\cpp\llama_wrapper.cpp").LastWriteTime = Get-Date

# Run ninja
Push-Location $buildDir
& $ninja llama_wrapper -j 8
if ($LASTEXITCODE -ne 0) { throw "Ninja build failed" }
Pop-Location
Write-Host "Build OK" -ForegroundColor Green

Write-Host "`n=== 2/4 Copy .so to jniLibs ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $jniLibs | Out-Null

# Copy wrapper .so
Copy-Item "$buildDir\libllama_wrapper.so" -Destination $jniLibs -Force

# Copy dependent .so files from build_arm64/bin/
$binDir = "$buildDir\bin"
if (Test-Path $binDir) {
    Get-ChildItem "$binDir\*.so" | ForEach-Object {
        Copy-Item $_.FullName -Destination $jniLibs -Force
        Write-Host "  Copied: $($_.Name) ($([math]::Round($_.Length/1MB,1))MB)"
    }
}

Write-Host "  libllama_wrapper.so ($([math]::Round((Get-Item "$jniLibs\libllama_wrapper.so").Length/1MB,1))MB)"
Write-Host "Copy OK" -ForegroundColor Green

Write-Host "`n=== 3/4 Verify no old error strings ===" -ForegroundColor Cyan
$bytes = [System.IO.File]::ReadAllBytes("$jniLibs\libllama_wrapper.so")
$text = [System.Text.Encoding]::ASCII.GetString($bytes)
if ($text -match "Decode failed") {
    Write-Host "WARNING: 'Decode failed' still in .so - build may be stale!" -ForegroundColor Red
} else {
    Write-Host "OK: Old error strings not found" -ForegroundColor Green
}
if ($text -match "Prompt decode error") {
    Write-Host "OK: New error code found" -ForegroundColor Green
} else {
    Write-Host "WARNING: New error codes not found" -ForegroundColor Red
}

Write-Host "`n=== 4/4 Build APK ===" -ForegroundColor Cyan
Push-Location $projectDir
flutter build apk --debug
Pop-Location

Write-Host "`n=== Done! ===" -ForegroundColor Green
$apk = Get-ChildItem "$projectDir\build\app\outputs\flutter-apk\app-debug.apk"
Write-Host "APK: $($apk.FullName) ($([math]::Round($apk.Length/1MB,1))MB)"
