@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
set "GODOT_EXE=%PROJECT_ROOT%.tools\godot\Godot_v4.7.1-stable_win64.exe"
"%GODOT_EXE%" --path "%PROJECT_ROOT%." -- --classic --seed=VOID-0001
