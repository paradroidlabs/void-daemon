$projectRoot = $PSScriptRoot
$consoleGodot = Join-Path $projectRoot ".tools\godot\Godot_v4.7.1-stable_win64_console.exe"
if (-not (Test-Path -LiteralPath $consoleGodot)) {
    $commonGitDirectory = git -C $projectRoot rev-parse --path-format=absolute --git-common-dir 2>$null
    if ($LASTEXITCODE -eq 0 -and $commonGitDirectory) {
        $consoleGodot = Join-Path (Split-Path $commonGitDirectory -Parent) ".tools\godot\Godot_v4.7.1-stable_win64_console.exe"
    }
}

if (-not (Test-Path -LiteralPath $consoleGodot)) {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $godotCommand) {
        throw "Godot 4.7.1+ was not found."
    }
    $consoleGodot = $godotCommand.Source
}

& $consoleGodot --headless --path $projectRoot --editor --quit
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\combat-review.log') --script res://tests/combat_review.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\playfield-layout.log') --script res://tests/playfield_layout_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\smoke-ci.log') -- --smoke-test --seed=AUTOMATED-TEST
exit $LASTEXITCODE

