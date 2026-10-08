@echo off
title SheRise Mobile Backend (Dedicated Port 10202)
cls
echo ========================================================
echo       SheRise Mobile Backend Server (Port 10202)
echo ========================================================
echo.
echo [*] Dedicated server for Mobile App only.
echo [*] Clean console: Shows mobile requests, OTPs, and auth codes.
echo [*] Database is shared in real-time with Web and Admin.
echo.
cd /d "%~dp0SheRise_Web"
set SERVER_PORT=10202
set FLASK_DEBUG=1
.\.venv\Scripts\python.exe app.py
pause
