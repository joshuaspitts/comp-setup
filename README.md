# laptop-setup

One-command Windows laptop provisioning. Downloads all scripts from GitHub and
runs a full install — apps, dev tools, cloud CLIs, shell config, debloat, and
scheduled maintenance tasks.

---

## Quick start (new machine)

**CMD (run as Administrator, or the script will self-elevate):**
```cmd
curl -fsSL https://raw.githubusercontent.com/GITHUB_USER/laptop-setup/main/bootstrap.ps1 -o %TEMP%\bootstrap.ps1 && pwsh -ExecutionPolicy Bypass -File %TEMP%\bootstrap.ps1
```

**PowerShell:**
```powershell
iwr https://raw.githubusercontent.com/GITHUB_USER/laptop-setup/main/bootstrap.ps1 -OutFile "$env:TEMP\bootstrap.ps1"; pwsh -ExecutionPolicy Bypass -File "$env:TEMP\bootstrap.ps1"
```

Replace `GITHUB_USER` with your GitHub username, or update `$GithubUser` in
`bootstrap.ps1` before pushing.

> `curl.exe` ships with Windows 10/11 (v1803+) — no prerequisites needed.

---

## Optional flags

| Flag | Effect |
|------|--------|
| `-RunDebloat` | Also run `debloat.ps1` (Win11Debloat + registry tweaks) — recommended on a fresh OS |
| `-SkipProfileSetup` | Skip Oh My Posh / PowerShell completions setup |
| `-SkipStartupClean` | Skip startup item cleanup |
| `-SkipScheduledTask` | Skip registering the weekly winget-update scheduled task |

```cmd
pwsh -ExecutionPolicy Bypass -File %TEMP%\bootstrap.ps1 -RunDebloat
```

---

## What gets installed

`laptop-setup.ps1` runs 13 sections via `winget`:

| # | Section | Notable packages |
|---|---------|-----------------|
| 1 | System tweaks | Long path support, Developer Mode, High Performance power plan |
| 2 | WSL2 | `wsl --install`, `.wslconfig` (8 GB / 4 CPUs / 2 GB swap) |
| 3 | Shell & dev foundations | Git, Node.js, Python, Oh My Posh, Windows Terminal |
| 4 | Package management | delta, chezmoi, pipx, pyenv-win |
| 5 | CLI utilities | bat, fd, fzf, ripgrep, jq, yq, wget, zoxide, eza |
| 6 | Cloud CLIs | AWS CLI, Azure CLI, Google Cloud SDK |
| 7 | Containers & k8s | Docker Desktop, kubectl, Helm, k9s, Lens |
| 8 | IaC | Terraform, GitHub CLI |
| 9 | Remote & networking | PuTTY, WinSCP, Tailscale |
| 10 | Browsers | Brave, Chrome |
| 11 | Productivity | VS Code, Sublime Text, Notepad++, Notepads, DBeaver |
| 12 | Password managers | 1Password, 1Password CLI, Bitwarden |
| 13 | Communication / AI | Discord, Claude Code CLI, Gemini CLI (via npm) |

---

## Repository structure

```
bootstrap.ps1          Entry point — downloads all scripts, then runs laptop-setup.ps1
laptop-setup.ps1       Main provisioning script (13 sections)
debloat.ps1            Win11Debloat + registry tweaks (taskbar, privacy, Explorer)
startup-cleanup.ps1    Disables startup items that reinstall themselves
winget-update.ps1      Weekly updater: winget + npm globals + pip packages
profile-setup.ps1      Oh My Posh, JetBrainsMono Nerd Font, PSFzf, completions
wsl-bootstrap.sh       WSL Ubuntu: zsh, nvm, cloud CLIs, kubectl, Helm, Terraform
serve-preview.ps1      Local HTTP server for todo.html preview (port 3400)
todo.md                Remaining manual setup steps (Markdown)
todo.html              Same content as dark-mode interactive checklist
```

---

## Post-install steps

After `laptop-setup.ps1` finishes and you reboot:

1. **WSL Ubuntu** — install and bootstrap:
   ```powershell
   wsl --install -d Ubuntu
   # after Ubuntu first-run completes:
   wsl -d Ubuntu -- bash "$env:USERPROFILE/Scripts/wsl-bootstrap.sh"
   ```

2. **Git config** — set your name, email, and preferred pager:
   ```powershell
   git config --global user.name  "Your Name"
   git config --global user.email "you@example.com"
   ```

3. **Cloud CLI auth** — each needs a one-time login:
   ```powershell
   aws configure        # access key + region
   az login             # browser OAuth
   gcloud init          # browser OAuth + project
   gh auth login        # GitHub SSH or token
   ```

4. **SSH key** — generate and add to GitHub:
   ```powershell
   ssh-keygen -t ed25519 -C "you@example.com"
   cat ~/.ssh/id_ed25519.pub | clip
   Start-Process "https://github.com/settings/keys"
   ```

5. **Windows Terminal** — set font: Settings → Defaults → Appearance →
   Font face → `JetBrainsMono Nerd Font`

See `todo.md` (or open `todo.html` in a browser) for the full remaining checklist.

---

## Maintenance

A scheduled task (`\$USERNAME\WingetWeeklyUpdate`) runs every Sunday at 9:30 AM
and calls `winget-update.ps1`, which upgrades winget packages, npm globals, and
outdated pip packages. Logs go to `%TEMP%\winget-update.log`.

A second task (`\$USERNAME\WSLWeeklyAptUpgrade`) runs `sudo apt upgrade` inside
WSL Ubuntu on the same schedule.

To run updates manually:
```powershell
& "$env:USERPROFILE\Scripts\winget-update.ps1"
```

---

## Before pushing

Update the `$GithubUser` placeholder in `bootstrap.ps1`:
```powershell
$GithubUser = "your-actual-username"
```

Then push to a **private** repo (the scripts contain no secrets, but your
config choices are personal).
