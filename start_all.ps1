<#
.SYNOPSIS
    SheRise Universal Startup Script
.DESCRIPTION
    Launches SheRise Web (Backend + Web UI), SheRise Admin Panel, and optionally SheRise Mobile.
#>

param(
    [switch]$IncludeMobile,
    [switch]$InstallDeps
)

$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "=========================================" -ForegroundColor Magenta
Write-Host "   SheRise Platform - Universal Launcher " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Magenta
Write-Host "Root Directory: $rootDir" -ForegroundColor Gray

# 1. Start SheRise_Web (Flask API + Built Web UI) on Port 10201
Write-Host "`n[1/3] Preparing SheRise_Web (Backend & Web UI)..." -ForegroundColor Yellow
$webDir = Join-Path $rootDir "SheRise_Web"
$venvPy = Join-Path $webDir ".venv\Scripts\python.exe"

if (-not (Test-Path $venvPy) -or $InstallDeps) {
    Write-Host "Setting up Python virtual environment and dependencies for SheRise_Web..." -ForegroundColor Gray
    Start-Process powershell -NoNewWindow -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command Set-Location '$webDir'; if (-not (Test-Path '.venv')) { python -m venv .venv }; .\.venv\Scripts\python.exe -m pip install --upgrade pip; .\.venv\Scripts\python.exe -m pip install -r requirements.txt"
}

Write-Host "Launching SheRise_Web on http://127.0.0.1:10201 in a new window..." -ForegroundColor Green
$webCmd = "Set-Location '$webDir'; if (Test-Path '$venvPy') { & '$venvPy' app.py } else { python app.py }; Read-Host 'Press Enter to exit...'"
Start-Process powershell -ArgumentList "-NoExit -ExecutionPolicy Bypass -Command $webCmd"

# 2. Start SheRise_AdminPanel (Vite Dev Server) on Port 5173
Write-Host "`n[2/3] Preparing SheRise_AdminPanel (Admin Console)..." -ForegroundColor Yellow
$adminDir = Join-Path $rootDir "SheRise_AdminPanel"

if (-not (Test-Path (Join-Path $adminDir "node_modules")) -or $InstallDeps) {
    Write-Host "Installing npm dependencies for SheRise_AdminPanel..." -ForegroundColor Gray
    Start-Process powershell -NoNewWindow -Wait -ArgumentList "-NoProfile -Command Set-Location '$adminDir'; npm install"
}

Write-Host "Launching SheRise_AdminPanel on http://localhost:5173 in a new window..." -ForegroundColor Green
$adminCmd = "Set-Location '$adminDir'; npm run dev; Read-Host 'Press Enter to exit...'"
Start-Process powershell -ArgumentList "-NoExit -Command $adminCmd"

# 3. SheRise_Mobile
$mobileDir = Join-Path $rootDir "SheRise_Mobile"
if ($IncludeMobile) {
    Write-Host "`n[3/3] Launching SheRise Mobile Backend (Port 10202) & Mobile App..." -ForegroundColor Yellow
    $mobileServerBat = Join-Path $rootDir "start_mobile_server.bat"
    if (Test-Path $mobileServerBat) {
        Write-Host "Starting dedicated mobile backend on port 10202..." -ForegroundColor Green
        Start-Process cmd -ArgumentList "/c `"$mobileServerBat`""
    }

    $adbPath = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Get-Command "adb" -ErrorAction SilentlyContinue) {
        adb reverse tcp:10202 tcp:10202 | Out-Null
        adb reverse tcp:10201 tcp:10201 | Out-Null
    } elseif (Test-Path $adbPath) {
        & $adbPath reverse tcp:10202 tcp:10202 | Out-Null
        & $adbPath reverse tcp:10201 tcp:10201 | Out-Null
    }
    $mobileCmd = "Set-Location '$mobileDir'; flutter run -d android --dart-define=SHE_RISE_URL=http://localhost:10202; if (-not `$?) { flutter run --dart-define=SHE_RISE_URL=http://localhost:10202 }; Read-Host 'Press Enter to exit...'"
    Start-Process powershell -ArgumentList "-NoExit -Command $mobileCmd"
} else {
    Write-Host "`n[3/3] SheRise_Mobile was skipped." -ForegroundColor Gray
    Write-Host "To run mobile later, run .\start_mobile.bat or install the built APK directly:" -ForegroundColor Gray
    Write-Host "  $rootDir\SheRise.apk" -ForegroundColor Cyan
    Write-Host "(Or re-run this script with -IncludeMobile)" -ForegroundColor Gray
}

Write-Host "`n=========================================" -ForegroundColor Magenta
Write-Host "Services are launching:" -ForegroundColor Green
Write-Host "  - Core Web App:   http://127.0.0.1:10201" -ForegroundColor Cyan
Write-Host "  - Admin Panel:    http://localhost:5173" -ForegroundColor Cyan
Write-Host "=========================================`n" -ForegroundColor Magenta
