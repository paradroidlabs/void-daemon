@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "GODOT_EXE=%PROJECT_ROOT%\.tools\godot\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot was not found at "%GODOT_EXE%".
  echo Install Godot 4.7.1 or run the project.godot file with your Godot editor.
  exit /b 1
)
set "RUN_SEED=%~1"
if "%RUN_SEED%"=="" set "RUN_SEED=VOID-0001"
set "TOUCH_ARG="
if /I "%~2"=="touch" set "TOUCH_ARG=--touch-ui"
"%GODOT_EXE%" --path "%PROJECT_ROOT%" -- --seed=%RUN_SEED% %TOUCH_ARG%
