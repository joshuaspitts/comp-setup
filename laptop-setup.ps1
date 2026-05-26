#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Fresh laptop build script — installs all apps via winget in one shot.
.DESCRIPTION
    Run this on a new Windows 11 machine to get to a working state fast.
    Idempotent: safe to re-run; already-installed apps are skipped.

    Normally called via bootstrap.ps1 which handles downloading all scripts.
    Can also be run directly:

        Set-ExecutionPolicy -Scope Process Bypass
        .\laptop-setup.ps1

    Flags:
        -RunDebloat          Run debloat.ps1 BEFORE installs (recommended on fresh OS)
        -SkipProfileSetup    Skip profile-setup.ps1 (Oh My Posh + CLI completions)
        -SkipStartupClean    Skip startup-cleanup.ps1
        -SkipScheduledTask   Skip registering scheduled tasks
#>
param(
    [switch]$RunDebloat,
    [switch]$SkipProfileSetup,
    [switch]$SkipStartupClean,
    [switch]$SkipScheduledTask
)

$ErrorActionPreference = "Continue"

# ── Paths — all derived from environment, never hardcoded ────────────────────
$PermDir  = Join-Path $env:USERPROFILE "Scripts"   # permanent home for these scripts
$Username = $env:USERNAME

# Convert PermDir to its WSL equivalent (e.g. C:\Users\Foo\Scripts → /mnt/c/Users/Foo/Scripts)
$WslScriptsPath = "/mnt/" + ($PermDir[0].ToString().ToLower()) +
                  ($PermDir.Substring(2) -replace '\\', '/')

# If this script is running from somewhere other than PermDir (e.g. %TEMP% after curl),
# copy all scripts to the permanent location first so scheduled tasks have a stable path.
$ScriptDir = $PSScriptRoot
if ((Resolve-Path $ScriptDir -ErrorAction SilentlyContinue)?.Path -ne
    (Resolve-Path $PermDir   -ErrorAction SilentlyContinue)?.Path) {
    Write-Host "`n  Installing scripts to $PermDir..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $PermDir | Out-Null
    Get-ChildItem $ScriptDir | Copy-Item -Destination $PermDir -Force
    $ScriptDir = $PermDir
}

# ── Helpers ───────────────────────────────────────────────────────────────────
function Install-WingetApp {
    param([string]$Id, [string]$Label, [string]$Source = "winget")
    Write-Host "`n  Installing $Label ($Id)..." -ForegroundColor Cyan
    winget install --id $Id --exact --source $Source `
        --accept-source-agreements --accept-package-agreements --silent
}

function Write-Section {
    param([string]$Title)
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
}

function Invoke-Script {
    param([string]$Name)
    $path = Join-Path $ScriptDir $Name
    if (Test-Path $path) { & $path } else { Write-Warning "$Name not found at $path — skipping." }
}

function Register-SetupTask {
    param(
        [string]$TaskName,
        [string]$Description,
        [string]$Execute,
        [string]$Argument,
        [string]$DayOfWeek = "Sunday",
        [string]$StartTime = "9:00AM",
        [int]   $RunLevel  = 1           # 1 = Highest, 0 = Limited
    )
    $action   = New-ScheduledTaskAction -Execute $Execute -Argument $Argument
    $trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $StartTime
    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -StartWhenAvailable -RunOnlyIfNetworkAvailable -MultipleInstances IgnoreNew
    $level     = if ($RunLevel -eq 1) { "Highest" } else { "Limited" }
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel $level

    Register-ScheduledTask -TaskName $TaskName -TaskPath "\$Username\" `
        -Action $action -Trigger $trigger -Settings $settings `
        -Principal $principal -Force -Description $Description | Out-Null

    Write-Host "  Registered: \$Username\$TaskName ($DayOfWeek @ $StartTime)" -ForegroundColor Green
}

Write-Section "Laptop Setup — running as $Username"

# ── [0] Optional Debloat — runs BEFORE everything else ───────────────────────
if ($RunDebloat) {
    Write-Host "`n[0] Debloat..." -ForegroundColor Green
    Invoke-Script "debloat.ps1"
}

# ── [1/13] System Tweaks ──────────────────────────────────────────────────────
Write-Host "`n[1/13] System Tweaks" -ForegroundColor Green

Write-Host "`n  Enabling long path support (>260 chars)..." -ForegroundColor Cyan
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
    -Name LongPathsEnabled -Value 1 -Type DWord -Force

Write-Host "  Enabling Windows Developer Mode (symlinks without admin)..." -ForegroundColor Cyan
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
    -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord -Force

Write-Host "  Setting power plan to High Performance..." -ForegroundColor Cyan
powercfg /setactive SCHEME_MIN

# ── [2/13] WSL2 ───────────────────────────────────────────────────────────────
Write-Host "`n[2/13] WSL2" -ForegroundColor Green
Write-Host "`n  Enabling WSL2..." -ForegroundColor Cyan
wsl --install --no-distribution 2>&1
Write-Host "  Install Ubuntu after reboot: wsl --install -d Ubuntu" -ForegroundColor DarkGray

$wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
if (-not (Test-Path $wslConfigPath)) {
    @"
[wsl2]
memory=8GB
processors=4
swap=2GB
localhostForwarding=true
"@ | Set-Content $wslConfigPath
    Write-Host "  Created .wslconfig (8 GB RAM, 4 CPUs, 2 GB swap)" -ForegroundColor DarkGray
} else {
    Write-Host "  .wslconfig already exists — not overwriting." -ForegroundColor DarkGray
}

# ── [3/13] Shell & Dev Foundations ───────────────────────────────────────────
Write-Host "`n[3/13] Shell & Dev Foundations" -ForegroundColor Green
Install-WingetApp "Microsoft.PowerShell"      "PowerShell 7"
Install-WingetApp "Microsoft.WindowsTerminal" "Windows Terminal"
Install-WingetApp "JanDeDobbeleer.OhMyPosh"   "Oh My Posh"
Install-WingetApp "Git.Git"                   "Git"
Install-WingetApp "GitHub.cli"                "GitHub CLI (gh)"
Install-WingetApp "OpenJS.NodeJS.LTS"         "Node.js LTS"
Install-WingetApp "Python.Python.3.13"        "Python 3.13"
Install-WingetApp "BurntSushi.ripgrep.MSVC"   "ripgrep"

# ── [4/13] Package Management & Dev Tooling ──────────────────────────────────
Write-Host "`n[4/13] Package Management & Dev Tooling" -ForegroundColor Green

Install-WingetApp "dandavison.delta"  "delta (better git diffs)"
Install-WingetApp "twpayne.chezmoi"   "chezmoi (dotfiles manager)"

# Refresh PATH so Python/pip installed above are usable in this session
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")

Write-Host "`n  Installing pipx via pip..." -ForegroundColor Cyan
python -m pip install --upgrade pip --quiet
python -m pip install --user pipx --quiet
python -m pipx ensurepath

Write-Host "`n  Installing pyenv-win..." -ForegroundColor Cyan
$pyenvInstaller = Join-Path $env:TEMP "install-pyenv-win.ps1"
Invoke-WebRequest -UseBasicParsing `
    -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" `
    -OutFile $pyenvInstaller
& $pyenvInstaller
Remove-Item $pyenvInstaller -ErrorAction SilentlyContinue

Write-Host "`n  [INFO] Scoop requires a non-admin terminal — run after reboot:" -ForegroundColor DarkYellow
Write-Host "    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor DarkGray
Write-Host "    irm get.scoop.sh | iex" -ForegroundColor DarkGray
Write-Host "    scoop install eza zoxide" -ForegroundColor DarkGray

# ── [5/13] CLI Utilities ──────────────────────────────────────────────────────
Write-Host "`n[5/13] CLI Utilities" -ForegroundColor Green
Install-WingetApp "jqlang.jq"      "jq (JSON processor)"
Install-WingetApp "MikeFarah.yq"   "yq (YAML processor)"
Install-WingetApp "sharkdp.bat"    "bat (better cat)"
Install-WingetApp "sharkdp.fd"     "fd (better find)"
Install-WingetApp "junegunn.fzf"   "fzf (fuzzy finder)"
Install-WingetApp "GNU.Wget2"      "wget2"

# ── [6/13] Cloud CLIs ─────────────────────────────────────────────────────────
Write-Host "`n[6/13] Cloud CLIs" -ForegroundColor Green
Install-WingetApp "Amazon.AWSCLI"      "AWS CLI"
Install-WingetApp "Microsoft.AzureCLI" "Azure CLI"
Install-WingetApp "Google.CloudSDK"    "Google Cloud SDK (gcloud)"

# ── [7/13] Containers & Kubernetes ───────────────────────────────────────────
Write-Host "`n[7/13] Containers & Kubernetes" -ForegroundColor Green
Install-WingetApp "Docker.DockerDesktop" "Docker Desktop"
Install-WingetApp "Kubernetes.kubectl"   "kubectl"
Install-WingetApp "Helm.Helm"            "Helm"
Install-WingetApp "Derailed.k9s"         "k9s (K8s TUI)"
Install-WingetApp "Mirantis.Lens"        "Lens (K8s IDE)"

# ── [8/13] Infrastructure as Code ────────────────────────────────────────────
Write-Host "`n[8/13] Infrastructure as Code" -ForegroundColor Green
Install-WingetApp "Hashicorp.Terraform" "Terraform"

# ── [9/13] Remote & Networking ────────────────────────────────────────────────
Write-Host "`n[9/13] Remote & Networking" -ForegroundColor Green
Install-WingetApp "Tailscale.Tailscale" "Tailscale"
Install-WingetApp "WinSCP.WinSCP"       "WinSCP"
Install-WingetApp "PuTTY.PuTTY"         "PuTTY"

# ── [10/13] Browsers ──────────────────────────────────────────────────────────
Write-Host "`n[10/13] Browsers" -ForegroundColor Green
Install-WingetApp "Mozilla.Firefox"  "Firefox"
Install-WingetApp "Brave.Brave"      "Brave"
Install-WingetApp "Google.Chrome"    "Google Chrome"
Install-WingetApp "Microsoft.Edge"   "Microsoft Edge"

# ── [11/13] Productivity, Notes & Editors ────────────────────────────────────
Write-Host "`n[11/13] Productivity, Notes & Editors" -ForegroundColor Green
Install-WingetApp "Microsoft.VisualStudioCode" "Visual Studio Code"
Install-WingetApp "Obsidian.Obsidian"          "Obsidian"
Install-WingetApp "Notion.Notion"              "Notion"
Install-WingetApp "DBeaver.DBeaver.Community"  "DBeaver CE"
Install-WingetApp "Notepad++.Notepad++"        "Notepad++"
Install-WingetApp "JackieLiu.NotepadsApp"      "Notepads"
Install-WingetApp "Geany.Geany"                "Geany"
Install-WingetApp "SublimeHQ.SublimeText.4"    "Sublime Text 4"

# ── [12/13] Password Managers ─────────────────────────────────────────────────
Write-Host "`n[12/13] Password Managers" -ForegroundColor Green
Install-WingetApp "AgileBits.1Password"     "1Password"
Install-WingetApp "AgileBits.1Password.CLI" "1Password CLI (op)"
Install-WingetApp "Bitwarden.Bitwarden"     "Bitwarden"

# ── [13/13] Communication, AI & Gaming ───────────────────────────────────────
Write-Host "`n[13/13] Communication, AI & Gaming" -ForegroundColor Green
Install-WingetApp "Discord.Discord"       "Discord"
Install-WingetApp "Anthropic.Claude"      "Claude Desktop"
Install-WingetApp "Anthropic.ClaudeCode"  "Claude Code CLI"
Install-WingetApp "OpenAI.Codex"          "Codex CLI (OpenAI)"

Write-Host "`n  Installing ChatGPT (official MS Store)..." -ForegroundColor Cyan
winget install --id 9N59P93TTH8K --source msstore `
    --accept-source-agreements --accept-package-agreements --silent
if ($LASTEXITCODE -ne 0) {
    Write-Warning "  ChatGPT Store install failed. Install manually: https://apps.microsoft.com/detail/9N59P93TTH8K"
}

# Refresh PATH so npm is available in this session
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")

Write-Host "`n  Installing Gemini CLI via npm..." -ForegroundColor Cyan
npm install -g @google/gemini-cli
if ($LASTEXITCODE -ne 0) {
    Write-Warning "  Gemini CLI failed. Run after reboot: npm install -g @google/gemini-cli"
}

Install-WingetApp "Valve.Steam"        "Steam"
Install-WingetApp "Blizzard.BattleNet" "Battle.net"

# ── Self-updating apps (excluded from winget) ─────────────────────────────────
Write-Host "`n----------------------------------------" -ForegroundColor DarkGray
Write-Host "  Self-updating (not winget-managed):" -ForegroundColor DarkGray
@(
    "Microsoft 365/Office  → Click-to-Run",
    "NVIDIA drivers/App    → NVIDIA App",
    "AMD Radeon            → AMD Software: Adrenalin",
    "ASUS suite            → MyASUS / Armoury Crate",
    "Game titles           → Steam / Battle.net",
    "Gemini CLI            → winget-update.ps1 handles via npm"
) | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

# ── PowerShell Profile + CLI Completions ─────────────────────────────────────
if (-not $SkipProfileSetup) {
    Write-Section "PowerShell Profile Setup"
    Invoke-Script "profile-setup.ps1"
}

# ── Startup Cleanup ───────────────────────────────────────────────────────────
if (-not $SkipStartupClean) {
    Write-Section "Startup Cleanup"
    Invoke-Script "startup-cleanup.ps1"
}

# ── Scheduled Tasks ───────────────────────────────────────────────────────────
if (-not $SkipScheduledTask) {
    Write-Section "Registering Scheduled Tasks"

    $updateScript = Join-Path $ScriptDir "winget-update.ps1"
    if (Test-Path $updateScript) {
        Register-SetupTask `
            -TaskName   "WingetWeeklyUpgrade" `
            -Description "Weekly upgrade: winget + npm + pip globals." `
            -Execute    "pwsh.exe" `
            -Argument   "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$updateScript`"" `
            -DayOfWeek  "Sunday" `
            -StartTime  "9:00AM" `
            -RunLevel   1
    } else {
        Write-Warning "winget-update.ps1 not found — skipping winget task."
    }

    # WSL apt update — runs limited (no elevation needed for wsl.exe)
    # Requires passwordless sudo for apt — wsl-bootstrap.sh configures this.
    Register-SetupTask `
        -TaskName   "WSLWeeklyAptUpgrade" `
        -Description "Weekly apt update + upgrade inside WSL Ubuntu." `
        -Execute    "wsl.exe" `
        -Argument   "-d Ubuntu -- bash -c `"sudo apt update -qq && sudo apt upgrade -y`"" `
        -DayOfWeek  "Sunday" `
        -StartTime  "9:30AM" `
        -RunLevel   0

    Write-Host "`n  View in: Task Scheduler > Task Scheduler Library > $Username" -ForegroundColor DarkGray
}

# ── Post-reboot checklist ─────────────────────────────────────────────────────
Write-Section "Setup complete! Reboot recommended."
Write-Host "  Post-reboot checklist:" -ForegroundColor DarkGray
Write-Host "    1.  wsl --install -d Ubuntu" -ForegroundColor DarkGray
Write-Host "    2.  wsl -d Ubuntu -- bash $WslScriptsPath/wsl-bootstrap.sh" -ForegroundColor DarkGray
Write-Host "    3.  Open non-admin terminal for Scoop:" -ForegroundColor DarkGray
Write-Host "        irm get.scoop.sh | iex  &&  scoop install eza zoxide" -ForegroundColor DarkGray
Write-Host "    4.  Authenticate cloud CLIs:" -ForegroundColor DarkGray
Write-Host "        aws configure  |  az login  |  gcloud init  |  gh auth login" -ForegroundColor DarkGray

Write-Host "`n  Full remaining-tasks checklist:" -ForegroundColor Yellow
Write-Host "    $ScriptDir\todo.md     (Markdown)"   -ForegroundColor DarkGray
Write-Host "    $ScriptDir\todo.html   (dark-mode interactive)" -ForegroundColor DarkGray

$todoHtml = Join-Path $ScriptDir "todo.html"
if (Test-Path $todoHtml) {
    Write-Host "`n  Opening todo.html in your default browser..." -ForegroundColor Cyan
    Start-Process $todoHtml
} else {
    Write-Warning "todo.html not found at $todoHtml — open todo.md manually."
}
