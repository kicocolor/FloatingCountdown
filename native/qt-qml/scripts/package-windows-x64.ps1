$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$projectDir = Join-Path $repoRoot 'native\qt-qml'
$buildDir = Join-Path $projectDir 'build\windows-x64'
$packageRoot = Join-Path $buildDir 'package'
$appDir = Join-Path $packageRoot 'FloatingCountdown'
$releaseDir = Join-Path $repoRoot 'release-native'
$zipPath = Join-Path $releaseDir 'FloatingCountdown-win32-x64-qt.zip'
$singleExePath = Join-Path $releaseDir 'FloatingCountdown-win32-x64-qt.exe'

$cmake = Get-Command cmake -ErrorAction Stop
$ninja = Get-Command ninja -ErrorAction Stop

function Import-VsDevEnvironment {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $vsPath = $null
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -products * -property installationPath
    }

    if (!$vsPath) {
        $fallback = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\BuildTools'
        if (Test-Path $fallback) {
            $vsPath = $fallback
        }
    }

    if (!$vsPath) { throw 'Visual Studio Build Tools not found.' }

    $devCmd = Join-Path $vsPath 'Common7\Tools\VsDevCmd.bat'
    if (!(Test-Path $devCmd)) {
        throw "VsDevCmd.bat not found: $devCmd"
    }

    $envLines = cmd /s /c "`"$devCmd`" -arch=x64 -host_arch=x64 >nul && set"
    foreach ($line in $envLines) {
        if ($line -match '^(.*?)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }

    if (!(Get-Command cl.exe -ErrorAction SilentlyContinue)) {
        throw 'cl.exe was not added to PATH by VsDevCmd.bat.'
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

function Copy-X64Dll($source, $destDir) {
    if (!(Test-Path $source)) {
        return
    }
    if ((Get-PeMachine $source) -eq 0x8664) {
        Copy-Item $source $destDir -Force
    }
}

Import-VsDevEnvironment

if (Test-Path $buildDir) {
    Remove-Item $buildDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$qtRoot = 'C:\Qt\6.8.3\msvc2022_64'

if (Test-Path (Join-Path $qtRoot 'bin')) {
    $env:Path = (Join-Path $qtRoot 'bin') + ';' + $env:Path
}

$qtConfigDir = Join-Path $qtRoot 'lib\cmake\Qt6'
if (!(Test-Path (Join-Path $qtConfigDir 'Qt6Config.cmake'))) {
    throw "Qt x64 config not found: $qtConfigDir"
}

$configureArgs = @(
    '-S', $projectDir,
    '-B', $buildDir,
    '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    "-DCMAKE_PREFIX_PATH=$qtRoot",
    "-DQt6_DIR=$qtConfigDir"
)

Write-Host "Using Qt x64: $qtRoot"
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

$windeployqt = Join-Path $qtRoot 'bin\windeployqt.exe'
if (!(Test-Path $windeployqt)) {
    throw "windeployqt not found: $windeployqt"
}
& $windeployqt --release --qmldir (Join-Path $projectDir 'qml') (Join-Path $appDir 'FloatingCountdown.exe')

$system32 = Join-Path $env:windir 'System32'
Copy-X64Dll (Join-Path $system32 'D3DCompiler_47.dll') $appDir
Copy-X64Dll (Join-Path $system32 'Microsoft-Edge-WebView\dxcompiler.dll') $appDir
Copy-X64Dll (Join-Path $system32 'Microsoft-Edge-WebView\dxil.dll') $appDir

$vcRoot = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC'
$vcRedist = Get-ChildItem $vcRoot -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
foreach ($runtime in @('concrt140.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    if ($vcRedist) {
        Copy-X64Dll (Join-Path $vcRedist $runtime) $appDir
    }
}

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
