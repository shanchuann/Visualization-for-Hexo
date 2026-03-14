param(
    [string]$Configuration = "Debug",
    [string]$Platform = "x64",
    [string]$Toolset = "",
    [string]$QtInstall = "",
    [switch]$Clean,
    [switch]$SkipKill
)

$ErrorActionPreference = "Stop"

function Resolve-QtInstallDir {
    if ($QtInstall) {
        if (-not (Test-Path $QtInstall)) {
            throw "QtInstall path not found: $QtInstall"
        }
        return (Resolve-Path $QtInstall).Path
    }

    if ($env:QT_ROOT_DIR -and (Test-Path $env:QT_ROOT_DIR)) {
        return (Resolve-Path $env:QT_ROOT_DIR).Path
    }

    if ($env:Qt6_DIR -and (Test-Path $env:Qt6_DIR)) {
        $qt6Dir = (Resolve-Path $env:Qt6_DIR).Path
        # .../msvc2022_64/lib/cmake/Qt6 -> .../msvc2022_64
        return (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $qt6Dir)))
    }

    if ($env:QTDIR -and (Test-Path $env:QTDIR)) {
        return (Resolve-Path $env:QTDIR).Path
    }

    return $null
}

$projectPath = Join-Path $PSScriptRoot "..\Visualization for Hexo.vcxproj"

if (-not $SkipKill) {
    Get-Process -Name "Visualization for Hexo" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 300
}

if (-not (Get-Command msbuild.exe -ErrorAction SilentlyContinue)) {
    throw "msbuild.exe not found. Please run in a VS Developer PowerShell or install Visual Studio Build Tools."
}

$targets = if ($Clean) { "Clean;Build" } else { "Build" }

$msbuildArgs = @(
    $projectPath,
    "/t:$targets",
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    "/v:minimal"
)

$qtInstallDir = Resolve-QtInstallDir
if ($qtInstallDir) {
    $msbuildArgs += "/p:QtInstall=$qtInstallDir"
    Write-Host "[build] QtInstall override: $qtInstallDir"
}

if ($Toolset) {
    $msbuildArgs += "/p:PlatformToolset=$Toolset"
    Write-Host "[build] PlatformToolset override: $Toolset"
}

Write-Host "[build] build $Configuration|$Platform"
& msbuild @msbuildArgs
if ($LASTEXITCODE -ne 0) {
    throw "msbuild failed with exit code $LASTEXITCODE"
}
