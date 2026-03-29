@echo off
REM Frontend-Backend Connection Test Script (Windows)
REM This script helps verify that frontend and backend are properly connected

echo.
echo ==========================================
echo Money Mentor - Connection Test (Windows)
echo ==========================================
echo.

REM Check if backend is running
echo [1/4] Checking backend connectivity...
set BACKEND_URL=http://localhost:8000/api/ping

powershell -Command "$response = Invoke-WebRequest -Uri '%BACKEND_URL%' -UseBasicParsing -ErrorAction SilentlyContinue; if ($response.StatusCode -eq 200) { Write-Host '✅ Backend is running and responding (Status: 200)' } else { Write-Host '❌ Backend not responding' }"

echo.

REM Check Flutter
echo [2/4] Checking Flutter installation...
where flutter >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=*" %%i in ('flutter --version') do (
        echo ✅ Flutter found: %%i
        goto :flutter_found
    )
    :flutter_found
) else (
    echo ❌ Flutter not found in PATH
    exit /b 1
)

echo.

REM Check dependencies
echo [3/4] Checking dependencies in pubspec.yaml...
findstr /M "http:" pubspec.yaml >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo ✅ http package found
) else (
    echo ❌ http package not found - run: flutter pub get
)

findstr /M "intl:" pubspec.yaml >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo ✅ intl package found
) else (
    echo ❌ intl package not found - run: flutter pub get
)

echo.

REM Check API config
echo [4/4] Checking API configuration...
if exist "lib\config\api_config.dart" (
    echo ✅ API config file found
    for /f "tokens=*" %%i in ('findstr "static const String baseUrl" lib\config\api_config.dart') do (
        echo    %%i
    )
) else (
    echo ❌ API config file not found
)

echo.
echo ==========================================
echo Connection Test Summary
echo ==========================================
echo.
echo ✅ All checks completed!
echo.
echo Next steps:
echo 1. Open a terminal and run: cd backend ^& python main.py
echo 2. In another terminal run: flutter run
echo 3. Check the green/red connection indicator in app
echo.
echo For physical device:
echo 1. Get your IP: ipconfig
echo 2. Update baseUrl in lib\config\api_config.dart
echo 3. Ensure device is on same network
echo.
pause
