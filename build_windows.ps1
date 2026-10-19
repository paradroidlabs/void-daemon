param([string]$GodotPath)
$ErrorActionPreference = 'Stop'
$buildRoot = $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $buildRoot '.tools\godot\Godot_v4.7.1-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot not found: $GodotPath" }
$templatePath = Join-Path $buildRoot '.tools\windows\windows_release_x86_64.exe'
if (-not (Test-Path -LiteralPath $templatePath)) {
    throw 'Missing Windows runtime. Run python scripts/fetch_windows_template.py first.'
}
$projectText = Get-Content -LiteralPath (Join-Path $buildRoot 'project.godot') -Raw
$buildVersion = [regex]::Match($projectText, 'config/version="([^"]+)"').Groups[1].Value
if ($buildVersion -notmatch '^desktop-[0-9.]+$') { throw 'Invalid desktop build version.' }
$outputDir = Join-Path $buildRoot ('builds\windows-' + $buildVersion)
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$exePath = Join-Path $outputDir 'VOID-DAEMON.exe'
& $GodotPath --headless --path $buildRoot --editor --quit --log-file (Join-Path $buildRoot '.godot\windows-import.log')
if ($LASTEXITCODE -ne 0) { throw 'Godot resource import failed.' }
& $GodotPath --headless --path $buildRoot --export-release 'Windows Desktop' $exePath --log-file (Join-Path $buildRoot '.godot\windows-export.log')
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
if (-not (Test-Path -LiteralPath $exePath)) { throw 'Export did not produce an executable.' }
Copy-Item -LiteralPath (Join-Path $buildRoot 'DESKTOP_PLAYTEST.md') -Destination $outputDir
Copy-Item -LiteralPath (Join-Path $buildRoot 'EXPERIENCE_PLAYTEST.md') -Destination $outputDir
Copy-Item -LiteralPath (Join-Path $buildRoot 'distribution\Play Combat Lab.cmd') -Destination $outputDir
foreach ($license in @('GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt')) {
    $licensePath = Join-Path $buildRoot ('.tools\windows\' + $license)
    if (-not (Test-Path -LiteralPath $licensePath)) { throw "Missing distribution notice: $license" }
    Copy-Item -LiteralPath $licensePath -Destination $outputDir
}
$revision = (& git -C $buildRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify the source commit.' }
$status = (& git -C $buildRoot status --porcelain --untracked-files=no)
$hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
$exeStream = [System.IO.File]::OpenRead($exePath)
try {
    $exeHash = [BitConverter]::ToString($hashAlgorithm.ComputeHash($exeStream)).Replace('-', '').ToLowerInvariant()
} finally {
    $exeStream.Dispose()
    $hashAlgorithm.Dispose()
}
$manifest = [ordered]@{
    build = $buildVersion
    source_commit = $revision
    source_has_tracked_changes = [bool]$status
    engine = '4.7.1.stable.official.a13da4feb'
    architecture = 'windows-x86_64'
    embedded_pck = $true
    executable_sha256 = $exeHash
}
# Generated build metadata, not a source-file edit.
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDir 'build.json') -Encoding UTF8
Write-Output "WINDOWS_BUILD_OK $exePath"
