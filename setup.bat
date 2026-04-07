@echo off
setlocal EnableDelayedExpansion
echo.
echo ================================================
echo   Claude Code AI Business Assistant — Setup
echo   Built by Selr AI -- selrai.com.au
echo ================================================
echo.

:: ------------------------------------------------
:: CONFIG
:: ------------------------------------------------
set REPO_URL=https://github.com/luke-selrai/openclaw-workshop-kit.git
set KIT_DIR=%USERPROFILE%\workshop-kit
set ASSISTANT_DIR=%USERPROFILE%\my-assistant
set SKILLS_DIR=%USERPROFILE%\.claude\skills
set LOG_FILE=%TEMP%\workshop-setup.log

:: Clear previous log
echo Workshop Kit Setup — %date% %time% > "%LOG_FILE%"

:: ------------------------------------------------
:: ADMIN CHECK  (non-blocking)
:: ------------------------------------------------
net session >nul 2>&1
set IS_ADMIN=%errorlevel%
if %IS_ADMIN% neq 0 (
    echo   Note: Not running as Administrator.
    echo   If the install fails with a permissions error,
    echo   right-click setup.bat ^> "Run as administrator"
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
    echo   Warning: This folder path is very long.
    echo   Windows has a 260-character limit. If errors appear,
    echo   move this file closer to C:\ and try again.
    echo.
)

:: ------------------------------------------------
:: POWERSHELL EXECUTION POLICY  (preemptive fix)
:: ------------------------------------------------
powershell -NoProfile -Command ^
    "if (@('Restricted','Undefined') -contains (Get-ExecutionPolicy -Scope CurrentUser)) { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host 'FIXED' }" ^
    2>nul | findstr /i "FIXED" >nul 2>&1
if %errorlevel% equ 0 (
    echo   Fixed PowerShell execution policy.
    echo.
)

:: ================================================
:: STEP 1 — Check Node.js
:: ================================================
echo [1/7] Checking Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Node.js is not installed.
    echo   Please install it from: https://nodejs.org
    echo   Download the LTS version ^(v22 or v20^), run the installer,
    echo   then close and reopen this window and run setup.bat again.
    echo.
    echo   FAILED: Node.js not found >> "%LOG_FILE%"
    pause
    exit /b 1
)

for /f "tokens=1 delims=v" %%i in ('node --version') do set NODERAW=%%i
for /f "tokens=1 delims=." %%i in ("%NODERAW%") do set NODEMAJOR=%%i
if %NODEMAJOR% LSS 20 (
    echo.
    echo   Your Node.js is too old ^(found: v%NODERAW%^).
    echo   Please update to v20 or higher at https://nodejs.org
    echo   then run setup.bat again.
    echo.
    echo   FAILED: Node.js v%NODERAW% too old >> "%LOG_FILE%"
    pause
    exit /b 1
)
echo   Node.js v%NODERAW% — OK
echo   Node.js v%NODERAW% — OK >> "%LOG_FILE%"
echo.

:: ================================================
:: STEP 2 — Check Git
:: ================================================
echo [2/7] Checking Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Git is not installed or not in your PATH.
    echo.
    echo   Option 1 — Install Git:
    echo     Download from: https://git-scm.com/download/win
    echo     Run the installer with all default settings.
    echo.
    echo   Option 2 — Fix the PATH ^(if Git is already installed^):
    echo     1. Press the Windows key
    echo     2. Type: Environment Variables
    echo     3. Click "Edit the system environment variables"
    echo     4. Click "Environment Variables" at the bottom
    echo     5. In System variables, find "Path" and click Edit
    echo     6. Click New and type: C:\Program Files\Git\cmd
    echo     7. Click OK, OK, OK
    echo.
    echo   After installing or fixing PATH, close this window and run setup.bat again.
    echo.

    :: Try to auto-detect Git in common locations
    if exist "C:\Program Files\Git\cmd\git.exe" (
        echo   ** Git IS installed at C:\Program Files\Git but is not in your PATH.
        echo   ** Adding it now...
        set "PATH=C:\Program Files\Git\cmd;%PATH%"
        git --version >nul 2>&1
        if !errorlevel! equ 0 (
            echo   ** Fixed! Git is now available for this session.
            echo   ** To make this permanent, follow the PATH fix above or restart your computer.
            echo.
            goto GIT_OK
        )
    )

    echo   FAILED: Git not found >> "%LOG_FILE%"
    pause
    exit /b 1
)

:GIT_OK
for /f "tokens=*" %%i in ('git --version') do set GITVER=%%i
echo   %GITVER% — OK
echo   %GITVER% — OK >> "%LOG_FILE%"
echo.

:: ================================================
:: STEP 3 — Check VS Code
:: ================================================
echo [3/7] Checking VS Code...
where code >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   VS Code is not installed or not in your PATH.
    echo   Please install it from: https://code.visualstudio.com
    echo   IMPORTANT: During install, tick "Add to PATH"
    echo   Then close this window and run setup.bat again.
    echo.
    echo   WARNING: VS Code not in PATH — continuing anyway >> "%LOG_FILE%"
    echo   Continuing without VS Code auto-open...
    echo.
    set VSCODE_AVAILABLE=0
) else (
    echo   VS Code — OK
    echo   VS Code — OK >> "%LOG_FILE%"
    set VSCODE_AVAILABLE=1
)
echo.

:: ================================================
:: STEP 4 — Check Claude Code Extension
:: ================================================
echo [4/7] Checking Claude Code extension...
set CLAUDE_EXT_FOUND=0
where code >nul 2>&1
if %errorlevel% equ 0 (
    code --list-extensions 2>nul | findstr /i "anthropic" >nul 2>&1
    if !errorlevel! equ 0 (
        set CLAUDE_EXT_FOUND=1
    )
)

if %CLAUDE_EXT_FOUND% equ 1 (
    echo   Claude Code extension — OK
    echo   Claude Code extension — OK >> "%LOG_FILE%"
) else (
    echo   Claude Code extension not detected.
    echo   After setup, open VS Code and install it:
    echo     1. Click Extensions icon ^(left sidebar^)
    echo     2. Search: Claude Code
    echo     3. Install the one by Anthropic
    echo.
    echo   WARNING: Claude Code extension not found >> "%LOG_FILE%"
)
echo.

:: ================================================
:: STEP 5 — Clone or Update Workshop Kit
:: ================================================
echo [5/7] Downloading workshop content...

if exist "%KIT_DIR%\.git" (
    echo   Workshop kit already downloaded. Updating...
    pushd "%KIT_DIR%"
    git pull origin main >"%TEMP%\workshop-git.txt" 2>&1
    set GIT_EXIT=!errorlevel!
    popd
    if !GIT_EXIT! neq 0 (
        echo   Could not update. Using existing version.
        echo   WARNING: git pull failed >> "%LOG_FILE%"
        type "%TEMP%\workshop-git.txt" >> "%LOG_FILE%"
    ) else (
        echo   Updated to latest version — OK
        echo   git pull — OK >> "%LOG_FILE%"
    )
    del "%TEMP%\workshop-git.txt" >nul 2>&1
) else (
    if exist "%KIT_DIR%" (
        echo   Folder exists but is not a git repo. Removing and re-downloading...
        rmdir /s /q "%KIT_DIR%" >nul 2>&1
    )
    git clone "%REPO_URL%" "%KIT_DIR%" >"%TEMP%\workshop-git.txt" 2>&1
    set GIT_EXIT=!errorlevel!
    if !GIT_EXIT! neq 0 (
        echo.
        echo   Failed to download workshop content.
        echo   Please check your internet connection and try again.
        echo.
        echo   If you are behind a corporate firewall, ask your IT team
        echo   to allow access to github.com
        echo.
        echo   FAILED: git clone >> "%LOG_FILE%"
        type "%TEMP%\workshop-git.txt" >> "%LOG_FILE%"
        del "%TEMP%\workshop-git.txt" >nul 2>&1
        pause
        exit /b 1
    )
    del "%TEMP%\workshop-git.txt" >nul 2>&1
    echo   Workshop kit downloaded — OK
    echo   git clone — OK >> "%LOG_FILE%"
)
echo.

:: ================================================
:: STEP 6 — Copy Files
:: ================================================
echo [6/7] Setting up your AI assistant...

:: Create my-assistant directory
if not exist "%ASSISTANT_DIR%" (
    mkdir "%ASSISTANT_DIR%"
    echo   Created: %ASSISTANT_DIR%
)

:: Copy CLAUDE.md (the AI brain)
if exist "%KIT_DIR%\my-assistant\CLAUDE.md" (
    copy /y "%KIT_DIR%\my-assistant\CLAUDE.md" "%ASSISTANT_DIR%\CLAUDE.md" >nul 2>&1
    echo   Copied CLAUDE.md — OK
    echo   CLAUDE.md copied >> "%LOG_FILE%"
) else (
    echo   WARNING: CLAUDE.md not found in workshop kit
    echo   FAILED: CLAUDE.md not found >> "%LOG_FILE%"
)

:: Create skills directory
if not exist "%SKILLS_DIR%" (
    mkdir "%SKILLS_DIR%"
    echo   Created skills directory
)

:: Copy all skill folders (skip files, only copy folders)
set SKILL_COUNT=0
for /d %%d in ("%KIT_DIR%\skills\*") do (
    set SKILL_NAME=%%~nxd
    xcopy /s /e /y /q "%%d" "%SKILLS_DIR%\!SKILL_NAME!\" >nul 2>&1
    set /a SKILL_COUNT+=1
)
echo   Installed %SKILL_COUNT% skills — OK
echo   %SKILL_COUNT% skills installed >> "%LOG_FILE%"

:: Create memory directory if it doesn't exist
if not exist "%ASSISTANT_DIR%\memory" (
    mkdir "%ASSISTANT_DIR%\memory"
    echo   Created memory directory
)

echo.

:: ================================================
:: STEP 7 — Verify Everything
:: ================================================
echo [7/7] Verifying setup...
echo.

set PASS_COUNT=0
set FAIL_COUNT=0

:: Check CLAUDE.md exists
if exist "%ASSISTANT_DIR%\CLAUDE.md" (
    echo   [OK] CLAUDE.md is in place
    set /a PASS_COUNT+=1
) else (
    echo   [!!] CLAUDE.md is missing
    set /a FAIL_COUNT+=1
)

:: Check skills were copied
set INSTALLED_SKILLS=0
for /d %%d in ("%SKILLS_DIR%\*") do set /a INSTALLED_SKILLS+=1
if %INSTALLED_SKILLS% GEQ 80 (
    echo   [OK] %INSTALLED_SKILLS% skills installed
    set /a PASS_COUNT+=1
) else if %INSTALLED_SKILLS% GEQ 1 (
    echo   [OK] %INSTALLED_SKILLS% skills installed ^(expected ~87^)
    set /a PASS_COUNT+=1
) else (
    echo   [!!] No skills found in %SKILLS_DIR%
    set /a FAIL_COUNT+=1
)

:: Check Node.js
node --version >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Node.js is working
    set /a PASS_COUNT+=1
) else (
    echo   [!!] Node.js not working
    set /a FAIL_COUNT+=1
)

:: Check Git
git --version >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Git is working
    set /a PASS_COUNT+=1
) else (
    echo   [!!] Git not working
    set /a FAIL_COUNT+=1
)

echo.

:: ================================================
:: DONE
:: ================================================
if %FAIL_COUNT% equ 0 (
    echo ================================================
    echo   Setup complete! Everything looks good.
    echo   %PASS_COUNT%/%PASS_COUNT% checks passed.
    echo ================================================
    echo.
    echo   NEXT STEPS:
    echo.
    echo   1. Open VS Code
    echo   2. Open the folder: %ASSISTANT_DIR%
    if %VSCODE_AVAILABLE% equ 1 (
        echo      ^(Or press any key and we will open it for you^)
    ) else (
        echo      Press Ctrl+Shift+P ^> type "open folder"
        echo      Navigate to: %ASSISTANT_DIR%
    )
    echo   3. Click the Claude icon in the left sidebar
    echo   4. Type "hello" and press Enter
    echo   5. Your assistant will introduce itself and ask about your business
    echo.
    echo   Setup log saved to: %LOG_FILE%
    echo.
    echo   SETUP COMPLETE >> "%LOG_FILE%"

    if %VSCODE_AVAILABLE% equ 1 (
        echo   Press any key to open VS Code with your assistant...
        pause >nul
        code "%ASSISTANT_DIR%"
    ) else (
        pause
    )
) else (
    echo ================================================
    echo   Setup finished with %FAIL_COUNT% issue^(s^).
    echo   %PASS_COUNT% passed, %FAIL_COUNT% failed.
    echo ================================================
    echo.
    echo   Check the issues above and try running setup.bat again.
    echo   Setup log: %LOG_FILE%
    echo.
    echo   Need help? Email luke@selrai.com.au
    echo.
    echo   SETUP INCOMPLETE: %FAIL_COUNT% failures >> "%LOG_FILE%"
    pause
)

endlocal
