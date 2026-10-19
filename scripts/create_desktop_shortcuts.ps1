$ErrorActionPreference = 'Stop'
$shortcutRoot = Split-Path $PSScriptRoot -Parent
$projectText = Get-Content -LiteralPath (Join-Path $shortcutRoot 'project.godot') -Raw
$buildVersion = [regex]::Match($projectText, 'config/version="([^"]+)"').Groups[1].Value
if ($buildVersion -notmatch '^desktop-[0-9.]+$') { throw 'Invalid desktop build version.' }
$target = Join-Path $shortcutRoot ('builds\windows-' + $buildVersion + '\VOID-DAEMON.exe')
if (-not (Test-Path -LiteralPath $target)) { throw "Build not found: $target" }
$desktop = [Environment]::GetFolderPath('Desktop')
$shell = New-Object -ComObject WScript.Shell
foreach ($entry in @(
    @{ Name = 'VOID DAEMON'; Arguments = ''; Description = 'VOID//DAEMON - hangar, chassis selection and survival' },
    @{ Name = 'VOID DAEMON - Combat Lab'; Arguments = '-- --combo-lab --fixture=cluster --loadout=chain'; Description = 'VOID//DAEMON - repeatable combat lab' }
)) {
    $shortcutPath = Join-Path $desktop ($entry.Name + '.lnk')
    $shortcut = $shell.CreateShortcut($shortcutPath)
    if ((Test-Path -LiteralPath $shortcutPath) -and $shortcut.TargetPath -ne $target) {
        throw "An unrelated shortcut already exists; preserved: $shortcutPath"
    }
    $shortcut.TargetPath = $target
    $shortcut.Arguments = $entry.Arguments
    $shortcut.WorkingDirectory = Split-Path $target -Parent
    $shortcut.IconLocation = $target + ',0'
    $shortcut.Description = $entry.Description
    $shortcut.Save()
    Write-Output "SHORTCUT_OK $shortcutPath"
}
