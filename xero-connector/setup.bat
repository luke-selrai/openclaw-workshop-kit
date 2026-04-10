@echo off
setlocal EnableDelayedExpansion
echo ================================================
echo   Xero Connector Setup
echo   Built by Selr AI -- selrai.com.au
echo ================================================
echo.

:: ------------------------------------------------
:: ADMIN CHECK  (non-blocking)
:: ------------------------------------------------
net session >nul 2>&1
set IS_ADMIN=%errorlevel%
if %IS_ADMIN% neq 0 (
    echo   Note: Not running as Administrator.
    echo   If the install fails with a permissions error,
    echo   close this window, right-click setup.bat ^> "Run as administrator"
    echo   and try again.
    echo.
)

:: ------------------------------------------------
:: LONG PATH WARNING
:: ------------------------------------------------
set SCRIPT_PATH=%~f0
set SCRIPT_PATH_LEN=0
for /l %%i in (1,1,300) do (
    if "!SCRIPT_PATH:~%%i,1!" neq "" set /a SCRIPT_PATH_LEN=%%i
)
if %SCRIPT_PATH_LEN% GTR 200 (
    echo   Warning: This script is in a very deep folder path.
    echo   If errors appear, move the xero-connector folder closer to C:\
    echo   e.g.  C:\workshop\xero-connector\setup.bat
    echo.
)

:: ------------------------------------------------
:: POWERSHELL EXECUTION POLICY  (preemptive fix)
:: ------------------------------------------------
powershell -NoProfile -Command ^
    "if (@('Restricted','Undefined') -contains (Get-ExecutionPolicy -Scope CurrentUser)) { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host 'FIXED' }" ^
    2>nul | findstr /i "FIXED" >nul 2>&1
if %errorlevel% equ 0 (
    echo   Fixed PowerShell execution policy ^(RemoteSigned for current user^).
    echo.
)

:: ------------------------------------------------
:: CORPORATE PROXY NOTICE
:: ------------------------------------------------
if defined HTTPS_PROXY (
    echo   Corporate proxy detected: %HTTPS_PROXY%
    echo   The sign-in tool will use this automatically.
    echo.
) else if defined HTTP_PROXY (
    echo   Corporate proxy detected: %HTTP_PROXY%
    echo   If sign-in fails, run this before retrying:
    echo     set HTTPS_PROXY=%HTTP_PROXY%
    echo.
)

:: ------------------------------------------------
:: STEP 1  -- Check Node.js
:: ------------------------------------------------
echo [1/4] Checking Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Node.js is not installed on this computer.
    echo   Please install it from: https://nodejs.org
    echo   Download the LTS version ^(v22 or v20^), run the installer,
    echo   then run this file again.
    echo.
    pause
    exit /b 1
)

for /f "tokens=1 delims=v" %%i in ('node --version') do set NODERAW=%%i
for /f "tokens=1 delims=." %%i in ("%NODERAW%") do set NODEMAJOR=%%i
if %NODEMAJOR% LSS 20 (
    echo.
    echo   Your Node.js version is too old ^(found: v%NODERAW%^).
    echo   This connector needs Node.js v20 or higher.
    echo   Please update at https://nodejs.org and run this file again.
    echo.
    pause
    exit /b 1
)
echo   Node.js v%NODERAW% -- OK
echo.

:: ------------------------------------------------
:: STEP 2  -- npm install  (with cache-clean retry)
:: ------------------------------------------------
echo [2/4] Installing dependencies...
echo   This may take 1-2 minutes -- that is normal.
echo.

set INSTALL_ATTEMPTS=0

:TRY_INSTALL
set /a INSTALL_ATTEMPTS+=1
call npm install >"%TEMP%\xero_install.txt" 2>&1
set INSTALL_EXIT=%errorlevel%

if %INSTALL_EXIT% equ 0 goto INSTALL_OK

:: EINTEGRITY -- corrupted npm cache
findstr /i "EINTEGRITY" "%TEMP%\xero_install.txt" >nul 2>&1
if %errorlevel% equ 0 (
    if %INSTALL_ATTEMPTS% equ 1 (
        echo   npm cache corruption detected -- cleaning and retrying...
        call npm cache clean --force >nul 2>&1
        goto TRY_INSTALL
    )
)

:: EPERM / EACCES
findstr /i /c:"EPERM" /c:"EACCES" /c:"permission" "%TEMP%\xero_install.txt" >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo   Permission error during install.
    if %IS_ADMIN% neq 0 (
        echo   Fix: Close this window, right-click setup.bat, choose
        echo        "Run as administrator", and try again.
    ) else (
        echo   Already running as Admin. Try adding an exclusion for your
        echo   Node.js global folder in Windows Defender, then try again.
    )
    echo.
    goto SHOW_INSTALL_LOG
)

:: ECONNRESET / 403
findstr /i /c:"ECONNRESET" /c:"ECONNREFUSED" /c:"403" /c:"proxy" "%TEMP%\xero_install.txt" >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo   Network error -- npm cannot reach the internet.
    echo   Ask IT to allow: registry.npmjs.org:443
    echo.
    goto SHOW_INSTALL_LOG
)

:SHOW_INSTALL_LOG
echo.
echo   Install failed. Full error details:
echo   -----------------------------------------------
type "%TEMP%\xero_install.txt"
echo   -----------------------------------------------
del "%TEMP%\xero_install.txt" >nul 2>&1
echo.
pause
exit /b 1

:INSTALL_OK
del "%TEMP%\xero_install.txt" >nul 2>&1
echo   Dependencies installed -- OK
echo.

:: ------------------------------------------------
:: STEP 3  -- Check / create .env
:: ------------------------------------------------
echo [3/4] Checking credentials file...

if not exist .env (
    if exist .env.example (
        copy .env.example .env >nul
        echo   Created .env from template.
    ) else (
        echo XERO_CLIENT_ID=your_client_id_here> .env
        echo XERO_CLIENT_SECRET=your_client_secret_here>> .env
        echo   Created blank .env file.
    )
)

:: Check for placeholder values
findstr /i "your_client_id_here" .env >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo   *** Action needed ***
    echo.
    echo   Your .env file has placeholder values that need to be replaced.
    echo.
    echo   1. Go to: https://developer.xero.com/app/manage
    echo   2. Click your app ^(or create one -- it is free^)
    echo   3. Copy your Client ID and Client Secret
    echo   4. Open the .env file in this folder and replace:
    echo        XERO_CLIENT_ID=your_client_id_here
    echo        XERO_CLIENT_SECRET=your_client_secret_here
    echo.
    echo   See XERO-SETUP.md Step 2 for full instructions.
    echo.
    echo   Once you have updated .env, run this file again,
    echo   OR go straight to sign-in by running:
    echo     npm run auth
    echo.
    pause
    exit /b 0
)

echo   Credentials found -- OK
echo.

:: ------------------------------------------------
:: STEP 4  -- Run auth
:: ------------------------------------------------
echo [4/4] Connecting to Xero...
echo   A browser window will open. Sign in to Xero and click Allow.
echo.

call npm run auth
if %errorlevel% neq 0 (
    echo.
    echo   Sign-in did not complete. You can retry at any time by running:
    echo     npm run auth
    echo.
    pause
    exit /b 1
)

echo.
echo ================================================
echo   All done! Xero is connected to Claude Code.
echo.
echo   Next: add Xero to your Claude Code settings.
echo   See XERO-SETUP.md Step 5 for instructions.
echo.
echo   Then try asking Claude:
echo     "Show me my recent Xero invoices"
echo     "List my Xero contacts"
echo     "Show me the Xero profit and loss"
echo ================================================
echo.
pause
endlocal

