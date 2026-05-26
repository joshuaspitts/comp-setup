<#
.SYNOPSIS
    Restore a game install folder from a NAS share with live overall progress.

.DESCRIPTION
    Robocopy wrapper that:
      - sizes the NAS source up front
      - runs robocopy in a background job (silent per-file output)
      - shows a single PowerShell progress bar updating every N seconds
      - prints the final robocopy summary
      - reminds you to use Battle.net's "Locate this game" feature afterward

    Defaults to restoring Diablo IV from \\192.168.7.9\migration\d4 to
    D:\Games\Diablo IV. Change -Destination if your install drive is different.

.PARAMETER Destination
    Where to put the restored game folder. Default: D:\Games\Diablo IV
    (Falls back to C:\Games\Diablo IV if D:\ doesn't exist.)

.PARAMETER NasShare
    UNC root of the NAS share. Default: \\192.168.7.9\migration

.PARAMETER Name
    Subfolder name on the share. Default: d4

.PARAMETER PollSeconds
    How often to refresh the progress bar. Default: 10

.EXAMPLE
    .\game-backup-download.ps1
    # Restores Diablo IV with defaults

.EXAMPLE
    .\game-backup-download.ps1 -Destination 'E:\Games\Overwatch' -Name 'overwatch'

.NOTES
    Battle.net does not auto-detect copied folders. After this script finishes:
      1. Launch Battle.net and sign in
      2. Click Diablo IV (or your game) -> Install
      3. Click the small "Locate this game" link near the install path
      4. Point it at the destination this script just wrote to
      5. Battle.net will hash-scan and download only the patch delta

    If the share requires credentials, authenticate first in this same shell:
        net use \\192.168.7.9\migration /user:NAS_USER * /persistent:yes
#>
param(
    [string]$Destination = $null,
    [string]$NasShare    = '\\192.168.7.9\migration',
    [string]$Name        = 'd4',
    [int]   $PollSeconds = 10
)

$ErrorActionPreference = 'Stop'

# ── Default destination logic: prefer D:\ if it exists, else C:\ ────────────
if (-not $Destination) {
    if (Test-Path 'D:\') {
        $Destination = 'D:\Games\Diablo IV'
    } else {
        $Destination = 'C:\Games\Diablo IV'
    }
}

$src = Join-Path $NasShare $Name

# ── Pre-flight ──────────────────────────────────────────────────────────────
if (-not (Test-Path $NasShare)) {
    Write-Host "`nCannot reach NAS share: $NasShare" -ForegroundColor Red
    Write-Host "Authenticate first:" -ForegroundColor Yellow
    Write-Host "    net use $NasShare /user:NAS_USER * /persistent:yes" -ForegroundColor DarkGray
    exit 1
}
if (-not (Test-Path $src)) {
    Write-Error "Source not found on NAS: $src"
    exit 1
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

# ── Size source ─────────────────────────────────────────────────────────────
Write-Host "`nSizing source: $src ..." -ForegroundColor Cyan
$totalBytes = (Get-ChildItem $src -Recurse -ErrorAction SilentlyContinue |
               Where-Object { -not $_.PSIsContainer } |
               Measure-Object Length -Sum).Sum
if (-not $totalBytes) {
    Write-Error "Source is empty or unreadable: $src"
    exit 1
}
$totalGB = [math]::Round($totalBytes / 1GB, 2)
Write-Host "Total: $totalGB GB" -ForegroundColor Cyan
Write-Host "Destination: $Destination`n" -ForegroundColor Cyan

# ── Background robocopy with progress polling ───────────────────────────────
$jobName = "restore-$Name-$(Get-Random -Maximum 9999)"
$started = Get-Date

$job = Start-Job -Name $jobName -ScriptBlock {
    robocopy $using:src $using:Destination /E /MT:16 /R:1 /W:1 /NFL /NDL /NP /NJH /NJS
    $LASTEXITCODE
}

$activity = "Restoring '$Name' -> $Destination"
while ((Get-Job $jobName).State -eq 'Running') {
    Start-Sleep -Seconds $PollSeconds
    $doneBytes = (Get-ChildItem $Destination -Recurse -ErrorAction SilentlyContinue |
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

$rcExit  = $jobOutput | Select-Object -Last 1
$summary = $jobOutput | Select-Object -First (($jobOutput.Count) - 1)

Write-Host "`n──── robocopy summary ─────────────────────────────────────────" -ForegroundColor Yellow
$summary | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }

if ($rcExit -ge 8) {
    Write-Warning "`nRobocopy exit code $rcExit indicates errors. Review the summary above."
    exit $rcExit
}

$totalElapsed = (Get-Date) - $started
Write-Host "`nRestore complete (exit $rcExit) in $($totalElapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Green
Write-Host "  $src" -ForegroundColor DarkGray
Write-Host "  -> $Destination" -ForegroundColor DarkGray

# ── Next-steps reminder ─────────────────────────────────────────────────────
Write-Host "`n──── NEXT STEPS — Battle.net 'Locate this game' ─────────────" -ForegroundColor Yellow
Write-Host "  1. Open Battle.net and sign in"                       -ForegroundColor DarkGray
Write-Host "  2. Click the game in your library -> Install"         -ForegroundColor DarkGray
Write-Host "  3. On the install dialog, click 'Locate this game'"   -ForegroundColor DarkGray
Write-Host "  4. Point it at:" -ForegroundColor DarkGray
Write-Host "       $Destination" -ForegroundColor Cyan
Write-Host "  5. Battle.net will hash-scan and download patch deltas only.`n" -ForegroundColor DarkGray
