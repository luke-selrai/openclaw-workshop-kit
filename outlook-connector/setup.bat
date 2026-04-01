@echo off
echo ================================================
echo   Outlook ^& Microsoft 365 Connector Setup
echo   Built by Selr AI — selrai.com.au
echo ================================================
echo.

echo Checking Node.js is installed...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed.
    echo Please install it from https://nodejs.org and run this again.
    pause
    exit /b 1
)
echo Node.js found.
echo.

echo Installing the Microsoft 365 tool...
echo This may take a minute — that is normal.
echo.
npm install -g @pnp/cli-microsoft365
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Install failed. Check your internet connection and try again.
    pause
    exit /b 1
)
echo.
echo Install complete!
echo.

echo Signing in to your Microsoft account...
echo A browser window is about to open.
echo Pick the Microsoft account you want to use, then click Allow.
echo.
m365 login --authType browser
if %errorlevel% neq 0 (
    echo.
    echo Browser login failed. Trying device code login instead...
    m365 login
)
echo.

echo Verifying the connection...
m365 outlook mail list --pageSize 3
echo.
echo ================================================
echo   Done! Your Microsoft 365 account is connected.
echo   Ask your assistant: "Show me my unread emails"
echo ================================================
echo.
pause
