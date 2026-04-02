@echo off
setlocal EnableDelayedExpansion
chcp 65001 > nul 2>&1

echo ================================================
echo   Claude AI Business Assistant -- GCP Setup
echo   Built by Selr AI -- selrai.com.au
echo ================================================
echo.

:: ------------------------------------------------
:: WINDOWS TERMINAL CHECK
:: The Claude sign-in step needs a proper terminal.
:: Warn if running in plain Command Prompt.
:: ------------------------------------------------
set TERMINAL_OK=0
if defined WT_SESSION set TERMINAL_OK=1
if defined TERM_PROGRAM set TERMINAL_OK=1

if %TERMINAL_OK% equ 0 (
    echo   NOTE: For the sign-in step later, you will need Windows Terminal.
    echo   If you do not have it, get it free from the Microsoft Store.
    echo   Search: "Windows Terminal" -- it is the one by Microsoft Corporation.
    echo   You can continue this script in any terminal -- but keep this in mind.
    echo.
)

:: ------------------------------------------------
:: STEP 1 -- Check gcloud is installed and signed in
:: ------------------------------------------------
echo [1/8] Checking Google Cloud CLI...
echo.

where gcloud > nul 2>&1
if %errorlevel% neq 0 (
    echo   Google Cloud CLI is not installed.
    echo   Install it from: https://cloud.google.com/sdk/docs/install
    echo   Then run this script again.
    echo.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('gcloud auth list --filter^=status:ACTIVE --format^="value(account)" 2^>nul') do set GCLOUD_ACCOUNT=%%i
if not defined GCLOUD_ACCOUNT (
    echo   You are not signed in to Google Cloud.
    echo   Run this command first:  gcloud auth login
    echo   Then run this script again.
    echo.
    pause
    exit /b 1
)
echo   Google Cloud CLI found.
echo   Signed in as: %GCLOUD_ACCOUNT%
echo.

:: ------------------------------------------------
:: QUESTION 1 -- GCP Project
:: ------------------------------------------------
echo   Your existing GCP projects:
echo.

set PROJECT_COUNT=0
set "PROJECT_LIST_FILE=%TEMP%\gcp_projects.txt"
gcloud projects list --format="value(projectId,name)" > "%PROJECT_LIST_FILE%" 2>nul

for /f "tokens=*" %%i in (%PROJECT_LIST_FILE%) do (
    set /a PROJECT_COUNT+=1
    set "PROJECT_LINE_!PROJECT_COUNT!=%%i"
    for /f "tokens=1" %%j in ("%%i") do set "PROJECT_ID_!PROJECT_COUNT!=%%j"
    echo   !PROJECT_COUNT!. %%i
)
echo.

:ASK_PROJECT
set /p PROJECT_CHOICE="  Which project? Enter the number, or NEW to create one: "
if /i "%PROJECT_CHOICE%"=="NEW" goto CREATE_PROJECT

set /a CHOICE_NUM=%PROJECT_CHOICE% 2>nul
if %CHOICE_NUM% lss 1 goto INVALID_PROJECT
if %CHOICE_NUM% gtr %PROJECT_COUNT% goto INVALID_PROJECT
set PROJECT=!PROJECT_ID_%CHOICE_NUM%!
goto PROJECT_DONE

:INVALID_PROJECT
echo   Please enter a number between 1 and %PROJECT_COUNT%, or NEW.
goto ASK_PROJECT

:CREATE_PROJECT
set /p NEW_PROJECT_NAME="  What would you like to call the new project? "
:: Sanitise to a valid project ID (lowercase, hyphens, max 28 chars)
powershell -NoProfile -Command ^
    "$id = '%NEW_PROJECT_NAME%'.ToLower() -replace '[^a-z0-9]','-' -replace '-+','-'; $id.Substring(0,[Math]::Min(28,$id.Length))" ^
    > "%TEMP%\project_id.txt" 2>nul
set /p NEW_PROJECT_ID=<"%TEMP%\project_id.txt"
echo   Creating project: %NEW_PROJECT_ID%...
gcloud projects create "%NEW_PROJECT_ID%" --name="%NEW_PROJECT_NAME%"
if %errorlevel% neq 0 (
    echo   Project creation failed. Check the name and try again.
    pause
    exit /b 1
)
set PROJECT=%NEW_PROJECT_ID%

:PROJECT_DONE
echo   Using project: %PROJECT%
echo.

:: ------------------------------------------------
:: QUESTION 2 -- Region
:: ------------------------------------------------
echo   Which region is closest to you?
echo.
echo   1. Australia (Sydney)  -- australia-southeast1
echo   2. USA (Iowa)          -- us-central1
echo   3. USA (Virginia)      -- us-east1
echo   4. Europe (Belgium)    -- europe-west1
echo   5. Asia (Singapore)    -- asia-southeast1
echo   6. Other -- I will type it myself
echo.

:ASK_REGION
set /p REGION_CHOICE="  Enter number (1-6): "
if "%REGION_CHOICE%"=="1" ( set REGION=australia-southeast1 & goto REGION_DONE )
if "%REGION_CHOICE%"=="2" ( set REGION=us-central1 & goto REGION_DONE )
if "%REGION_CHOICE%"=="3" ( set REGION=us-east1 & goto REGION_DONE )
if "%REGION_CHOICE%"=="4" ( set REGION=europe-west1 & goto REGION_DONE )
if "%REGION_CHOICE%"=="5" ( set REGION=asia-southeast1 & goto REGION_DONE )
if "%REGION_CHOICE%"=="6" ( set /p REGION="  Type your region: " & goto REGION_DONE )
echo   Please enter a number between 1 and 6.
goto ASK_REGION

:REGION_DONE
for /f "tokens=*" %%i in ('gcloud compute zones list --filter^="region:%REGION%" --format^="value(name)" 2^>nul') do (
    set ZONE=%%i
    goto ZONE_FOUND
)
:ZONE_FOUND
if not defined ZONE (
    echo   Could not find a zone in region '%REGION%'. Check the name and try again.
    pause
    exit /b 1
)
echo   Using region: %REGION% (zone: %ZONE%)
echo.

:: ------------------------------------------------
:: QUESTION 3 -- Messaging platform
:: ------------------------------------------------
echo   Which messaging app would you like to use?
echo.
echo   1. Telegram (recommended -- easiest to set up)
echo   2. Discord
echo   3. WhatsApp
echo   4. iMessage (Mac only -- not available on Windows)
echo.

:ASK_PLATFORM
set /p PLATFORM_CHOICE="  Enter number (1-4): "
if "%PLATFORM_CHOICE%"=="1" ( set PLATFORM=telegram & goto PLATFORM_DONE )
if "%PLATFORM_CHOICE%"=="2" ( set PLATFORM=discord & goto PLATFORM_DONE )
if "%PLATFORM_CHOICE%"=="3" ( set PLATFORM=whatsapp & goto PLATFORM_DONE )
if "%PLATFORM_CHOICE%"=="4" (
    echo.
    echo   iMessage is not available on Windows. Please choose 1, 2, or 3.
    goto ASK_PLATFORM
)
echo   Please enter a number between 1 and 3.
goto ASK_PLATFORM

:PLATFORM_DONE
set BOT_TOKEN=

if "%PLATFORM%"=="telegram" (
    echo.
    echo   You need a Telegram bot token.
    echo   Open Telegram -- search @BotFather -- send /newbot -- copy the token.
    echo.
    set /p BOT_TOKEN="  Paste your bot token: "
)
if "%PLATFORM%"=="discord" (
    echo.
    echo   You need a Discord bot token.
    echo   Go to discord.com/developers -- New Application -- Bot -- Reset Token.
    echo.
    set /p BOT_TOKEN="  Paste your bot token: "
)
if "%PLATFORM%"=="whatsapp" (
    echo.
    echo   You need a WhatsApp Business API token.
    echo   Get it from developers.facebook.com (Meta Business account required).
    echo.
    set /p BOT_TOKEN="  Paste your API token: "
)
echo.

:: ------------------------------------------------
:: STEP 2 -- Create the VM
:: ------------------------------------------------
echo [2/8] Creating your server...
echo.

set VM_NAME=claude-assistant
for /f "tokens=*" %%i in ('gcloud compute instances list --project^=%PROJECT% --filter^="name=claude-assistant" --format^="value(name)" 2^>nul') do set EXISTING=%%i
if defined EXISTING (
    set VM_NAME=claude-assistant-v2
    echo   'claude-assistant' already exists -- using 'claude-assistant-v2'.
)

gcloud compute instances create %VM_NAME% ^
    --project=%PROJECT% ^
    --zone=%ZONE% ^
    --machine-type=e2-standard-2 ^
    --image-family=ubuntu-2404-lts ^
    --image-project=ubuntu-os-cloud ^
    --boot-disk-size=50GB ^
    --boot-disk-type=pd-standard
if %errorlevel% neq 0 (
    echo.
    echo   VM creation failed. Common causes:
    echo   - Billing not enabled (visit console.cloud.google.com)
    echo   - Quota exceeded for this region (try a different region)
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('gcloud compute instances describe %VM_NAME% --project^=%PROJECT% --zone^=%ZONE% --format^="value(networkInterfaces[0].accessConfigs[0].natIP)" 2^>nul') do set VM_IP=%%i
echo.
echo   Server created: %VM_NAME% -- IP: %VM_IP%
echo   Waiting 20 seconds for it to boot...

powershell -NoProfile -Command "Start-Sleep -Seconds 20"

echo   Testing SSH...
set SSH_ATTEMPTS=0
:SSH_RETRY
gcloud compute ssh %VM_NAME% --project=%PROJECT% --zone=%ZONE% --command="echo OK" --quiet > nul 2>&1
if %errorlevel% neq 0 (
    set /a SSH_ATTEMPTS+=1
    if %SSH_ATTEMPTS% geq 4 (
        echo   SSH not responding after 4 attempts. Check the VM in GCP Console.
        pause
        exit /b 1
    )
    echo   Not ready yet -- waiting 10 more seconds...
    powershell -NoProfile -Command "Start-Sleep -Seconds 10"
    goto SSH_RETRY
)
echo   SSH working.
echo.

:: ------------------------------------------------
:: STEP 3 -- Install everything on the server
:: ------------------------------------------------
echo [3/8] Installing software on your server...
echo   This takes 3-5 minutes -- normal.
echo.

(
echo set -e
echo echo "  [3a] Adding 4GB swap space..."
echo sudo fallocate -l 4G /swapfile
echo sudo chmod 600 /swapfile
echo sudo mkswap /swapfile ^> /dev/null
echo sudo swapon /swapfile
echo echo '/swapfile none swap sw 0 0' ^| sudo tee -a /etc/fstab ^> /dev/null
echo echo "  [3b] Installing system tools..."
echo sudo apt-get update -qq
echo sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl git ffmpeg python3 python3-pip build-essential unzip 2^>^&1 ^| tail -2
echo echo "  [3c] Installing Node.js v22..."
echo curl -fsSL https://deb.nodesource.com/setup_22.x ^| sudo -E bash - 2^>/dev/null
echo sudo apt-get install -y nodejs 2^>^&1 ^| tail -2
echo node --version
echo echo "  [3d] Installing Bun..."
echo curl -fsSL https://bun.sh/install ^| bash 2^>/dev/null
echo echo 'export BUN_INSTALL="$HOME/.bun"' ^>^> ~/.bashrc
echo echo 'export PATH="$BUN_INSTALL/bin:$PATH"' ^>^> ~/.bashrc
echo echo 'export PATH="$HOME/.local/bin:$PATH"' ^>^> ~/.bashrc
echo echo "  [3e] Installing Whisper and voice model..."
echo pip3 install openai-whisper --quiet --break-system-packages
echo python3 -c "import whisper; whisper.load_model('tiny')" 2^>/dev/null
echo echo "       Voice model ready."
echo echo "  [3f] Installing Claude Code..."
echo curl -fsSL https://claude.ai/install.sh -o /tmp/install.sh
echo bash /tmp/install.sh 2^>/dev/null
echo echo "  All software installed."
) > "%TEMP%\gcp_install.sh"

gcloud compute ssh %VM_NAME% --project=%PROJECT% --zone=%ZONE% -- bash -s < "%TEMP%\gcp_install.sh"
if %errorlevel% neq 0 (
    echo   Installation failed. Check your internet connection and try again.
    pause
    exit /b 1
)
del "%TEMP%\gcp_install.sh" > nul 2>&1
echo.

:: ------------------------------------------------
:: STEP 4 -- Set up workspace
:: ------------------------------------------------
echo [4/8] Setting up assistant workspace...
echo.

(
echo set -e
echo echo "  [4a] Cloning workshop kit..."
echo git clone https://github.com/luke-selrai/openclaw-workshop-kit.git ~/workshop-kit 2^>^&1 ^| tail -1
echo echo "  [4b] Copying assistant files and skills..."
echo mkdir -p ~/my-assistant
echo cp ~/workshop-kit/my-assistant/CLAUDE.md ~/my-assistant/CLAUDE.md
echo mkdir -p ~/.claude/skills
echo cp -r ~/workshop-kit/skills/*/ ~/.claude/skills/ 2^>/dev/null ^|^| true
echo echo "  [4c] Marking workspace as trusted..."
echo python3 - ^<^< 'PYEOF'
echo import json, os
echo path = os.path.expanduser^('~/.claude.json'^)
echo with open^(path^) as f: d = json.load^(f^)
echo d['hasCompletedOnboarding'] = True
echo d['lastOnboardingVersion'] = 100
echo d['theme'] = 'dark'
echo if 'projects' not in d: d['projects'] = {}
echo home = os.path.expanduser^('~'^)
echo d['projects'][home + '/my-assistant'] = {'allowedTools': [], 'mcpContextUris': [], 'mcpServers': {}, 'enabledMcpjsonServers': [], 'disabledMcpjsonServers': [], 'hasTrustDialogAccepted': True, 'projectOnboardingSeenCount': 1, 'hasClaudeMdExternalIncludesApproved': True, 'hasClaudeMdExternalIncludesWarningShown': True}
echo with open^(path, 'w'^) as f: json.dump^(d, f, indent=2^)
echo print^('  Workspace trusted.'^)
echo PYEOF
) > "%TEMP%\gcp_workspace.sh"

gcloud compute ssh %VM_NAME% --project=%PROJECT% --zone=%ZONE% -- bash -s < "%TEMP%\gcp_workspace.sh"
del "%TEMP%\gcp_workspace.sh" > nul 2>&1
echo.

:: ------------------------------------------------
:: STEP 5 -- Create service files
:: ------------------------------------------------
echo [5/8] Creating background service files...
echo.

:: Write PTY wrapper locally with platform substituted, then copy to server
(
echo #!/usr/bin/env python3
echo import pty, os
echo.
echo def read(fd^):
echo     return os.read(fd, 1024^)
echo.
echo pty.spawn(
echo     [os.path.expanduser("~/.local/bin/claude"^), "--channels", "plugin:%PLATFORM%@claude-plugins-official"],
echo     master_read=read
echo )
) > "%TEMP%\start-claude.sh"

gcloud compute scp "%TEMP%\start-claude.sh" "%VM_NAME%:~/start-claude.sh" ^
    --project=%PROJECT% --zone=%ZONE% --quiet
gcloud compute ssh %VM_NAME% --project=%PROJECT% --zone=%ZONE% ^
    --command="chmod +x ~/start-claude.sh" --quiet

:: Get remote username for service file
for /f "tokens=*" %%i in ('gcloud compute ssh %VM_NAME% --project^=%PROJECT% --zone^=%ZONE% --command^="echo $USER" --quiet 2^>nul') do set REMOTE_USER=%%i

:: Write systemd service file
(
echo [Unit]
echo Description=Claude AI Assistant
echo After=network.target
echo.
echo [Service]
echo Type=simple
echo WorkingDirectory=%%h/my-assistant
echo Environment=PATH=/home/%REMOTE_USER%/.local/bin:/home/%REMOTE_USER%/.bun/bin:/usr/local/bin:/usr/bin:/bin
echo Environment=HOME=%%h
echo Environment=WHISPER_CACHE_DIR=%%h/.cache/whisper
echo ExecStart=/usr/bin/python3 /home/%REMOTE_USER%/start-claude.sh
echo Restart=on-failure
echo RestartSec=10
echo StandardOutput=append:%%h/claude-assistant.log
echo StandardError=append:%%h/claude-assistant.log
echo.
echo [Install]
echo WantedBy=default.target
) > "%TEMP%\claude-assistant.service"

gcloud compute ssh %VM_NAME% --project=%PROJECT% --zone=%ZONE% ^
    --command="mkdir -p ~/.config/systemd/user" --quiet
gcloud compute scp "%TEMP%\claude-assistant.service" ^
    "%VM_NAME%:~/.config/systemd/user/claude-assistant.service" ^
    --project=%PROJECT% --zone=%ZONE% --quiet

del "%TEMP%\start-claude.sh" > nul 2>&1
del "%TEMP%\claude-assistant.service" > nul 2>&1
echo   Service files created.
echo.

:: ------------------------------------------------
:: STEP 6 -- Manual: sign in, install plugin, pair
:: ------------------------------------------------
echo [6/8] ACTION REQUIRED -- Sign in and set up your messaging plugin
echo ================================================================
echo.
echo   Open Windows Terminal (or WSL) and run:
echo.
echo   gcloud compute ssh %VM_NAME% --project=%PROJECT% --zone=%ZONE%
echo.
echo   -- STEP A: Sign in to Claude ---------------------------------
echo   On the server, run:
echo.
echo     cd ~/my-assistant ^&^& claude .
echo.
echo   When prompted, press 1 (I have a Claude subscription^).
echo   A URL will appear -- open it in your browser, sign in, come back.
echo.
echo   -- STEP B: Install the %PLATFORM% plugin --------------------
echo   Inside Claude, type:
echo.
echo     /plugins
echo.
echo   Find '%PLATFORM%' in the list and install it. Then type /exit.
echo.
echo   -- STEP C: Configure token and pair -------------------------
echo   Back in the server terminal, run:
echo.
echo     claude . --channels plugin:%PLATFORM%@claude-plugins-official
echo.
if defined BOT_TOKEN (
    if "%PLATFORM%"=="telegram" (
        echo   Inside Claude, type:
        echo.
        echo     /telegram:configure %BOT_TOKEN%
        echo.
        echo   Then open Telegram, find your bot, send any message.
        echo   Your bot replies with a 6-character code. Then type:
        echo.
        echo     /telegram:access pair ^<the-code^>
        echo     /telegram:access policy allowlist
    )
    if "%PLATFORM%"=="discord" (
        echo   Inside Claude, type:
        echo.
        echo     /discord:configure %BOT_TOKEN%
        echo.
        echo   Then follow the pairing instructions shown by Claude.
    )
    if "%PLATFORM%"=="whatsapp" (
        echo   Inside Claude, type:
        echo.
        echo     /whatsapp:configure %BOT_TOKEN%
        echo.
        echo   Then follow the pairing instructions shown by Claude.
    )
    echo.
    echo   When done, type:  /exit
)
echo.
echo ================================================================
echo.
pause

:: ------------------------------------------------
:: STEP 7 -- Start the service
:: ------------------------------------------------
echo.
echo [7/8] Starting your assistant as a 24/7 background service...
echo.

(
echo set -e
echo loginctl enable-linger "$USER"
echo systemctl --user daemon-reload
echo systemctl --user enable claude-assistant
echo systemctl --user start claude-assistant
echo echo "  Service started."
) > "%TEMP%\gcp_startservice.sh"

gcloud compute ssh %VM_NAME% --project=%PROJECT% --zone=%ZONE% -- bash -s < "%TEMP%\gcp_startservice.sh"
del "%TEMP%\gcp_startservice.sh" > nul 2>&1

echo   Waiting 15 seconds...
powershell -NoProfile -Command "Start-Sleep -Seconds 15"
echo.

:: ------------------------------------------------
:: STEP 8 -- Verify
:: ------------------------------------------------
echo [8/8] Checking service status...
echo.

for /f "tokens=*" %%i in ('gcloud compute ssh %VM_NAME% --project^=%PROJECT% --zone^=%ZONE% --command^="systemctl --user is-active claude-assistant 2>/dev/null" --quiet 2^>nul') do set SERVICE_STATUS=%%i
echo   Service: %SERVICE_STATUS%

echo   Last log lines:
gcloud compute ssh %VM_NAME% --project=%PROJECT% --zone=%ZONE% ^
    --command="tail -5 ~/claude-assistant.log 2>/dev/null || echo '(log not yet available)'" --quiet

echo.

:: Check for known issues in log
for /f "tokens=*" %%i in ('gcloud compute ssh %VM_NAME% --project^=%PROJECT% --zone^=%ZONE% --command^="tail -20 ~/claude-assistant.log 2>/dev/null" --quiet 2^>nul') do (
    echo %%i | findstr /i "plugin not installed" > nul 2>&1
    if !errorlevel! equ 0 (
        echo   WARNING: Plugin not installed correctly.
        echo   SSH back in and repeat Step B (install plugin via /plugins^).
        echo   Then run: systemctl --user restart claude-assistant
    )
    echo %%i | findstr /i "Listening for channel messages" > nul 2>&1
    if !errorlevel! equ 0 (
        echo   Confirmed: assistant is listening for messages.
    )
)

echo.
echo ================================================
echo   Setup complete!
echo.
echo   Server:   %VM_NAME%
echo   IP:       %VM_IP%
echo   Platform: %PLATFORM%
echo.
echo   Open %PLATFORM%, find your bot, and send:
echo     hello
echo.
echo   Your assistant will introduce itself and ask
echo   7 questions about your business.
echo.
echo   Monthly cost: ~AUD 49-61/month
echo   Stop to save costs:
echo   gcloud compute instances stop %VM_NAME% --project=%PROJECT% --zone=%ZONE%
echo ================================================
echo.
pause
endlocal
