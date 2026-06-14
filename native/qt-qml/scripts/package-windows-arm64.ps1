$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$projectDir = Join-Path $repoRoot 'native\qt-qml'
$buildDir = Join-Path $projectDir 'build\windows-arm64'
$packageRoot = Join-Path $buildDir 'package'
$appDir = Join-Path $packageRoot 'FloatingCountdown'
$releaseDir = Join-Path $repoRoot 'release-native'
$zipPath = Join-Path $releaseDir 'FloatingCountdown-win32-arm64-qt.zip'
$singleExePath = Join-Path $releaseDir 'FloatingCountdown-win32-arm64-qt.exe'

$cmake = Get-Command cmake -ErrorAction Stop
$ninja = Get-Command ninja -ErrorAction Stop

function Import-VsDevEnvironment {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (!(Test-Path $vswhere)) {
        return
    }

    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.ARM64 -property installationPath
    if (!$vsPath) {
        return
    }

    $devCmd = Join-Path $vsPath 'Common7\Tools\VsDevCmd.bat'
    if (!(Test-Path $devCmd)) {
        return
    }

    $envLines = cmd /s /c "`"$devCmd`" -arch=arm64 -host_arch=arm64 >nul && set"
    foreach ($line in $envLines) {
        if ($line -match '^(.*?)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }
}

function Get-PeMachine($path) {
    $stream = [IO.File]::OpenRead($path)
    try {
        $reader = New-Object IO.BinaryReader($stream)
        $stream.Seek(0x3c, [IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $reader.ReadInt32()
        $stream.Seek($peOffset + 4, [IO.SeekOrigin]::Begin) | Out-Null
        return $reader.ReadUInt16()
    } finally {
        if ($reader) { $reader.Close() }
        $stream.Close()
    }
}

function Copy-Arm64Dll($source, $destDir) {
    if (!(Test-Path $source)) {
        return
    }
    if ((Get-PeMachine $source) -eq 0xAA64) {
        Copy-Item $source $destDir -Force
    }
}

Import-VsDevEnvironment

if (Test-Path $buildDir) {
    Remove-Item $buildDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$qtRoot = 'C:\Qt\6.8.3\msvc2022_arm64'
$qtHostRoot = 'C:\Qt\6.8.3\msvc2022_64'

if (Test-Path (Join-Path $qtRoot 'bin')) {
    $env:Path = (Join-Path $qtRoot 'bin') + ';' + $env:Path
}
if (Test-Path (Join-Path $qtHostRoot 'bin')) {
    $env:Path = $env:Path + ';' + (Join-Path $qtHostRoot 'bin')
}

$qtConfigDir = Join-Path $qtRoot 'lib\cmake\Qt6'
if (!(Test-Path (Join-Path $qtConfigDir 'Qt6Config.cmake'))) {
    throw "Qt ARM64 target config not found: $qtConfigDir"
}
if (!(Test-Path (Join-Path $qtHostRoot 'lib\cmake\Qt6\Qt6Config.cmake'))) {
    throw "Qt host config not found: $qtHostRoot"
}

$configureArgs = @(
    '-S', $projectDir,
    '-B', $buildDir,
    '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    "-DCMAKE_PREFIX_PATH=$qtRoot",
    "-DQt6_DIR=$qtConfigDir",
    "-DQT_HOST_PATH=$qtHostRoot"
)

Write-Host "Using Qt target: $qtRoot"
Write-Host "Using Qt host: $qtHostRoot"
& $cmake.Source @configureArgs
& $cmake.Source --build $buildDir --config Release

if (Test-Path $packageRoot) {
    Remove-Item $packageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $appDir | Out-Null

$exe = Join-Path $buildDir 'FloatingCountdown.exe'
if (!(Test-Path $exe)) {
    $exe = Join-Path $buildDir 'Release\FloatingCountdown.exe'
}
if (!(Test-Path $exe)) {
    throw "FloatingCountdown.exe not found in $buildDir"
}

Copy-Item $exe $appDir -Force

$windeployqt = Get-Command windeployqt -ErrorAction Stop
& $windeployqt.Source --release --qmldir (Join-Path $projectDir 'qml') (Join-Path $appDir 'FloatingCountdown.exe')

# The Windows ARM64 Qt kit uses host tools from the x64 kit. windeployqt can
# create the right layout but may copy host binaries, so overwrite runtime
# files from the ARM64 target kit before zipping.
Get-ChildItem $appDir -Filter '*.dll' -File | ForEach-Object {
    $targetDll = Join-Path (Join-Path $qtRoot 'bin') $_.Name
    if (Test-Path $targetDll) {
        Copy-Item $targetDll $_.FullName -Force
    }
}

$pluginRoot = Join-Path $qtRoot 'plugins'
foreach ($pluginDir in @('generic', 'imageformats', 'networkinformation', 'platforms', 'qmltooling', 'tls')) {
    $sourceDir = Join-Path $pluginRoot $pluginDir
    $destDir = Join-Path $appDir $pluginDir
    if ((Test-Path $sourceDir) -and (Test-Path $destDir)) {
        Remove-Item $destDir -Recurse -Force
        Copy-Item $sourceDir $destDir -Recurse -Force
    }
}

$targetQml = Join-Path $qtRoot 'qml'
$destQml = Join-Path $appDir 'qml'
if ((Test-Path $targetQml) -and (Test-Path $destQml)) {
    Remove-Item $destQml -Recurse -Force
    Copy-Item $targetQml $destQml -Recurse -Force
}

$system32 = Join-Path $env:windir 'System32'
Copy-Arm64Dll (Join-Path $system32 'D3DCompiler_47.dll') $appDir
Copy-Arm64Dll (Join-Path $system32 'Microsoft-Edge-WebView\dxcompiler.dll') $appDir
Copy-Arm64Dll (Join-Path $system32 'Microsoft-Edge-WebView\dxil.dll') $appDir

$vcRedist = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC\14.44.35112\arm64\Microsoft.VC143.CRT'
foreach ($runtime in @('concrt140.dll', 'msvcp140.dll', 'vcruntime140.dll')) {
    Copy-Arm64Dll (Join-Path $vcRedist $runtime) $appDir
}
Remove-Item (Join-Path $appDir 'vcruntime140_1.dll') -Force -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}
Compress-Archive -Path (Join-Path $appDir '*') -DestinationPath $zipPath -Force

$sizeMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host "Created $zipPath ($sizeMb MB)"

$sfxSource = Join-Path $projectDir 'sfx\self_extract.cpp'
$sfxBuildDir = Join-Path $buildDir 'sfx'
$sfxExe = Join-Path $sfxBuildDir 'FloatingCountdownSfx.exe'
New-Item -ItemType Directory -Force -Path $sfxBuildDir | Out-Null

$cl = Get-Command cl.exe -ErrorAction Stop
Push-Location $sfxBuildDir
try {
    $sfxCompileArgs = @(
        '/nologo',
        '/utf-8',
        '/std:c++17',
        '/O2',
        '/EHsc',
        '/DUNICODE',
        '/D_UNICODE',
        "/Fe:$sfxExe",
        $sfxSource,
        '/link',
        '/SUBSYSTEM:WINDOWS',
        'shell32.lib',
        'user32.lib'
    )
    & $cl.Source @sfxCompileArgs | Out-Host
} finally {
    Pop-Location
}

if (Test-Path $singleExePath) {
    Remove-Item $singleExePath -Force
}
Copy-Item $sfxExe $singleExePath -Force

$payload = [IO.File]::ReadAllBytes($zipPath)
$stream = [IO.File]::Open($singleExePath, [IO.FileMode]::Append, [IO.FileAccess]::Write)
try {
    $stream.Write($payload, 0, $payload.Length)
    $magic = [Text.Encoding]::ASCII.GetBytes('FCQTSFX1')
    $stream.Write($magic, 0, $magic.Length)
    $sizeBytes = [BitConverter]::GetBytes([UInt64]$payload.Length)
    $stream.Write($sizeBytes, 0, $sizeBytes.Length)
} finally {
    $stream.Close()
}

$singleSizeMb = [math]::Round((Get-Item $singleExePath).Length / 1MB, 2)
Write-Host "Created $singleExePath ($singleSizeMb MB)"
