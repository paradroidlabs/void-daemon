$ErrorActionPreference = 'Stop'
$shortcutRoot = Split-Path $PSScriptRoot -Parent
$target = Join-Path $shortcutRoot 'builds\windows-desktop-2026.10.19.1\VOID-DAEMON.exe'
if (-not (Test-Path -LiteralPath $target)) { throw "Build not found: $target" }
$desktop = [Environment]::GetFolderPath('Desktop')
$shell = New-Object -ComObject WScript.Shell
foreach ($entry in @(
    @{ Name = 'VOID DAEMON'; Arguments = ''; Description = 'VOID//DAEMON - full survival run' },
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
