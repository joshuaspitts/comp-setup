# Setup Commands — quick reference

> All commands target the repo at `https://github.com/joshuaspitts/comp-setup`
> (the `$RawBase` URL is `https://raw.githubusercontent.com/joshuaspitts/comp-setup/main`)

---

## TL;DR — Fresh Windows install

Run **one** of these from an Administrator shell (or let the script self-elevate).

### CMD (works on stock Windows 10/11 — no prereqs)
```cmd
curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/bootstrap.ps1 -o %TEMP%\bootstrap.ps1 && pwsh -ExecutionPolicy Bypass -File %TEMP%\bootstrap.ps1
```

### PowerShell 7+ (pwsh)
```powershell
iwr https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/bootstrap.ps1 -OutFile "$env:TEMP\bootstrap.ps1"; pwsh -ExecutionPolicy Bypass -File "$env:TEMP\bootstrap.ps1"
```

### Windows PowerShell 5.1 (when `pwsh` isn't installed yet)
A truly fresh Windows install only has `powershell.exe` (5.1). Swap `pwsh` for `powershell`:
```cmd
curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/bootstrap.ps1 -o %TEMP%\bootstrap.ps1 && powershell -ExecutionPolicy Bypass -File %TEMP%\bootstrap.ps1
```
**Why:** `laptop-setup.ps1` installs `pwsh` early in section [3/13]. After the first run + reboot, future runs can use `pwsh`.

---

## Common flag variations

`bootstrap.ps1` passes any flags straight through to `laptop-setup.ps1`.

| Flag | Why |
|------|-----|
| `-RunDebloat` | Also run `debloat.ps1` first (Win11Debloat + registry tweaks). **Recommended on a brand-new OS.** |
| `-SkipProfileSetup` | Don't install Oh My Posh / Nerd Font / PSFzf. Use if you already have a tuned `$PROFILE`. |
| `-SkipStartupClean` | Don't disable Discord/Steam/Brave/etc. auto-start. Use if you actually want them at boot. |
| `-SkipScheduledTask` | Don't register the weekly winget-update or WSL apt-upgrade tasks. |

### Examples
```cmd
:: First time on a fresh OS — debloat + everything else
curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/bootstrap.ps1 -o %TEMP%\bootstrap.ps1 && pwsh -ExecutionPolicy Bypass -File %TEMP%\bootstrap.ps1 -RunDebloat

:: Already-customized box — skip profile + startup cleanup
curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/bootstrap.ps1 -o %TEMP%\bootstrap.ps1 && pwsh -ExecutionPolicy Bypass -File %TEMP%\bootstrap.ps1 -SkipProfileSetup -SkipStartupClean
```

---

## Individual scripts (skip the full bootstrap)

Use these when you want to re-run a single piece of the setup, or pull one script onto a machine that's already provisioned.

| Script | Purpose | One-liner |
|--------|---------|-----------|
| `laptop-setup.ps1` | Main provisioning (13 sections of winget) | `curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/laptop-setup.ps1 -o "%USERPROFILE%\Scripts\laptop-setup.ps1"` |
| `debloat.ps1` | Win11Debloat + 10 registry tweaks (Explorer, privacy, taskbar) | `curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/debloat.ps1 -o "%USERPROFILE%\Scripts\debloat.ps1"` |
| `startup-cleanup.ps1` | Disable Discord/Steam/Brave auto-start | `curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/startup-cleanup.ps1 -o "%USERPROFILE%\Scripts\startup-cleanup.ps1"` |
| `winget-update.ps1` | Manual run of the weekly updater (winget + npm + pip) | `curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/winget-update.ps1 -o "%USERPROFILE%\Scripts\winget-update.ps1"` |
| `profile-setup.ps1` | Oh My Posh + JetBrainsMono Nerd Font + PSFzf + completions | `curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/profile-setup.ps1 -o "%USERPROFILE%\Scripts\profile-setup.ps1"` |
| `wsl-bootstrap.sh` | Inside WSL Ubuntu: zsh, nvm, cloud CLIs, kubectl, Helm, Terraform, k9s | `curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/wsl-bootstrap.sh -o "%USERPROFILE%\Scripts\wsl-bootstrap.sh"` |
| `todo.md` | Manual post-install checklist (Markdown) | `curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/todo.md -o "%USERPROFILE%\Scripts\todo.md"` |
| `todo.html` | Same checklist, dark-mode interactive | `curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/todo.html -o "%USERPROFILE%\Scripts\todo.html"` |

PowerShell equivalent of any of the above — swap `curl -fsSL` for `iwr`:
```powershell
iwr https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/winget-update.ps1 -OutFile "$env:USERPROFILE\Scripts\winget-update.ps1"
```

---

## Optional add-ons (gaming rigs only)

Not part of `bootstrap.ps1` — deliberately, so non-gaming installs stay lean.

| Script | Purpose | One-liner |
|--------|---------|-----------|
| `game-backup-upload.ps1` | Robocopy a game install to NAS with overall progress | `curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/game-backup-upload.ps1 -o "%USERPROFILE%\Scripts\game-backup-upload.ps1"` |
| `game-backup-download.ps1` | Restore from NAS + "Locate this game" reminder | `curl -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/game-backup-download.ps1 -o "%USERPROFILE%\Scripts\game-backup-download.ps1"` |

Grab both at once:
```powershell
@('game-backup-upload.ps1','game-backup-download.ps1') | ForEach-Object {
    iwr "https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/$_" -OutFile "$env:USERPROFILE\Scripts\$_"
}
```

Usage:
```powershell
# Before flatten (current machine):
.\game-backup-upload.ps1                                          # D4 default
.\game-backup-upload.ps1 -Source 'C:\Program Files (x86)\Overwatch' -Name 'overwatch'

# After flatten + Battle.net install (new machine):
.\game-backup-download.ps1                                        # D4 -> D:\Games\Diablo IV
.\game-backup-download.ps1 -Destination 'D:\Games\Overwatch' -Name 'overwatch'
```

---

## Inspect before executing (paranoid mode)

When you want to read a script before it runs — especially for a remote source.

```powershell
# Download to TEMP without executing
iwr https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/bootstrap.ps1 -OutFile "$env:TEMP\inspect-bootstrap.ps1"

# Open in Notepad (or VS Code)
notepad "$env:TEMP\inspect-bootstrap.ps1"
# code "$env:TEMP\inspect-bootstrap.ps1"

# Then execute when satisfied
pwsh -ExecutionPolicy Bypass -File "$env:TEMP\inspect-bootstrap.ps1"
```

Or stream-read the first chunk inline:
```powershell
iwr https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/bootstrap.ps1 |
    Select-Object -ExpandProperty Content | Out-String | Select-String -Pattern '.' | Select-Object -First 50
```

---

## Verification commands

### Is the repo serving the latest version?
```powershell
curl.exe -fsSL https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/bootstrap.ps1 | Select-String "GithubUser"
```
Should show: `$GithubUser   = "joshuaspitts"` — if it shows `"GITHUB_USER"`, the `raw.githubusercontent.com` CDN hasn't caught up yet (typically 5 min after a push).

### Bypass the CDN to confirm the repo itself is current
```powershell
curl.exe -fsSL -H "Accept: application/vnd.github.raw" https://api.github.com/repos/joshuaspitts/comp-setup/contents/bootstrap.ps1 | Select-String "GithubUser"
```
The GitHub API serves directly from git (no CDN). If this is correct but raw is stale, just wait 5 min.

### Check the last commit on origin/main
```powershell
curl.exe -fsSL https://api.github.com/repos/joshuaspitts/comp-setup/commits/main | Select-String -Pattern '"message"|"date"' | Select-Object -First 4
```

### Test the bootstrap URL responds (no download)
```powershell
curl.exe -fsSL -o $null -w "HTTP %{http_code}`n" https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/bootstrap.ps1
```
`HTTP 200` = good. `HTTP 404` = repo private, wrong branch, or wrong path.

---

## wget alternatives (mostly for WSL / Linux contexts)

Windows **does not** ship `wget` natively (only `curl.exe`). It's added by `laptop-setup.ps1` via `winget install GNU.Wget2`, but until that runs, stick to `curl`.

Inside WSL Ubuntu (after running `wsl-bootstrap.sh`) `wget` works natively:
```bash
# Pull the WSL bootstrap from inside WSL if you ever need to re-run it manually
wget -O ~/wsl-bootstrap.sh https://raw.githubusercontent.com/joshuaspitts/comp-setup/main/wsl-bootstrap.sh
bash ~/wsl-bootstrap.sh
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `curl: (22) ... 404` | Repo is private OR wrong branch OR file not yet pushed | Browser-check `https://github.com/joshuaspitts/comp-setup` — make public, or verify branch is `main`, or `git push` |
| `curl: (6) Could not resolve host` | No internet, DNS issue, or VPN intercepting | `ping raw.githubusercontent.com` |
| Bootstrap downloads OK but `pwsh` not found | Stock Windows — no PowerShell 7 yet | Use `powershell` instead of `pwsh` in the one-liner (see [PS 5.1 variant](#windows-powershell-51-when-pwsh-isnt-installed-yet)) |
| Raw URL shows old content right after push | `raw.githubusercontent.com` CDN cache (~5 min TTL) | Wait 5 min, or use the GitHub API verification command above |
| Script runs but fails on first winget command | Not running as admin | Re-run from elevated terminal, or let `bootstrap.ps1` self-elevate (it should prompt UAC) |
| WSL bootstrap script fails with `sudo: a password is required` | First run before passwordless sudo is configured | Normal — type your Ubuntu password once, the script configures `NOPASSWD` for future runs |

---

## Why curl over wget on Windows

- **`curl.exe` ships with Windows 10/11** since v1803 (May 2018). Located at `C:\Windows\System32\curl.exe`. Zero prereqs.
- **`wget` does NOT ship with Windows.** Has to be installed (winget: `GNU.Wget2`) before it's usable.
- For bootstrap, you need a tool that exists *before* any installs run — that's curl.
- Both work the same once you're past the bootstrap.

---

## Why `pwsh` over `powershell` (once both exist)

- **PowerShell 5.1** (`powershell.exe`) ships with Windows. Stuck on .NET Framework 4.x, no new features since 2016.
- **PowerShell 7+** (`pwsh.exe`) is cross-platform, faster, has `-File`/`-Recurse`/`-Filter` parameter improvements, native `??` and `?.` operators, parallel `ForEach-Object -Parallel`, etc.
- All the scripts in this repo are written to work in **both**, but `pwsh` is preferred once installed.
