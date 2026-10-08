@echo off
title SheRise Mobile Launcher
cls
echo ========================================================
echo             SheRise Mobile App Launcher
echo ========================================================
echo.

set ADB_PATH="%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
where adb >nul 2>&1
if %errorlevel% equ 0 (
    set ADB_CMD=adb
) else if exist %ADB_PATH% (
    set ADB_CMD=%ADB_PATH%
) else (
    set ADB_CMD=
)

:check_device
echo [1/3] Checking for connected Android devices via ADB...
if not "%ADB_CMD%"=="" (
    for /f "skip=1 tokens=1,2" %%A in ('%ADB_CMD% devices') do (
        if "%%B"=="device" (
            set DEVICE_ID=%%A
            goto device_found
        )
    )
)

echo.
echo [!] No Android device detected over USB.
echo.
echo To connect your phone (Xiaomi / Redmi / Android):
echo   1. Connect your phone via USB cable to this PC.
echo   2. Unlock your phone screen.
echo   3. Swipe down from top and change USB mode from "Charging" to "File Transfer (MTP)".
echo   4. Ensure "USB Debugging" is enabled in Settings -^> Developer Options.
echo.
echo Alternatively, you can install the already-built APK directly:
echo   - APK Location: %~dp0SheRise.apk
echo.
set /p retry="Press [R] to retry device detection, or [E] to exit: "
if /i "%retry%"=="r" goto check_device
goto end

:device_found
echo [+] Connected Android Device: %DEVICE_ID%
echo.
echo [2/4] Checking SheRise Mobile Backend on dedicated port 10202...
netstat -ano | findstr ":10202" >nul 2>&1
if errorlevel 1 (
    echo [+] Starting dedicated Mobile Backend server on port 10202 in a new window...
    start "SheRise Mobile Backend (Port 10202)" cmd /k "%~dp0start_mobile_server.bat"
    timeout /t 2 /nobreak >nul
) else (
    echo [+] Mobile Backend server is already running on port 10202.
)

echo.
echo [3/4] Configuring ADB reverse port forwarding (tcp:10202 ^-> tcp:10202)...
%ADB_CMD% reverse tcp:10202 tcp:10202
%ADB_CMD% reverse tcp:10201 tcp:10201
echo Port forwarding active: Mobile app reaches dedicated backend at http://localhost:10202
echo.

echo [4/4] Launching SheRise Mobile on Android (%DEVICE_ID%)...
cd /d "%~dp0SheRise_Mobile"
flutter run -d %DEVICE_ID% --dart-define=SHE_RISE_URL=http://localhost:10202

if errorlevel 1 (
    echo.
    echo ========================================================
    echo  If you saw: INSTALL_FAILED_USER_RESTRICTED (Xiaomi / MIUI)
    echo ========================================================
    echo  Xiaomi devices block USB installation by default.
    echo  Fix 1: Go to phone Settings -^> Additional Settings -^> Developer Options
    echo         Enable "Install via USB" (and "USB debugging (Security settings)").
    echo.
    echo  Fix 2: Copy and install the APK directly on your phone:
    echo         The APK is ready at: %~dp0SheRise.apk
    echo ========================================================
)

:end
pause

