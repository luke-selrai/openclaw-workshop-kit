@echo off
setlocal EnableDelayedExpansion
echo ================================================
echo   Outlook ^& Microsoft 365 Connector Setup
echo   Built by Selr AI -- selrai.com.au
echo ================================================
echo.

:: ------------------------------------------------
:: STEP 1 -- Check Node.js
:: ------------------------------------------------
echo [1/5] Checking Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Node.js is not installed on this computer.
    echo   Please install it from: https://nodejs.org
    echo   Download the LTS version, run the installer, then run this file again.
    echo.
    pause
    exit /b 1
)

:: Check Node.js version is v20 or higher
for /f "tokens=1 delims=v" %%i in ('node --version') do set NODERAW=%%i
for /f "tokens=1 delims=." %%i in ("%NODERAW%") do set NODEMAJOR=%%i
if %NODEMAJOR% LSS 20 (
    echo.
    echo   Your Node.js version is too old.
    echo   This connector needs Node.js version 20 or higher.
    echo   Please update from: https://nodejs.org and run this file again.
    echo.
    pause
    exit /b 1
)
echo   Node.js v%NODERAW% -- OK
echo.

:: ------------------------------------------------
:: STEP 2 -- Install m365 CLI
:: ------------------------------------------------
echo [2/5] Installing the Microsoft 365 tool...
echo   This may take 1-2 minutes -- that is normal.
echo.
call npm install -g @pnp/cli-microsoft365 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Install failed. Common causes:
    echo   - No internet connection
    echo   - Firewall blocking npm
    echo   Try closing this window, reopening as Administrator, and running again.
    echo.
    pause
    exit /b 1
)

:: Refresh PATH so m365 is found immediately
for /f "tokens=*" %%i in ('npm prefix -g') do set NPMGLOBAL=%%i
set PATH=%NPMGLOBAL%\bin;%PATH%

m365 --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   The tool installed but cannot be found yet.
    echo   Please close this window completely, reopen it, and run this file again.
    echo.
    pause
    exit /b 1
)
echo   Microsoft 365 tool installed -- OK
echo.

:: ------------------------------------------------
:: STEP 3 -- Set up app connection (one-time)
:: ------------------------------------------------
echo [3/5] Setting up your Microsoft connection...
echo   A browser window will open. Sign in with your Microsoft account
echo   and follow the steps to approve the connection.
echo.
call m365 setup --interactive
if %errorlevel% neq 0 (
    echo.
    echo   Setup did not complete. Please try again or contact your workshop facilitator.
    echo.
    pause
    exit /b 1
)
echo   Connection set up -- OK
echo.

:: ------------------------------------------------
:: STEP 4 -- Sign in
:: ------------------------------------------------
echo [4/5] Signing in to your Microsoft account...
echo   A browser window will open. Pick the account you want to use
echo   and click Accept or Allow when asked.
echo.
call m365 login --authType browser
if %errorlevel% neq 0 (
    echo.
    echo   Browser sign-in failed. Trying a different method...
    echo   You will see a short code. Go to https://aka.ms/devicelogin in your
    echo   browser, enter the code, and sign in there.
    echo.
    call m365 login
    if %errorlevel% neq 0 (
        echo.
        echo   Sign-in failed. Please check your internet connection and try again.
        echo.
        pause
        exit /b 1
    )
)
echo   Signed in -- OK
echo.

:: ------------------------------------------------
:: STEP 5 -- Verify
:: ------------------------------------------------
echo [5/5] Checking the connection works...
call m365 outlook mail list --pageSize 3 >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Connected but could not read emails.
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
