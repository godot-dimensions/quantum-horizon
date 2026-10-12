@echo off
setlocal
title Quantum Horizon Packaging

rem Double-click this file to build and package Quantum Horizon.
rem The "%~dp0" resolves to the current drive and path of this batch file.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0package_windows.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" (
    echo Quantum Horizon could not be packaged. Review the error above.
) else (
    echo Quantum Horizon packaged successfully.
)
echo.
pause
exit /b %EXIT_CODE%
