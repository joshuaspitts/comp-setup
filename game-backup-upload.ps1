<#
.SYNOPSIS
    Upload a game install folder to a NAS share with live overall progress.

.DESCRIPTION
    Robocopy wrapper that:
      - sizes the source up front
      - runs robocopy in a background job (silent per-file output)
      - shows a single PowerShell progress bar updating every N seconds
      - prints the final robocopy summary

    Defaults to backing up Diablo IV to \\192.168.7.9\migration\d4.

.PARAMETER Source
    Game install folder. Default: C:\Program Files (x86)\Diablo IV

.PARAMETER NasShare
    UNC root of the NAS share. Default: \\192.168.7.9\migration

.PARAMETER Name
    Subfolder name on the share (also used in progress label). Default: d4

.PARAMETER PollSeconds
    How often to refresh the progress bar. Default: 10

.EXAMPLE
    .\game-backup-upload.ps1
    # Backs up Diablo IV with defaults

.EXAMPLE
    .\game-backup-upload.ps1 -Source 'C:\Program Files (x86)\Overwatch' -Name 'overwatch'

.NOTES
    If the NAS share requires credentials, authenticate first in this same shell:
        net use \\192.168.7.9\migration /user:NAS_USER * /persistent:yes
    Background jobs do NOT inherit mapped drive letters, so this script uses
    UNC paths directly (no Z:\ etc.).
#>
param(
    [string]$Source      = 'C:\Program Files (x86)\Diablo IV',
    [string]$NasShare    = '\\192.168.7.9\migration',
    [string]$Name        = 'd4',
    [int]   $PollSeconds = 10
)

$ErrorActionPreference = 'Stop'
$dst = Join-Path $NasShare $Name

# ── Pre-flight ──────────────────────────────────────────────────────────────
if (-not (Test-Path $Source)) {
    Write-Error "Source not found: $Source"
    exit 1
}
if (-not (Test-Path $NasShare)) {
    Write-Host "`nCannot reach NAS share: $NasShare" -ForegroundColor Red
    Write-Host "Authenticate first:" -ForegroundColor Yellow
    Write-Host "    net use $NasShare /user:NAS_USER * /persistent:yes" -ForegroundColor DarkGray
    exit 1
}

New-Item -ItemType Directory -Force -Path $dst | Out-Null

# ── Size source ─────────────────────────────────────────────────────────────
Write-Host "`nSizing source: $Source ..." -ForegroundColor Cyan
$totalBytes = (Get-ChildItem $Source -Recurse -ErrorAction SilentlyContinue |
               Where-Object { -not $_.PSIsContainer } |
               Measure-Object Length -Sum).Sum
if (-not $totalBytes) {
    Write-Error "Source is empty or unreadable: $Source"
    exit 1
}
$totalGB = [math]::Round($totalBytes / 1GB, 2)
Write-Host "Total: $totalGB GB" -ForegroundColor Cyan
Write-Host "Destination: $dst`n" -ForegroundColor Cyan

# ── Background robocopy with progress polling ───────────────────────────────
$jobName = "backup-$Name-$(Get-Random -Maximum 9999)"
$started = Get-Date

$job = Start-Job -Name $jobName -ScriptBlock {
    robocopy $using:Source $using:dst /E /MT:16 /R:1 /W:1 /NFL /NDL /NP /NJH /NJS
    $LASTEXITCODE
}

$activity = "Backing up '$Name' -> $dst"
while ((Get-Job $jobName).State -eq 'Running') {
    Start-Sleep -Seconds $PollSeconds
    $doneBytes = (Get-ChildItem $dst -Recurse -ErrorAction SilentlyContinue |
                  Where-Object { -not $_.PSIsContainer } |
                  Measure-Object Length -Sum).Sum
    if ($doneBytes) {
        $doneGB  = [math]::Round($doneBytes / 1GB, 2)
        $pct     = [math]::Round($doneBytes / $totalBytes * 100, 1)
        $elapsed = (Get-Date) - $started
        $rate    = if ($elapsed.TotalSeconds -gt 0) {
                       [math]::Round(($doneBytes/1MB)/$elapsed.TotalSeconds, 1)
                   } else { 0 }
        Write-Progress -Activity $activity `
                       -Status   "$doneGB GB / $totalGB GB  ($pct%)  @ $rate MB/s  elapsed $($elapsed.ToString('hh\:mm\:ss'))" `
                       -PercentComplete ([math]::Min($pct, 100))
    }
}

Write-Progress -Activity $activity -Completed
$jobOutput = Receive-Job $jobName
Remove-Job  $jobName

# Last line of job output is $LASTEXITCODE from inside the job
$rcExit = $jobOutput | Select-Object -Last 1
$summary = $jobOutput | Select-Object -First (($jobOutput.Count) - 1)

Write-Host "`n──── robocopy summary ─────────────────────────────────────────" -ForegroundColor Yellow
$summary | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }

# Robocopy exit codes: 0-7 = OK (with various flavours), 8+ = errors
if ($rcExit -ge 8) {
    Write-Warning "`nRobocopy exit code $rcExit indicates errors. Review the summary above."
} else {
    $totalElapsed = (Get-Date) - $started
    Write-Host "`nBackup complete (exit $rcExit) in $($totalElapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Green
    Write-Host "  $Source" -ForegroundColor DarkGray
    Write-Host "  -> $dst" -ForegroundColor DarkGray
}
