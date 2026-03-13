param(
    [string]$Configuration = "Release",
    [string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$proj = Join-Path $root "Visualization for Hexo.vcxproj"

Write-Host "[package] build $Configuration|$Platform"
msbuild $proj /t:Build /p:Configuration=$Configuration /p:Platform=$Platform /v:minimal

$exe = Join-Path $root "x64/Release/Visualization for Hexo.exe"
if (-not (Test-Path $exe)) {
    Write-Warning "[package] executable not found at expected path: $exe"
    exit 1
}

Write-Host "[package] TODO: integrate windeployqt and installer generation"
Write-Host "[package] ready: $exe"
