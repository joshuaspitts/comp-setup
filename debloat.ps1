#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 debloat — wraps Win11Debloat by Raphire with local privacy tweaks.
.DESCRIPTION
    Calls the Win11Debloat script (https://github.com/Raphire/Win11Debloat) in
    silent/default mode, then applies additional registry-level privacy and UX
    tweaks that aren't covered by it.

    Run standalone or called from laptop-setup.ps1 via -RunDebloat.

    Win11Debloat -RunDefaults removes:
      - Advertising ID, telemetry, diagnostic data uploads
      - Cortana, Bing search in Start, web suggestions in search
      - Microsoft 365 / OneDrive / Teams (personal) upsell nags
      - Bloatware UWP apps: Candy Crush, Solitaire, Disney+, TikTok, etc.
      - Xbox Game Bar (keeps Xbox app for controller support)
      - "Suggested" apps and content in Start
      - Edge desktop shortcut recreation
    It does NOT remove OneDrive itself, the Edge browser, or Windows Security.
#>

$ErrorActionPreference = "Continue"

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "  Debloat: Win11Debloat (Raphire)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Source: https://github.com/Raphire/Win11Debloat" -ForegroundColor DarkGray
Write-Host "  Mode:   -RunDefaults -Silent" -ForegroundColor DarkGray

try {
    & ([scriptblock]::Create((irm "https://win11debloat.raphi.re/"))) -RunDefaults -Silent
} catch {
    Write-Warning "Win11Debloat failed: $_"
    Write-Warning "Run manually: irm https://win11debloat.raphi.re/ | iex"
}

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "  Additional Privacy & UX Tweaks" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Disable Copilot button on taskbar
Write-Host "  Disabling Copilot taskbar button..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "ShowCopilotButton" -Value 0 -Type DWord -Force

# Disable Task View button on taskbar
Write-Host "  Disabling Task View taskbar button..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force

# Disable widgets (news/weather panel)
Write-Host "  Disabling Widgets panel..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "TaskbarDa" -Value 0 -Type DWord -Force

# Disable Chat (Teams personal) taskbar button
Write-Host "  Disabling Chat taskbar button..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "TaskbarMn" -Value 0 -Type DWord -Force

# Disable Search highlights (animated logo in search bar)
Write-Host "  Disabling Search highlights..." -ForegroundColor Cyan
$searchPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings"
if (-not (Test-Path $searchPath)) { New-Item -Path $searchPath -Force | Out-Null }
Set-ItemProperty -Path $searchPath -Name "IsDynamicSearchBoxEnabled" -Value 0 -Type DWord -Force

# Show file extensions in Explorer
Write-Host "  Showing file extensions in Explorer..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "HideFileExt" -Value 0 -Type DWord -Force

# Show hidden files in Explorer
Write-Host "  Showing hidden files in Explorer..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Hidden" -Value 1 -Type DWord -Force

# Disable sticky keys prompt (annoying during gaming/fast typing)
Write-Host "  Disabling Sticky Keys prompt..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" `
    -Name "Flags" -Value "506" -Type String -Force

# Disable tips and suggestions notifications
Write-Host "  Disabling Windows tips/suggestions..." -ForegroundColor Cyan
$contentPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-ItemProperty -Path $contentPath -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $contentPath -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $contentPath -Name "SystemPaneSuggestionsEnabled"    -Value 0 -Type DWord -Force

# Disable "Get the most out of Windows" welcome page
Write-Host "  Disabling Windows welcome/upsell page..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" `
    -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Set Explorer to open "This PC" instead of Quick Access
Write-Host "  Setting Explorer default to This PC..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "LaunchTo" -Value 1 -Type DWord -Force

Write-Host "`n  Debloat complete. Some changes take effect after signing out/reboot." -ForegroundColor Green
