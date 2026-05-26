#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables startup items that apps implant without asking.
.DESCRIPTION
    Uses the same mechanism as Task Manager's Startup tab — writes to
    StartupApproved registry keys. Entries are disabled, not deleted, so
    you can re-enable them in Task Manager if needed.

    Run standalone or called automatically at the end of laptop-setup.ps1.
    Safe to re-run after installing new apps.

    KEPT (intentionally not touched):
      - SecurityHealth     Windows Security tray icon
      - 1Password          Password manager tray — needs to be running
      - Bitwarden          Password manager tray — needs to be running
      - Tailscale          VPN agent — must start with Windows to work
      - Claude             AI assistant tray (your call — see comment below)
#>

$ErrorActionPreference = "Continue"

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "  Startup Item Cleanup" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Binary value Task Manager writes when disabling a startup item
$disabled = [byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)

$hkcu = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
$hklm = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
$hklm32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"

foreach ($key in @($hkcu, $hklm, $hklm32)) {
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
}

function Disable-Startup {
    param([string]$Name, [string]$Key, [string]$Reason)
    # Check if the source Run entry exists before bothering to disable
    $runKey = $Key -replace "Explorer\\StartupApproved\\", ""
    $exists = Get-ItemProperty -Path $runKey -Name $Name -ErrorAction SilentlyContinue
    if ($exists) {
        Set-ItemProperty -Path $Key -Name $Name -Value $disabled -Type Binary -Force
        Write-Host "  Disabled: $Name  ($Reason)" -ForegroundColor DarkYellow
    }
}

Write-Host "`n-- Gaming & launchers (open when you want to game) --" -ForegroundColor Green
Disable-Startup "Discord"              $hkcu  "opens when you launch it"
Disable-Startup "Steam"                $hkcu  "opens when you want to game"
Disable-Startup "Battle.net"           $hkcu  "opens when you want to game"

Write-Host "`n-- Browser background helpers --" -ForegroundColor Green
Disable-Startup "BraveSoftware Update" $hkcu  "Brave self-updates; background helper not needed"
Disable-Startup "GoogleUpdate"         $hkcu  "Chrome self-updates; background helper not needed"

Write-Host "`n-- ASUS bloatware --" -ForegroundColor Green
Disable-Startup "Virtual Pet"          $hklm  "ASUS Virtual Assistant — not useful"
Disable-Startup "ASUS HM"              $hklm  "ASUS background helper"
Disable-Startup "ASUSUpdate"           $hklm  "use MyASUS manually to check for updates"

Write-Host "`n-- Microsoft noise --" -ForegroundColor Green
Disable-Startup "OneDrive"             $hkcu  "launch manually if you use it"
Disable-Startup "MicrosoftTeams"       $hkcu  "personal Teams; launch when needed"

Write-Host "`n-- Optional: Claude tray --" -ForegroundColor DarkGray
Write-Host "  Claude auto-start is KEPT. To disable: Task Manager > Startup Apps > Claude" -ForegroundColor DarkGray

# ── Scheduled task noise from app installers ──────────────────────────────────
Write-Host "`n-- Scheduled task background updaters --" -ForegroundColor Green

$noisyTasks = @(
    # Brave update tasks
    @{ Path = "\BraveSoftwareUpdateTaskMachineCore";   Reason = "Brave auto-updater" }
    @{ Path = "\BraveSoftwareUpdateTaskMachineUA";     Reason = "Brave auto-updater" }
    # Google update tasks
    @{ Path = "\GoogleUpdateTaskMachineCore";           Reason = "Chrome auto-updater; Chrome updates on launch" }
    @{ Path = "\GoogleUpdateTaskMachineUA";             Reason = "Chrome auto-updater" }
    # Notion
    @{ Path = "\NotionUpdateTask";                     Reason = "Notion background updater" }
)

foreach ($task in $noisyTasks) {
    $t = Get-ScheduledTask -TaskPath "\" -TaskName ($task.Path.TrimStart("\")) -ErrorAction SilentlyContinue
    if ($t) {
        Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  Disabled task: $($task.Path)  ($($task.Reason))" -ForegroundColor DarkYellow
    }
}

# ── Report final startup state ────────────────────────────────────────────────
Write-Host "`n-- Current startup items after cleanup --" -ForegroundColor Green
Get-CimInstance Win32_StartupCommand |
    Select-Object Name, Location |
    Sort-Object Location, Name |
    Format-Table -AutoSize

Write-Host "  To review/toggle: Task Manager (Ctrl+Shift+Esc) > Startup Apps tab" -ForegroundColor DarkGray
Write-Host "`n  Startup cleanup complete." -ForegroundColor Green
