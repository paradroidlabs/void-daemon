@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "GODOT_EXE=%PROJECT_ROOT%\.tools\godot\Godot_v4.7.1-stable_win64_console.exe"
if not exist "%GODOT_EXE%" (
  echo Godot console was not found at "%GODOT_EXE%".
  exit /b 1
)
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --editor --quit
if errorlevel 1 exit /b %errorlevel%
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --log-file "%PROJECT_ROOT%\.godot\boss-health-bar-test.log" --script res://tests/boss_health_bar_test.gd
if errorlevel 1 exit /b %errorlevel%
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --log-file "%PROJECT_ROOT%\.godot\smoke-ci.log" -- --smoke-test --seed=AUTOMATED-TEST
if errorlevel 1 exit /b %errorlevel%
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --log-file "%PROJECT_ROOT%\.godot\run-report-test.log" --script res://tests/run_report_test.gd
if errorlevel 1 exit /b %errorlevel%
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --log-file "%PROJECT_ROOT%\.godot\graviton-test.log" --script res://tests/graviton_combo_test.gd
if errorlevel 1 exit /b %errorlevel%
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --log-file "%PROJECT_ROOT%\.godot\graviton-flow.log" --script res://tests/graviton_demo.gd
if errorlevel 1 exit /b %errorlevel%
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --log-file "%PROJECT_ROOT%\.godot\graviton-input.log" --script res://tests/graviton_input_test.gd
exit /b %errorlevel%
