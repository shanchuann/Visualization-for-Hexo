param(
    [string]$Configuration = "Release",
    [string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$proj = Join-Path $root "Visualization for Hexo.vcxproj"

$msbuildArgs = @(
    $proj,
    "/t:Build",
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    "/v:minimal"
)

if ($env:Qt6_DIR) {
    $qt6Dir = Resolve-Path $env:Qt6_DIR
    $qtRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $qt6Dir))
    $msbuildArgs += "/p:QtInstall=$qtRoot"
    Write-Host "[package] QtInstall override from Qt6_DIR: $qtRoot"
}

function Find-WinDeployQt {
    if ($env:WINDEPLOYQT_EXE -and (Test-Path $env:WINDEPLOYQT_EXE)) {
        return $env:WINDEPLOYQT_EXE
    }

    $cmd = Get-Command windeployqt.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    if ($env:Qt6_DIR) {
        $qt6Dir = Resolve-Path $env:Qt6_DIR
        $qtRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $qt6Dir))
        $candidate = Join-Path $qtRoot "bin\windeployqt.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $qmake = Get-Command qmake.exe -ErrorAction SilentlyContinue
    if ($qmake) {
        $candidate = Join-Path (Split-Path -Parent $qmake.Source) "windeployqt.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $commonQtRoot = "D:\Qt"
    if (Test-Path $commonQtRoot) {
        $candidate = Get-ChildItem -Path $commonQtRoot -Filter windeployqt.exe -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "msvc" } |
            Select-Object -First 1
        if ($candidate) {
            return $candidate.FullName
        }
    }

    throw "windeployqt.exe not found. Install Qt or set WINDEPLOYQT_EXE."
}

Write-Host "[package] build $Configuration|$Platform"
msbuild @msbuildArgs

$exe = Join-Path $root "x64/$Configuration/Visualization for Hexo.exe"
if (-not (Test-Path $exe)) {
    Write-Warning "[package] executable not found at expected path: $exe"
    exit 1
}

$distRoot = Join-Path $root "dist"
$packageDir = Join-Path $distRoot "Visualization-for-Hexo-$Configuration-$Platform"
$zipPath = Join-Path $distRoot "Visualization-for-Hexo-$Configuration-$Platform.zip"

if (Test-Path $packageDir) {
    Remove-Item -Recurse -Force $packageDir
}
New-Item -ItemType Directory -Path $packageDir | Out-Null

Copy-Item -Path $exe -Destination (Join-Path $packageDir "Visualization for Hexo.exe") -Force

$windeployqt = Find-WinDeployQt
Write-Host "[package] windeployqt: $windeployqt"

& $windeployqt --release --qmldir $root (Join-Path $packageDir "Visualization for Hexo.exe")
if ($LASTEXITCODE -ne 0) {
    throw "windeployqt failed with exit code $LASTEXITCODE"
}

if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipPath -Force

Write-Host "[package] ready: $zipPath"
