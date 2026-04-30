param(
    [string]$Configuration = "Release",
    [string]$Platform = "x64",
    [string]$Toolset = "",
    [string]$VsDevCmd = "",
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
    try {
        Remove-Item -Recurse -Force $packageDir
    } catch {
        Write-Warning "[package] failed to remove existing package dir (in use). Will overwrite files in-place: $packageDir"
    }
}
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

Copy-Item -Path $exe -Destination (Join-Path $packageDir "Visualization for Hexo.exe") -Force

if ($IncludePdb) {
    $pdb = Join-Path $binDir "Visualization for Hexo.pdb"
    if (Test-Path $pdb) {
        Copy-Item -Path $pdb -Destination (Join-Path $packageDir "Visualization for Hexo.pdb") -Force
    }
}

$docs = @(
    (Join-Path $repoRoot "README.md")
    (Join-Path $repoRoot "LICENSE")
    (Join-Path $repoRoot "LICENSE.txt")
) | Where-Object { Test-Path $_ } | Select-Object -Unique

foreach ($doc in $docs) {
    Copy-Item -Path $doc -Destination (Join-Path $packageDir (Split-Path -Leaf $doc)) -Force
}

$windeployqt = Find-WinDeployQt
Write-Host "[package] windeployqt: $windeployqt"

$deployMode = if ($Configuration -match "Debug") { "--debug" } else { "--release" }
$windeployqtArgs = @(
    $deployMode,
    "--qmldir", $root,
    "--force",
    (Join-Path $packageDir "Visualization for Hexo.exe")
)
Write-Host "[package] windeployqt args: $($windeployqtArgs -join ' ')"
& $windeployqt @windeployqtArgs
if ($LASTEXITCODE -ne 0) {
    throw "windeployqt failed with exit code $LASTEXITCODE"
}

# Ensure Qt WebEngine resources, locales, and QML are present in the package (defensive copy)
function Copy-IfExists {
    param(
        [string]$src,
        [string]$dst
    )
    if (-not (Test-Path $src)) {
        return
    }
    Write-Host "[package] copying: $src -> $dst"
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force
    try {
        $srcItem = Get-Item -Path $src
        if ($srcItem.PSIsContainer -and (Test-Path $dst)) {
            # Merge directory contents to avoid PowerShell nesting sub-dirs
            Get-ChildItem -Path $src | ForEach-Object {
                $childDst = Join-Path $dst $_.Name
                if ($_.PSIsContainer) {
                    if (-not (Test-Path $childDst)) {
                        $null = New-Item -ItemType Directory -Path $childDst -Force
                    }
                    robocopy $_.FullName $childDst /E /NFL /NDL /NJH /NJS /NP 2>&1 | Out-Null
                } else {
                    Copy-Item -Path $_.FullName -Destination $childDst -Force
                }
            }
        } else {
            Copy-Item -Path $src -Destination $dst -Recurse -Force
        }
    } catch {
        Write-Warning ([string]::Format("[package] failed to copy {0}: {1}", $src, $_.Exception.Message))
    }
}

if ($qtInstallDir) {
    # qtwebengine locales — copy to both locations that main.cpp searches
    $srcLocales = Join-Path $qtInstallDir "translations\qtwebengine_locales"
    Copy-IfExists -src $srcLocales -dst (Join-Path $packageDir "resources\qtwebengine_locales")
    Copy-IfExists -src $srcLocales -dst (Join-Path $packageDir "translations\qtwebengine_locales")

    # important resources: icudtl, v8 snapshot, qtwebengine pak files
    $qtResourcesDirCandidates = @(
        (Join-Path $qtInstallDir "resources"),
        (Join-Path $qtInstallDir "lib\resources"),
        (Join-Path $qtInstallDir "lib")
    )

    $dstResRoot = Join-Path $packageDir "resources"
    New-Item -ItemType Directory -Path $dstResRoot -Force | Out-Null

    foreach ($cand in $qtResourcesDirCandidates) {
        if (-not (Test-Path $cand)) { continue }
        Get-ChildItem -Path $cand -File -Filter "*qtwebengine*.pak" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-IfExists -src $_.FullName -dst (Join-Path $dstResRoot $_.Name)
        }
        Copy-IfExists -src (Join-Path $cand "icudtl.dat") -dst (Join-Path $dstResRoot "icudtl.dat")
        Copy-IfExists -src (Join-Path $cand "v8_context_snapshot.bin") -dst (Join-Path $dstResRoot "v8_context_snapshot.bin")
    }

    # Ensure QtWebEngineProcess is present (some setups miss it)
    $srcWebProc = Join-Path $qtInstallDir "bin\QtWebEngineProcess.exe"
    Copy-IfExists -src $srcWebProc -dst (Join-Path $packageDir "QtWebEngineProcess.exe")
}

# NOTE: Project QML files are embedded via qrc:/qt/qml/visualization for hexo/...
# Do NOT copy them into the package dir — windeployqt creates its own qml/
# folder for Qt QML plugins, and copying project sources on top can break
# the plugin layout (PowerShell Copy-Item -Recurse nests into sub-dirs when
# the destination already exists).

# Copy common MSVC runtime DLLs (vcruntime) into package so app can run without global install
$vcruntimeNames = @('vcruntime140.dll','vcruntime140_1.dll','msvcp140.dll','msvcp140_1.dll','msvcp140_2.dll')
$systemDirs = @(
    (Join-Path $env:windir 'System32'),
    (Join-Path $env:windir 'SysWOW64')
)

foreach ($name in $vcruntimeNames) {
    $found = $false
    $candidates = @()
    if ($qtInstallDir) { $candidates += (Join-Path $qtInstallDir "bin\$name") }
    $candidates += $systemDirs
    foreach ($cand in $candidates) {
        $full = if ((Test-Path $cand -PathType Leaf) -and ($cand -like "*\$name")) { $cand } else { Join-Path $cand $name }
        if (Test-Path $full) {
            Copy-IfExists -src $full -dst (Join-Path $packageDir $name)
            $found = $true
            break
        }
    }
    if (-not $found) {
        Write-Warning "[package] runtime DLL not found: $name"
    }
}

# Ensure vc_redist installer is included (if present in Qt install or system common locations)
$vcCandidates = @()
if ($qtInstallDir) { $vcCandidates += (Join-Path $qtInstallDir 'bin\vc_redist.x64.exe') }
$vcCandidates += (Join-Path $root 'vc_redist.x64.exe')
$vcCandidates += (Join-Path $repoRoot 'vc_redist.x64.exe')
foreach ($vc in $vcCandidates) {
    if (Test-Path $vc) {
        Copy-IfExists -src $vc -dst (Join-Path $packageDir 'vc_redist.x64.exe')
        break
    }
}

if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipPath -Force

Write-Host "[package] ready: $zipPath"
