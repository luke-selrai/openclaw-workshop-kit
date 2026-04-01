@echo off
setlocal EnableDelayedExpansion
echo ================================================
echo   Outlook ^& Microsoft 365 Connector Setup
echo   Built by Selr AI -- selrai.com.au
echo ================================================
echo.

:: ------------------------------------------------
:: ADMIN CHECK  (non-blocking -- used for better error messages later)
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
:: LONG PATH WARNING  (OneDrive / deeply nested folders)
:: ------------------------------------------------
set SCRIPT_PATH=%~f0
set SCRIPT_PATH_LEN=0
for /l %%i in (1,1,300) do (
    if "!SCRIPT_PATH:~%%i,1!" neq "" set /a SCRIPT_PATH_LEN=%%i
)
if %SCRIPT_PATH_LEN% GTR 200 (
    echo   Warning: This script is in a very deep folder path.
    echo   Windows has a 260-character path limit. If errors appear,
    echo   copy the outlook-connector folder closer to C:\ and try again.
    echo   e.g.  C:\workshop\outlook-connector\setup.bat
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
    echo   Note: npm uses HTTP_PROXY, but the Microsoft sign-in uses HTTPS_PROXY.
    echo   If sign-in fails, run this in a new window before retrying:
    echo     set HTTPS_PROXY=%HTTP_PROXY%
    echo   then re-run setup.bat.
    echo.
)

:: ------------------------------------------------
:: STEP 1  -- Check Node.js
:: ------------------------------------------------
echo [1/5] Checking Node.js...
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
:: STEP 2  -- Install m365 CLI  (with cache-clean retry)
:: ------------------------------------------------
echo [2/5] Installing the Microsoft 365 tool...
echo   This may take 1-2 minutes -- that is normal.
echo.

set INSTALL_ATTEMPTS=0

:TRY_INSTALL
set /a INSTALL_ATTEMPTS+=1
npm install -g @pnp/cli-microsoft365 >"%TEMP%\m365_install.txt" 2>&1
set INSTALL_EXIT=%errorlevel%

if %INSTALL_EXIT% equ 0 goto INSTALL_OK

:: EINTEGRITY -- corrupted npm cache; clean and retry once
findstr /i "EINTEGRITY" "%TEMP%\m365_install.txt" >nul 2>&1
if %errorlevel% equ 0 (
    if %INSTALL_ATTEMPTS% equ 1 (
        echo   npm cache corruption detected -- cleaning cache and retrying...
        npm cache clean --force >nul 2>&1
        goto TRY_INSTALL
    )
)

:: EPERM / EACCES -- permissions error
findstr /i "EPERM\|EACCES\|permission" "%TEMP%\m365_install.txt" >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo   Permission error during install.
    if %IS_ADMIN% neq 0 (
        echo   Fix: Close this window, right-click setup.bat, choose
        echo        "Run as administrator", and try again.
    ) else (
        echo   Already running as Admin but still blocked.
        echo   This is sometimes caused by Windows Defender scanning npm files.
        echo   Try: Windows Security ^> Virus ^& threat protection ^> Exclusions
        echo        ^> Add an exclusion for your Node.js global folder:
        for /f "tokens=*" %%i in ('npm prefix -g 2^>nul') do echo          %%i
        echo   Then run setup.bat again.
    )
    echo.
    goto SHOW_INSTALL_LOG
)

:: ECONNRESET / 403 -- proxy / firewall blocking npmjs.com
findstr /i "ECONNRESET\|ECONNREFUSED\|403\|ssl\|proxy" "%TEMP%\m365_install.txt" >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo   Network error -- npm cannot reach the internet.
    echo   Common causes:
    echo     - Corporate firewall blocking npmjs.com
    echo     - SSL inspection stripping certificates
    echo   Ask your IT department to allow: registry.npmjs.org:443
    echo.
    goto SHOW_INSTALL_LOG
)

:SHOW_INSTALL_LOG
echo.
echo   Install failed. Full error details:
echo   -----------------------------------------------
type "%TEMP%\m365_install.txt"
echo   -----------------------------------------------
del "%TEMP%\m365_install.txt" >nul 2>&1
echo.
pause
exit /b 1

:INSTALL_OK
del "%TEMP%\m365_install.txt" >nul 2>&1

:: Refresh PATH so m365 is found in this same window
for /f "tokens=*" %%i in ('npm prefix -g') do set NPMGLOBAL=%%i
set PATH=%NPMGLOBAL%\bin;%PATH%

m365 --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   The tool installed but cannot be found in this window yet.
    echo   Please close this window completely, reopen it, and run this file again.
    echo.
    pause
    exit /b 1
)
echo   Microsoft 365 tool installed -- OK
echo.

:: ------------------------------------------------
:: STEP 3  -- Set up app connection  (one-time)
:: ------------------------------------------------
echo [3/5] Setting up your Microsoft connection...
echo   A browser window will open. Sign in with your Microsoft account
echo   and click "Accept" when asked to approve the connection.
echo   ^(This links the Selr AI workshop app to your account -- one time only.^)
echo.
echo   If no browser opens, the window will show a URL -- paste it into any browser.
echo.

m365 setup --interactive
if %errorlevel% neq 0 (
    echo.
    echo   Setup did not complete. Possible causes:
    echo   - Browser was closed before approving
    echo   - Your organisation requires admin approval for new apps
    echo.
    echo   If you see "admin consent required":
    echo     Ask your IT admin to approve the PnP Management Shell app at:
    echo     https://entra.microsoft.com ^> Enterprise Applications ^> Grant admin consent
    echo.
    echo   To retry just this step, open a new Command Prompt and run:
    echo     m365 setup --interactive
    echo.
    pause
    exit /b 1
)
echo   Connection set up -- OK
echo.

:: ------------------------------------------------
:: STEP 4  -- Sign in
:: ------------------------------------------------
echo [4/5] Signing in to your Microsoft account...
echo   A browser window will open. Pick the account you want to use
echo   and click Accept or Allow when asked.
echo.

:: Check for stale session and clear it first
m365 status >nul 2>&1
if %errorlevel% equ 0 (
    echo   Existing session found -- refreshing...
    m365 logout >nul 2>&1
)

call m365 login --authType browser >"%TEMP%\m365_login.txt" 2>&1
set LOGIN_EXIT=%errorlevel%

if %LOGIN_EXIT% equ 0 (
    del "%TEMP%\m365_login.txt" >nul 2>&1
    goto LOGIN_OK
)

:: AADSTS53003 -- Conditional Access blocks browser login
findstr /i "53003\|AADSTS53003" "%TEMP%\m365_login.txt" >nul 2>&1
if %errorlevel% equ 0 (
    echo   Your organisation's security policy blocked browser sign-in.
    echo   Switching to device code sign-in instead...
    echo.
    del "%TEMP%\m365_login.txt" >nul 2>&1
    goto TRY_DEVICE_CODE
)

:: AADSTS90094 -- Admin consent required
findstr /i "90094\|AADSTS90094" "%TEMP%\m365_login.txt" >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo   Your Microsoft tenant requires an IT administrator to approve this app.
    echo   Ask your admin or workshop facilitator to grant consent at:
    echo     https://entra.microsoft.com
    echo     ^> Enterprise Applications ^> PnP Management Shell ^> Grant admin consent
    echo.
    del "%TEMP%\m365_login.txt" >nul 2>&1
    pause
    exit /b 1
)

:: AADSTS70043 -- Token/session expired
findstr /i "70043\|AADSTS70043" "%TEMP%\m365_login.txt" >nul 2>&1
if %errorlevel% equ 0 (
    echo   Previous session expired -- clearing and retrying...
    m365 logout >nul 2>&1
    del "%TEMP%\m365_login.txt" >nul 2>&1
    call m365 login --authType browser >"%TEMP%\m365_login.txt" 2>&1
    if !errorlevel! equ 0 (
        del "%TEMP%\m365_login.txt" >nul 2>&1
        goto LOGIN_OK
    )
)

echo   Browser sign-in failed. Trying device code sign-in...
echo.

:TRY_DEVICE_CODE
echo   You will see a short code below.
echo   Open https://aka.ms/devicelogin in your browser, enter the code, and sign in.
echo.
call m365 login >"%TEMP%\m365_login.txt" 2>&1
set LOGIN2_EXIT=%errorlevel%

if %LOGIN2_EXIT% equ 0 (
    del "%TEMP%\m365_login.txt" >nul 2>&1
    goto LOGIN_OK
)

echo.
echo   Sign-in failed. Please check:
echo   - Your internet connection
echo   - Whether your organisation blocks external apps
echo   - Contact your workshop facilitator if the problem continues
echo.
type "%TEMP%\m365_login.txt"
del "%TEMP%\m365_login.txt" >nul 2>&1
pause
exit /b 1

:LOGIN_OK
echo   Signed in -- OK
echo.

:: ------------------------------------------------
:: STEP 5  -- Verify
:: ------------------------------------------------
echo [5/5] Checking the connection works...
call m365 outlook mail list --pageSize 3 >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Connected but could not read emails right now.
    echo   This is usually fine -- your account may have special settings.
    echo   Try asking your assistant: "Show me my unread emails"
    echo.
) else (
    echo   Connection verified -- OK
    echo.
)

echo ================================================
echo   All done! Your Microsoft 365 account is set up.
echo.
echo   Go to your AI assistant and try saying:
echo     "Show me my unread emails"
echo     "What meetings do I have this week?"
echo     "List my recent OneDrive files"
echo ================================================
echo.
pause
endlocal
