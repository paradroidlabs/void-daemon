@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
set "GODOT_EXE=%PROJECT_ROOT%.tools\godot\Godot_v4.7.1-stable_win64.exe"
set "TOUCH_ARG="
if /I "%~1"=="touch" set "TOUCH_ARG=--touch-ui"
"%GODOT_EXE%" --path "%PROJECT_ROOT%." -- --combo-lab --fixture=cluster --loadout=chain %TOUCH_ARG%
