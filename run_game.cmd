@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "GODOT_EXE=%PROJECT_ROOT%\.tools\godot\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  if /I "%~2"=="touch" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\run_game.ps1" -Seed "%~1" -Touch
  ) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\run_game.ps1" -Seed "%~1"
  )
  exit /b
)
set "RUN_SEED=%~1"
if "%RUN_SEED%"=="" set "RUN_SEED=VOID-0001"
set "TOUCH_ARG="
if /I "%~2"=="touch" set "TOUCH_ARG=--touch-ui"
"%GODOT_EXE%" --path "%PROJECT_ROOT%" -- --seed=%RUN_SEED% %TOUCH_ARG%
