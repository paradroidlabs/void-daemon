@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "GODOT_EXE=%PROJECT_ROOT%\.tools\godot\Godot_v4.7.1-stable_win64_console.exe"
if not exist "%GODOT_EXE%" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\test_game.ps1"
  exit /b
)
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --editor --quit
if errorlevel 1 exit /b %errorlevel%
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --log-file "%PROJECT_ROOT%\.godot\combat-review.log" --script res://tests/combat_review.gd
if errorlevel 1 exit /b %errorlevel%
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --log-file "%PROJECT_ROOT%\.godot\playfield-layout.log" --script res://tests/playfield_layout_test.gd
if errorlevel 1 exit /b %errorlevel%
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --log-file "%PROJECT_ROOT%\.godot\smoke-ci.log" -- --smoke-test --seed=AUTOMATED-TEST
exit /b %errorlevel%
