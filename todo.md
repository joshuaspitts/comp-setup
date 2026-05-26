# Laptop Setup — Remaining Optimizations

> Scripts live in `$env:USERPROFILE\Scripts\`  
> Last updated: 2026-05-26

---

## Shell & Terminal

### [ ] Oh My Posh — pick a theme
`profile-setup.ps1` installs Oh My Posh and defaults to `jandedobbeleer.omp.json`.  
Browse all built-in themes, then update `powershell-profile.ps1`:
```powershell
Get-ChildItem $env:POSH_THEMES_PATH | Select-Object Name
# Edit powershell-profile.ps1: change theme path, then: . $PROFILE
```
**Recommended starting points:** `pure`, `atomic`, `jandedobbeleer`, `cloud-native-azure`

### [ ] Windows Terminal — font & profile customization
After `profile-setup.ps1` installs JetBrainsMono Nerd Font, set it in Windows Terminal:  
Settings → Defaults → Appearance → Font face → `JetBrainsMono Nerd Font`

Consider adding custom profiles for:
- WSL / Ubuntu (auto-created after WSL install)
- Azure Cloud Shell (`az shell` integration)
- SSH sessions to common hosts

### [ ] WSL Ubuntu — install and bootstrap
```powershell
wsl --install -d Ubuntu
# After Ubuntu first-run setup:
wsl -d Ubuntu -- bash $WslScriptsPath/wsl-bootstrap.sh
```

---

## Developer Config

### [ ] Git global config
`git` is installed but unconfigured. Create `git-config.ps1`:
```powershell
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.pager "delta"          # requires: winget install dandavison.delta
git config --global delta.navigate true
git config --global delta.side-by-side true
git config --global core.autocrlf input
git config --global credential.helper manager   # Git Credential Manager (ships with Git)
```

### [ ] SSH key generation
```powershell
ssh-keygen -t ed25519 -C "you@example.com"
cat ~/.ssh/id_ed25519.pub | clip                # copies to clipboard
Start-Process "https://github.com/settings/keys"
```

### [ ] VS Code extensions
`code --install-extension <id>` is fully scriptable. Suggested set:
```
hashicorp.terraform
ms-azuretools.vscode-docker
ms-kubernetes-tools.vscode-kubernetes-tools
ms-python.python
ms-vscode-remote.remote-wsl
ms-vscode-remote.remote-ssh
github.copilot
github.vscode-pull-request-github
eamodio.gitlens
redhat.vscode-yaml
tamasfe.even-better-toml
esbenp.prettier-vscode
dbaeumer.vscode-eslint
```
Create `vscode-extensions.ps1` with the full list.

---

## Package Management

### [x] delta — better git diffs
Added to `laptop-setup.ps1` section [4/13] via `dandavison.delta`.

### [x] chezmoi — dotfiles management
Installed via `laptop-setup.ps1` section [4/13]. Still needs initial config:
```powershell
chezmoi init --apply https://github.com/<you>/dotfiles
```

### [ ] Scoop — complement for PATH-friendly CLI tools
Some tools (especially dev utilities) install cleaner via Scoop — no admin required, immediate PATH availability, no installer popup.  
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
scoop install delta eza zoxide
```
**When to prefer Scoop over winget:** tools that need to be on PATH immediately without a reboot, or tools winget installs in awkward locations.

### [x] pipx — isolated Python tools
Prevents pip global installs from conflicting. Install and migrate:
```powershell
pip install pipx
pipx ensurepath
pipx install ansible          # example: run Ansible on Windows via WSL or pipx
pipx install pre-commit
pipx install black
```

### [x] pyenv-win — multiple Python versions
Useful if you switch between Python versions across projects:
```powershell
winget install pyenv-win.pyenv-win
pyenv install 3.12.0
pyenv global 3.12.0
```

---

## System Tuning

### [ ] Power plan — verify High Performance is active
`laptop-setup.ps1` runs `powercfg /setactive SCHEME_MIN`.  
Verify after reboot:
```powershell
powercfg /getactivescheme
```
On ASUS ROG hardware, also check Armoury Crate for its own performance mode (Manual / Turbo).

### [ ] Taskbar cleanup
Remove pinned apps you don't use. No reliable script exists — Windows 11 taskbar pinning is per-user JSON stored in:  
`%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar`  
Manual cleanup via right-click > Unpin is fastest.

### [ ] Default browser & file associations
Windows 11 requires per-extension changes — there's no `Set-DefaultBrowser` cmdlet.  
Settings → Apps → Default apps → search for app → set.  
Or use `winget install Nikolai-Bochev.NanaZip` (NanaZip) for a scriptable file association tool.

### [ ] Windows Search indexing — limit scope
Default indexing crawls everything and spikes disk I/O.  
Settings → Privacy & security → Searching Windows → set to "Classic" or exclude large folders:
```
C:\Program Files
C:\Program Files (x86)
node_modules  (any project folder)
```

### [x] Scheduled WSL apt updates
`laptop-setup.ps1` registers `\$USERNAME\WSLWeeklyAptUpgrade` (Sundays @ 9:30 AM).
`wsl-bootstrap.sh` configures passwordless sudo for apt so it runs unattended.

---

## WSL / Docker / Cloud

### [ ] .wslconfig — tune memory for your workload
`laptop-setup.ps1` creates a baseline `.wslconfig` (8 GB / 4 CPUs).  
Adjust after knowing your actual usage — WSL2 will use up to the limit, so size to your RAM:
```ini
[wsl2]
memory=12GB      # or 16GB if you have 32GB total
processors=6
swap=4GB
```

### [ ] Docker Desktop — enable WSL2 backend
After Docker Desktop installs, open it:  
Settings → General → "Use the WSL 2 based engine" ✓  
Settings → Resources → WSL Integration → enable for Ubuntu ✓  

### [ ] kubeconfig — multi-cluster management
If you work with multiple clusters (local kind/minikube + EKS/AKS/GKE), merge contexts:
```powershell
$env:KUBECONFIG = "$HOME\.kube\config;$HOME\.kube\eks-prod;$HOME\.kube\aks-dev"
kubectl config view --merge --flatten > "$HOME\.kube\merged-config"
```
Use `kctx` (already in `powershell-profile.ps1`) to switch contexts with fzf.

---

## Security & Identity

### [ ] 1Password CLI (`op`)
1Password desktop is installed. The CLI (`op`) enables secret injection into shell sessions:
```powershell
winget install AgileBits.1Password.CLI
op signin
op run --env-file=.env -- your-command
```

### [ ] GitHub SSH key provisioning
After generating your SSH key (see Developer Config above), test auth:
```bash
ssh -T git@github.com
# Hi <username>! You've successfully authenticated.
```
Also set git to use SSH for GitHub remotes:
```powershell
git config --global url."git@github.com:".insteadOf "https://github.com/"
```
