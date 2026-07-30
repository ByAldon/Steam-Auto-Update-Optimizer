@echo off
title Steam Update Optimizer
color 0B

:: Provide instant feedback before PowerShell initialization starts
echo.
echo   Please wait, starting program...
echo   Loading core components...
echo.

powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0SteamOptimizerGUI.ps1"
exit
