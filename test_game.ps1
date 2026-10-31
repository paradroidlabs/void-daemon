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
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\live-stats-test.log') --script res://tests/live_stats_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\substrate-test.log') --script res://tests/substrate_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\campaign-test.log') --script res://tests/campaign_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\transit-test.log') --script res://tests/transit_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\facility-test.log') --script res://tests/facility_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\recovery-test.log') --script res://tests/recovery_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\picket-test.log') --script res://tests/picket_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\expedition-test.log') --script res://tests/expedition_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\tactical-campaign-test.log') --script res://tests/tactical_campaign_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\story-test.log') --script res://tests/story_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\music-director-test.log') --script res://tests/music_director_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\graviton-test.log') --script res://tests/graviton_combo_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\graviton-flow.log') --script res://tests/graviton_demo.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $consoleGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot\graviton-input.log') --script res://tests/graviton_input_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
# Godot can return zero despite an unhandled GDScript error. Reject those too.
foreach ($testLog in @('boss-health-bar-test', 'inertial-flight-test', 'chassis-experience', 'experience-audio', 'playfield-layout', 'smoke-ci', 'run-report-test', 'live-stats-test', 'substrate-test', 'campaign-test', 'transit-test', 'facility-test', 'recovery-test', 'picket-test', 'expedition-test', 'tactical-campaign-test', 'story-test', 'music-director-test', 'graviton-test', 'graviton-flow', 'graviton-input')) {
    $testLogPath = Join-Path $projectRoot ('.godot\' + $testLog + '.log')
    if (Select-String -LiteralPath $testLogPath -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) {
        Write-Error "Runtime error in $testLogPath"
        exit 1
    }
}
exit 0

