param(
    [string]$Configuration = "Release",
    [string]$Platform = "x64",
    [string]$Toolset = "",
    [string]$QtInstall = "",
    [string]$DistRoot = "",
    [switch]$Clean,
    [switch]$IncludePdb,
    [switch]$SkipKill
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $root
$proj = Join-Path $root "Visualization for Hexo.vcxproj"

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

if (-not $SkipKill) {
    Get-Process -Name "Visualization for Hexo" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 300
}

if (-not (Get-Command msbuild.exe -ErrorAction SilentlyContinue)) {
    throw "msbuild.exe not found. Please run in a VS Developer PowerShell or install Visual Studio Build Tools."
}

$targets = if ($Clean) { "Clean;Build" } else { "Build" }

$msbuildArgs = @(
    $proj,
    "/t:$targets",
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    "/v:minimal"
)

$qtInstallDir = Resolve-QtInstallDir
if ($qtInstallDir) {
    $msbuildArgs += "/p:QtInstall=$qtInstallDir"
    Write-Host "[package] QtInstall override: $qtInstallDir"
}

if ($Toolset) {
    $msbuildArgs += "/p:PlatformToolset=$Toolset"
    Write-Host "[package] PlatformToolset override: $Toolset"
}

function Find-WinDeployQt {
    if ($env:WINDEPLOYQT_EXE -and (Test-Path $env:WINDEPLOYQT_EXE)) {
        return $env:WINDEPLOYQT_EXE
    }

    $cmd = Get-Command windeployqt.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $qtInstallDir = Resolve-QtInstallDir
    if ($qtInstallDir) {
        $candidate = Join-Path $qtInstallDir "bin\windeployqt.exe"
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
& msbuild @msbuildArgs
if ($LASTEXITCODE -ne 0) {
    throw "msbuild failed with exit code $LASTEXITCODE"
}

$binDir = Join-Path $root "$Platform\$Configuration"
$exe = Join-Path $binDir "Visualization for Hexo.exe"
if (-not (Test-Path $exe)) {
    Write-Warning "[package] executable not found at expected path: $exe"
    exit 1
}

$distRoot = if ($DistRoot) {
    $distRootCandidate = $DistRoot
    if (-not [System.IO.Path]::IsPathRooted($DistRoot)) {
        $distRootCandidate = Join-Path $root $DistRoot
    }
    if (Test-Path $distRootCandidate) {
        (Resolve-Path $distRootCandidate).Path
    } else {
        $distRootCandidate
    }
} else {
    Join-Path $root "dist"
}

$null = New-Item -ItemType Directory -Path $distRoot -Force
$packageDir = Join-Path $distRoot "Visualization-for-Hexo-$Configuration-$Platform"
$zipPath = Join-Path $distRoot "Visualization-for-Hexo-$Configuration-$Platform.zip"

if (Test-Path $packageDir) {
    Remove-Item -Recurse -Force $packageDir
}
New-Item -ItemType Directory -Path $packageDir | Out-Null

Copy-Item -Path $exe -Destination (Join-Path $packageDir "Visualization for Hexo.exe") -Force

if ($IncludePdb) {
    $pdb = Join-Path $binDir "Visualization for Hexo.pdb"
    if (Test-Path $pdb) {
        Copy-Item -Path $pdb -Destination (Join-Path $packageDir "Visualization for Hexo.pdb") -Force
    }
}

$docs = @(
    Join-Path $repoRoot "README.md",
    Join-Path $repoRoot "LICENSE",
    Join-Path $repoRoot "LICENSE.txt"
) | Where-Object { Test-Path $_ } | Select-Object -Unique

foreach ($doc in $docs) {
    Copy-Item -Path $doc -Destination (Join-Path $packageDir (Split-Path -Leaf $doc)) -Force
}

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
