param(
    [string]$Configuration = "Debug",
    [string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

$projectPath = Join-Path $PSScriptRoot "..\Visualization for Hexo.vcxproj"

Get-Process -Name "Visualization for Hexo" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300

msbuild $projectPath /t:Build /p:Configuration=$Configuration /p:Platform=$Platform
