@echo off
setlocal
title Quantum Horizon

REM Double-click this file to update, build, and open Quantum Horizon.
set "SCRIPT_DIR=%~dp0"
set "PROJECT_PATH=%SCRIPT_DIR%project\project.godot"
set "LAUNCHER_PATH=%SCRIPT_DIR%engine\scripts\run_editor_windows.ps1"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER_PATH%" -ProjectPath "%PROJECT_PATH%" %*
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" (
    echo Quantum Horizon could not be opened. Review the error above.
) else (
    echo Quantum Horizon launched successfully.
)
echo.
pause
exit /b %EXIT_CODE%
