$projectRoot = $PSScriptRoot
$consoleGodot = Join-Path $projectRoot ".tools\godot\Godot_v4.7.1-stable_win64_console.exe"

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

& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\boss-health-bar-test.log') --script res://tests/boss_health_bar_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\inertial-flight-test.log') --script res://tests/inertial_flight_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\chassis-experience.log') --script res://tests/chassis_experience_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\experience-audio.log') --script res://tests/experience_audio_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\playfield-layout.log') --script res://tests/playfield_layout_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\smoke-ci.log') -- --smoke-test --seed=AUTOMATED-TEST
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\run-report-test.log') --script res://tests/run_report_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\graviton-test.log') --script res://tests/graviton_combo_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\graviton-flow.log') --script res://tests/graviton_demo.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\graviton-input.log') --script res://tests/graviton_input_test.gd
exit $LASTEXITCODE

