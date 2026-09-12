@echo off
setlocal EnableExtensions

set "REVISION=d6a79d184062a048549fa8e82e3a880e2c2783e7"
set "INSTALL_DIRECTORY=%LOCALAPPDATA%\Yomitan API"
set "INSTALLER_URL=https://raw.githubusercontent.com/yomidevs/yomitan-api/%REVISION%/install_yomitan_api.py"
set "HELPER_URL=https://raw.githubusercontent.com/yomidevs/yomitan-api/%REVISION%/yomitan_api.py"

where py >nul 2>nul
if errorlevel 1 (
  where winget >nul 2>nul
  if errorlevel 1 (
    echo Python 3 is required and Windows Package Manager was not found.
    start "" "https://www.python.org/downloads/windows/"
    echo Install Python 3, select "Add Python to PATH", then run this file again.
    pause
    exit /b 1
  )
  echo Python 3 was not found. Installing it for this Windows user...
  winget install --id Python.Python.3.13 --exact --scope user --accept-package-agreements --accept-source-agreements
  if errorlevel 1 (
    echo Python installation did not complete.
    pause
    exit /b 1
  )
)

mkdir "%INSTALL_DIRECTORY%" 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing '%INSTALLER_URL%' -OutFile '%INSTALL_DIRECTORY%\install_yomitan_api.py'; Invoke-WebRequest -UseBasicParsing '%HELPER_URL%' -OutFile '%INSTALL_DIRECTORY%\yomitan_api.py'"
if errorlevel 1 (
  echo Could not download the official Yomitan API helper.
  pause
  exit /b 1
)

echo Installing the Yomitan API helper for Google Chrome...
(echo 2& echo.) | py -3 "%INSTALL_DIRECTORY%\install_yomitan_api.py"
if errorlevel 1 (
  echo Installation did not finish. Make sure Python was installed for this user.
  pause
  exit /b 1
)

start "" "chrome-extension://likgccmbimhjbgkjambclfkhldnlhbnn/settings.html#general"
echo.
echo Installed. In Yomitan, enable Advanced, then Enable Yomitan API under General.
echo Restart Chrome, then return to this extension and check connections.
pause
