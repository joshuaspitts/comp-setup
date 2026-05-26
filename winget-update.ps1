<#
.SYNOPSIS
    Full package update — winget, npm globals, and pip globals.
.DESCRIPTION
    Run by the WingetWeeklyUpgrade scheduled task (Sundays @ 9 AM).
    Also safe to run manually at any time.
    Logs to %TEMP%\winget-update.log.

    Coverage:
      winget   — all tracked apps
      npm      — @latest for fast-moving AI CLIs; npm update -g for the rest
      pip      — pip itself + all outdated global packages
#>

$log = "$env:TEMP\winget-update.log"

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Msg"
    $line | Add-Content -Path $log
    Write-Host $line -ForegroundColor $Color
}

Write-Log "====== Package update started ======" "Yellow"

# ── winget ───────────────────────────────────────────────────────────────────
Write-Log "-- winget: refreshing sources..." "Cyan"
winget source update --accept-source-agreements 2>&1 | Add-Content $log

Write-Log "-- winget: upgrading all packages..." "Cyan"
winget upgrade --all `
    --accept-source-agreements `
    --accept-package-agreements `
    --silent `
    2>&1 | Tee-Object -FilePath $log -Append

Write-Log "-- winget: done (exit $LASTEXITCODE)" "Green"

# ── npm globals ───────────────────────────────────────────────────────────────
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Log "-- npm: pinning fast-moving AI CLIs to @latest..." "Cyan"

    # These move fast enough that npm update -g misses major bumps — force @latest
    $pinnedLatest = @(
        "@google/gemini-cli"
    )
    foreach ($pkg in $pinnedLatest) {
        Write-Log "   npm install -g $pkg@latest" "DarkGray"
        npm install -g "$pkg@latest" 2>&1 | Add-Content $log
    }

    Write-Log "-- npm: updating all other globals..." "Cyan"
    npm update -g 2>&1 | Tee-Object -FilePath $log -Append
    Write-Log "-- npm: done" "Green"
} else {
    Write-Log "-- npm: not found, skipping." "DarkGray"
}

# ── pip globals ───────────────────────────────────────────────────────────────
if (Get-Command pip -ErrorAction SilentlyContinue) {
    Write-Log "-- pip: upgrading pip itself..." "Cyan"
    pip install --upgrade pip 2>&1 | Add-Content $log

    Write-Log "-- pip: upgrading outdated global packages..." "Cyan"
    $outdated = pip list --outdated --format=json 2>$null | ConvertFrom-Json
    if ($outdated.Count -gt 0) {
        $outdated | ForEach-Object {
            Write-Log "   pip install --upgrade $($_.name)" "DarkGray"
            pip install --upgrade $_.name 2>&1 | Add-Content $log
        }
        Write-Log "-- pip: upgraded $($outdated.Count) package(s)" "Green"
    } else {
        Write-Log "-- pip: all packages current" "Green"
    }
} else {
    Write-Log "-- pip: not found, skipping." "DarkGray"
}

Write-Log "====== Package update complete ======" "Yellow"
Write-Log "Log: $log" "DarkGray"
