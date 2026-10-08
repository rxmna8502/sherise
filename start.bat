@echo off
title SheRise Platform Launcher
cls
echo ========================================================
echo             SheRise Platform Launcher
echo ========================================================
echo.
echo Choose what you want to launch:
echo.
echo   [1] Web App + Admin Panel (Port 10201 and Port 5173)
echo   [2] Mobile Backend Server Only (Port 10202 - Clean Console for OTP)
echo   [3] Mobile App on Connected Phone (Port 10202)
echo   [4] Launch Everything (Web 10201 + Mobile Backend 10202 + Mobile App)
echo.
set choice=1
set /p "choice=Enter choice (1, 2, 3, or 4) [Default 1]: "
if defined choice set choice=%choice: =%
if "%choice%"=="" set choice=1

if "%choice%"=="1" goto opt1
if "%choice%"=="2" goto opt2
if "%choice%"=="3" goto opt3
if "%choice%"=="4" goto opt4
goto opt_invalid

:opt1
echo.
echo Launching SheRise Web Backend and Admin Panel on Port 10201...
powershell -ExecutionPolicy Bypass -File "%~dp0start_all.ps1"
goto done

:opt2
echo.
echo Launching Dedicated Mobile Backend Server on Port 10202...
call "%~dp0start_mobile_server.bat"
goto done

:opt3
echo.
echo Launching SheRise Mobile App (Connecting to Port 10202)...
call "%~dp0start_mobile.bat"
goto done

:opt4
echo.
echo Launching Full Platform: Web 10201 + Mobile Backend 10202 + Mobile App...
powershell -ExecutionPolicy Bypass -File "%~dp0start_all.ps1" -IncludeMobile
goto done

:opt_invalid
echo.
echo Invalid choice. Defaulting to Web + Admin Panel...
powershell -ExecutionPolicy Bypass -File "%~dp0start_all.ps1"
goto done

:done
pause
