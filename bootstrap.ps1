<#
.SYNOPSIS
    One-shot bootstrap for a new Windows machine — downloads all setup scripts
    from GitHub and kicks off the install.
.DESCRIPTION
    Run this on a brand-new machine with a single curl command (curl.exe is
    built into Windows 10/11 — no installs required before this):

    CMD (run as admin, or bootstrap will self-elevate):
        curl -fsSL https://raw.githubusercontent.com/GITHUB_USER/laptop-setup/main/bootstrap.ps1 -o %TEMP%\bootstrap.ps1 && pwsh -ExecutionPolicy Bypass -File %TEMP%\bootstrap.ps1

    PowerShell:
        iwr https://raw.githubusercontent.com/GITHUB_USER/laptop-setup/main/bootstrap.ps1 -OutFile "$env:TEMP\bootstrap.ps1"; pwsh -ExecutionPolicy Bypass -File "$env:TEMP\bootstrap.ps1"

    Flags passed through to laptop-setup.ps1:
        -RunDebloat        Also run debloat.ps1 (recommended on a fresh OS)
        -SkipProfileSetup  Skip Oh My Posh / completions setup
        -SkipStartupClean  Skip startup item cleanup
        -SkipScheduledTask Skip scheduled task registration
#>
param(
    [switch]$RunDebloat,
    [switch]$SkipProfileSetup,
    [switch]$SkipStartupClean,
    [switch]$SkipScheduledTask
)

# ── Self-elevate if not already admin ────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal]
          [Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argList = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($RunDebloat)        { $argList += " -RunDebloat" }
    if ($SkipProfileSetup)  { $argList += " -SkipProfileSetup" }
    if ($SkipStartupClean)  { $argList += " -SkipStartupClean" }
    if ($SkipScheduledTask) { $argList += " -SkipScheduledTask" }
    Start-Process pwsh -Verb RunAs -ArgumentList $argList
    exit
}

# ── Configuration — update GITHUB_USER before pushing your repo ──────────────
$GithubUser   = "GITHUB_USER"      # <-- replace with your GitHub username
$GithubRepo   = "laptop-setup"
$GithubBranch = "main"
$RawBase      = "https://raw.githubusercontent.com/$GithubUser/$GithubRepo/$GithubBranch"

$DestDir = Join-Path $env:USERPROFILE "Scripts"

$Scripts = @(
    "laptop-setup.ps1",
    "debloat.ps1",
    "startup-cleanup.ps1",
    "winget-update.ps1",
    "profile-setup.ps1",
    "wsl-bootstrap.sh",
    "todo.md",
    "todo.html"
)

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "  Laptop Setup Bootstrap" -ForegroundColor Yellow
Write-Host "  Repo: github.com/$GithubUser/$GithubRepo" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Yellow

# ── Download all scripts to permanent location ────────────────────────────────
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
Write-Host "  Downloading scripts to $DestDir..." -ForegroundColor Cyan

foreach ($file in $Scripts) {
    $url  = "$RawBase/$file"
    $dest = Join-Path $DestDir $file
    Write-Host "  + $file" -ForegroundColor DarkGray
    curl.exe -fsSL $url -o $dest
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to download $file from $url"
    }
}

Write-Host "`n  All scripts downloaded to $DestDir" -ForegroundColor Green

# ── Run the main setup script ─────────────────────────────────────────────────
$setup = Join-Path $DestDir "laptop-setup.ps1"
if (-not (Test-Path $setup)) {
    Write-Error "laptop-setup.ps1 not found at $setup — aborting."
    exit 1
}

Set-ExecutionPolicy -Scope Process Bypass -Force

$setupArgs = @()
if ($RunDebloat)        { $setupArgs += "-RunDebloat" }
if ($SkipProfileSetup)  { $setupArgs += "-SkipProfileSetup" }
if ($SkipStartupClean)  { $setupArgs += "-SkipStartupClean" }
if ($SkipScheduledTask) { $setupArgs += "-SkipScheduledTask" }

& $setup @setupArgs
