@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
set "GODOT_EXE=%PROJECT_ROOT%.tools\godot\Godot_v4.7.1-stable_win64_console.exe"
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%." --log-file "%PROJECT_ROOT%.godot\graviton-stress.log" --script res://tests/graviton_stress_test.gd
exit /b %errorlevel%
