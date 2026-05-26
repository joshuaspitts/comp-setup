#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets up the PowerShell profile with Oh My Posh, CLI completions, and aliases.
.DESCRIPTION
    - Installs Oh My Posh (if not already done by laptop-setup.ps1)
    - Installs a Nerd Font (JetBrainsMono) for Oh My Posh glyph support
    - Installs PSFzf PowerShell module for fzf key bindings
    - Writes Scripts\powershell-profile.ps1 (the actual profile content)
    - Adds a single dot-source line to $PROFILE so it's loaded on every shell

    The profile content lives in Scripts\powershell-profile.ps1 so it's
    easy to edit, version-control, and re-apply without re-running this script.
#>

$ErrorActionPreference = "Continue"
$ScriptDir  = $PSScriptRoot
$ProfileContent = Join-Path $ScriptDir "powershell-profile.ps1"

Write-Host "`n  Installing Oh My Posh..." -ForegroundColor Cyan
winget install --id JanDeDobbeleer.OhMyPosh --exact --source winget `
    --accept-source-agreements --accept-package-agreements --silent

# Refresh PATH so oh-my-posh is available in this session
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")

Write-Host "  Installing JetBrainsMono Nerd Font (required for Oh My Posh glyphs)..." -ForegroundColor Cyan
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh font install JetBrainsMono
} else {
    Write-Warning "  oh-my-posh not on PATH yet — font install skipped. Run manually: oh-my-posh font install JetBrainsMono"
}

Write-Host "  Installing PSFzf PowerShell module (fzf key bindings)..." -ForegroundColor Cyan
Install-Module -Name PSFzf -Force -Scope CurrentUser -ErrorAction SilentlyContinue

Write-Host "  Installing PSReadLine (latest, for better history/completion)..." -ForegroundColor Cyan
Install-Module -Name PSReadLine -Force -Scope CurrentUser -AllowPrerelease -ErrorAction SilentlyContinue

# ── Write the profile content file ───────────────────────────────────────────
Write-Host "`n  Writing $ProfileContent..." -ForegroundColor Cyan

@'
# =============================================================================
# PowerShell Profile — loaded by $PROFILE via dot-source
# Edit this file; changes take effect on next shell open (or `. $PROFILE`).
# =============================================================================

# ── Oh My Posh prompt ────────────────────────────────────────────────────────
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $theme = Join-Path $env:POSH_THEMES_PATH "jandedobbeleer.omp.json"
    if (-not (Test-Path $theme)) { $theme = "" }  # falls back to built-in default
    if ($theme) {
        oh-my-posh init pwsh --config $theme | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}

# ── PSReadLine — better history & completion ─────────────────────────────────
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
}

# ── fzf key bindings (Ctrl+T: file picker, Ctrl+R: history search) ───────────
if ((Get-Command fzf -EA 0) -and (Get-Module -ListAvailable PSFzf)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# ── CLI completions ───────────────────────────────────────────────────────────

# winget
Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $word = $wordToComplete -replace '"', '""'
    $ast  = $commandAst.ToString() -replace '"', '""'
    winget complete --word="$word" --commandline "$ast" --position $cursorPosition |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# kubectl
if (Get-Command kubectl -EA 0) {
    kubectl completion powershell | Out-String | Invoke-Expression
}

# helm
if (Get-Command helm -EA 0) {
    helm completion powershell | Out-String | Invoke-Expression
}

# GitHub CLI
if (Get-Command gh -EA 0) {
    gh completion -s powershell | Out-String | Invoke-Expression
}

# AWS CLI  (requires aws_completer on PATH, installed with AWS CLI)
if (Get-Command aws_completer -EA 0) {
    Register-ArgumentCompleter -Native -CommandName aws -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        $env:COMP_LINE  = $wordToComplete
        $env:COMP_POINT = $cursorPosition
        aws_completer | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        Remove-Item Env:\COMP_LINE, Env:\COMP_POINT -ErrorAction SilentlyContinue
    }
}

# Terraform (writes its own completion block to $PROFILE — only needs to run once)
if ((Get-Command terraform -EA 0) -and -not (Select-String -Path $PROFILE -Pattern "terraform" -Quiet -EA 0)) {
    terraform -install-autocomplete 2>$null
}

# Google Cloud SDK (sources the gcloud completion script if installed)
$gcloudCompletion = "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\completion.ps1"
if (Test-Path $gcloudCompletion) { . $gcloudCompletion }

# ── Aliases ───────────────────────────────────────────────────────────────────
Set-Alias -Name k    -Value kubectl    -ErrorAction SilentlyContinue
Set-Alias -Name tf   -Value terraform  -ErrorAction SilentlyContinue
Set-Alias -Name d    -Value docker     -ErrorAction SilentlyContinue
Set-Alias -Name g    -Value git        -ErrorAction SilentlyContinue
Set-Alias -Name cat  -Value bat        -ErrorAction SilentlyContinue

# ── Useful functions ──────────────────────────────────────────────────────────

# Unix-style `which`
function which  { (Get-Command $args[0] -ErrorAction SilentlyContinue)?.Source }

# Create a file if it doesn't exist, update timestamp if it does
function touch  { $args | ForEach-Object { if (Test-Path $_) { (Get-Item $_).LastWriteTime = Get-Date } else { New-Item -ItemType File -Path $_ -Force | Out-Null } } }

# Shorthand for Get-ChildItem -Force
function ll     { Get-ChildItem -Force @args }

# Print current public IP
function myip   { (Invoke-RestMethod 'https://api.ipify.org?format=json').ip }

# Grep with colour (passes through to ripgrep if available, else Select-String)
function grep {
    if (Get-Command rg -EA 0) { rg @args } else { $input | Select-String @args }
}

# Quick kubectl context switcher using fzf
function kctx {
    if (Get-Command kubectl -EA 0) {
        $ctx = kubectl config get-contexts -o name | fzf --prompt="context> "
        if ($ctx) { kubectl config use-context $ctx }
    }
}

# Tail the winget-update log
function update-log { Get-Content "$env:TEMP\winget-update.log" -Tail 50 -Wait }
'@ | Set-Content -Path $ProfileContent -Encoding UTF8

# ── Wire the content file into $PROFILE ──────────────────────────────────────
$profileDir = Split-Path $PROFILE
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $PROFILE))    { New-Item -ItemType File      -Path $PROFILE    -Force | Out-Null }

$sourceLine = ". `"$ProfileContent`""
$existing   = Get-Content $PROFILE -ErrorAction SilentlyContinue
if ($existing -notcontains $sourceLine) {
    Add-Content -Path $PROFILE -Value "`n$sourceLine"
    Write-Host "  Added dot-source line to $PROFILE" -ForegroundColor Green
} else {
    Write-Host "  $PROFILE already sources the profile content — no change needed." -ForegroundColor DarkGray
}

Write-Host "`n  Profile setup complete." -ForegroundColor Green
Write-Host "  Reload now: . `$PROFILE  — or just open a new terminal." -ForegroundColor DarkGray
Write-Host "  Theme: Task Scheduler > Oh My Posh themes live in `$env:POSH_THEMES_PATH" -ForegroundColor DarkGray
