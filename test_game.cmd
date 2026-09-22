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
"%GODOT_EXE%" --headless --path "%PROJECT_ROOT%" --log-file smoke-ci.log -- --smoke-test --seed=AUTOMATED-TEST
exit /b %errorlevel%
