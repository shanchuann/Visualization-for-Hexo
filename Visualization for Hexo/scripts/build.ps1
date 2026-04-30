param(
    [string]$Configuration = "Debug",
    [string]$Platform = "x64",
    [string]$Toolset = "",
    [string]$VsDevCmd = "",
    [string]$QtInstall = "",
    [switch]$Clean,
    [switch]$SkipKill,
    [switch]$SkipDeployQt
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

function Find-WinDeployQt {
    if ($env:WINDEPLOYQT_EXE -and (Test-Path $env:WINDEPLOYQT_EXE)) {
        return $env:WINDEPLOYQT_EXE
    }

    $qtInstallDir = Resolve-QtInstallDir
    if ($qtInstallDir) {
        $candidate = Join-Path $qtInstallDir "bin\windeployqt.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $cmd = Get-Command windeployqt.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
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
        $all = Get-ChildItem -Path $commonQtRoot -Filter windeployqt.exe -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "msvc" }
        $candidate = $all |
            Where-Object { $_.FullName -match "msvc2022_64" } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if (-not $candidate) {
            $candidate = $all | Sort-Object FullName -Descending | Select-Object -First 1
        }
        if ($candidate) {
            return $candidate.FullName
        }
    }

    throw "windeployqt.exe not found. Install Qt or set WINDEPLOYQT_EXE."
}

function Import-VsDevEnv {
    param(
        [string]$VsDevCmdPath = "D:\Program Files\VScommunity\Common7\Tools\VsDevCmd.bat"
    )

    if (-not (Test-Path $VsDevCmdPath)) {
        Write-Host "VsDevCmd not found at $VsDevCmdPath"
        return $false
    }

    Write-Host "Loading Visual Studio developer environment from: $VsDevCmdPath"
    $output = & cmd.exe /c "call `"$VsDevCmdPath`" && set"
    foreach ($line in $output) {
        if ($line -and $line -match "=") {
            $parts = $line -split "=",2
            try {
                $name = $parts[0]
                $value = $parts[1]
                Set-Item -Path ("env:" + $name) -Value $value -ErrorAction SilentlyContinue
            } catch {
                # ignore parse errors
            }
        }
    }

    return $true
}

$projectPath = Join-Path $PSScriptRoot "..\Visualization for Hexo.vcxproj"

if (-not $SkipKill) {
    Get-Process -Name "Visualization for Hexo" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 300
}

if (-not (Get-Command msbuild.exe -ErrorAction SilentlyContinue)) {
    Write-Host "msbuild.exe not found in PATH. Attempting to load VS developer environment..."
    $vsPathToTry = $VsDevCmd
    if (-not $vsPathToTry) { $vsPathToTry = $env:VSDEV_CMD_PATH }
    if (-not $vsPathToTry) { $vsPathToTry = "D:\Program Files\VScommunity\Common7\Tools\VsDevCmd.bat" }

    if (-not (Import-VsDevEnv $vsPathToTry)) {
        throw "msbuild.exe not found. Please run in a VS Developer PowerShell or install Visual Studio Build Tools."
    }

    if (-not (Get-Command msbuild.exe -ErrorAction SilentlyContinue)) {
        throw "msbuild.exe still not found after loading VS dev env."
    }
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

if (-not $SkipDeployQt) {
    $root = Split-Path -Parent $PSScriptRoot
    $binDir = Join-Path $root "$Platform\$Configuration"
    $exePath = Join-Path $binDir "Visualization for Hexo.exe"
    if (-not (Test-Path $exePath)) {
        throw "build output not found: $exePath"
    }

    $windeployqt = Find-WinDeployQt
    $deployMode = if ($Configuration -match "Debug") { "--debug" } else { "--release" }
    $windeployqtArgs = @(
        $deployMode,
        "--qmldir", $root,
        "--force",
        $exePath
    )
    Write-Host "[build] windeployqt: $windeployqt"
    Write-Host "[build] windeployqt args: $($windeployqtArgs -join ' ')"
    & $windeployqt @windeployqtArgs
    if ($LASTEXITCODE -ne 0) {
        throw "windeployqt failed with exit code $LASTEXITCODE"
    }
}
