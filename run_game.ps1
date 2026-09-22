param(
    [string]$Seed = "VOID-0001",
    [switch]$Touch
)

$projectRoot = $PSScriptRoot
$localGodot = Join-Path $projectRoot ".tools\godot\Godot_v4.7.1-stable_win64.exe"

if (Test-Path -LiteralPath $localGodot) {
    $godotExe = $localGodot
} else {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $godotCommand) {
        throw "Godot 4.7.1+ was not found. Install Godot or place the portable editor in .tools\godot."
    }
    $godotExe = $godotCommand.Source
}

$gameArguments = @("--seed=$Seed")
if ($Touch) {
    $gameArguments += "--touch-ui"
}

& $godotExe --path $projectRoot -- @gameArguments

