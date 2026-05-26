#!/usr/bin/env bash
# =============================================================================
# WSL Ubuntu Bootstrap
# Run from Windows after installing Ubuntu:
#   wsl --install -d Ubuntu
#   wsl -d Ubuntu -- bash /mnt/c/Users/<USERNAME>/Scripts/wsl-bootstrap.sh
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[bootstrap]${RESET} $*"; }
ok()   { echo -e "${GREEN}[ok]${RESET} $*"; }
head() { echo -e "\n${YELLOW}==== $* ====${RESET}"; }

head "System update"
sudo apt update -qq && sudo apt upgrade -y

head "Passwordless sudo for apt (required for Windows scheduled task)"
# Allows wsl.exe -d Ubuntu -- sudo apt upgrade -y to run unattended
SUDOERS_FILE="/etc/sudoers.d/apt-nopasswd"
if [ ! -f "$SUDOERS_FILE" ]; then
    echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get" | \
        sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 0440 "$SUDOERS_FILE"
    ok "Passwordless sudo configured for apt"
else
    ok "Sudoers entry already present"
fi

head "Core packages"
sudo apt install -y \
    build-essential curl wget git vim nano tmux zsh \
    unzip zip ca-certificates gnupg lsb-release \
    apt-transport-https software-properties-common \
    python3 python3-pip python3-venv \
    openssh-client jq

# ── Oh My Zsh ──────────────────────────────────────────────────────────────
head "Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended
    ok "Oh My Zsh installed"
else
    ok "Oh My Zsh already present"
fi

# zsh-autosuggestions plugin
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# zsh-syntax-highlighting plugin
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Patch .zshrc to enable plugins
sed -i 's/^plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting kubectl helm)/' \
    "$HOME/.zshrc" 2>/dev/null || true

# ── nvm + Node.js LTS ──────────────────────────────────────────────────────
head "nvm + Node.js LTS"
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    ok "nvm installed"
fi
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install --lts --latest-npm
nvm use --lts
ok "Node $(node --version) / npm $(npm --version)"

# Gemini CLI
npm install -g @google/gemini-cli
ok "Gemini CLI installed"

# ── Python (pipx for isolated global tools) ────────────────────────────────
head "Python + pipx"
pip3 install --user --upgrade pip pipx
pipx ensurepath
ok "pipx ready"

# ── AWS CLI v2 ─────────────────────────────────────────────────────────────
head "AWS CLI v2"
if ! command -v aws &>/dev/null; then
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/awscli
    sudo /tmp/awscli/aws/install
    rm -rf /tmp/awscli /tmp/awscliv2.zip
    ok "AWS CLI $(aws --version)"
else
    ok "AWS CLI already installed"
fi

# ── Azure CLI ──────────────────────────────────────────────────────────────
head "Azure CLI"
if ! command -v az &>/dev/null; then
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    ok "Azure CLI $(az version --query '\"azure-cli\"' -o tsv)"
else
    ok "Azure CLI already installed"
fi

# ── Google Cloud SDK ───────────────────────────────────────────────────────
head "Google Cloud SDK"
if ! command -v gcloud &>/dev/null; then
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
https://packages.cloud.google.com/apt cloud-sdk main" | \
        sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
        sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    sudo apt update -qq && sudo apt install -y google-cloud-cli
    ok "gcloud installed"
else
    ok "gcloud already installed"
fi

# ── kubectl ────────────────────────────────────────────────────────────────
head "kubectl"
if ! command -v kubectl &>/dev/null; then
    KVER=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    curl -fsSLO "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    ok "kubectl ${KVER}"
else
    ok "kubectl already installed"
fi

# ── Helm ───────────────────────────────────────────────────────────────────
head "Helm"
if ! command -v helm &>/dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    ok "helm $(helm version --short)"
else
    ok "helm already installed"
fi

# ── Terraform ──────────────────────────────────────────────────────────────
head "Terraform"
if ! command -v terraform &>/dev/null; then
    wget -O- https://apt.releases.hashicorp.com/gpg | \
        sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update -qq && sudo apt install -y terraform
    ok "terraform $(terraform version -json | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"terraform_version\"])')"
else
    ok "terraform already installed"
fi

# ── k9s ───────────────────────────────────────────────────────────────────
head "k9s"
if ! command -v k9s &>/dev/null; then
    K9S_VER=$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
    curl -fsSLO "https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_amd64.tar.gz"
    tar xzf k9s_Linux_amd64.tar.gz k9s
    sudo mv k9s /usr/local/bin/
    rm k9s_Linux_amd64.tar.gz
    ok "k9s ${K9S_VER}"
else
    ok "k9s already installed"
fi

# ── Shell completions in .zshrc ────────────────────────────────────────────
head "Shell completions"
ZSHRC="$HOME/.zshrc"
append_if_absent() {
    grep -qF "$1" "$ZSHRC" 2>/dev/null || echo "$1" >> "$ZSHRC"
}

append_if_absent 'source <(kubectl completion zsh)'
append_if_absent 'source <(helm completion zsh)'
append_if_absent 'complete -C aws_completer aws'
append_if_absent 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
append_if_absent 'export PATH="$HOME/.local/bin:$PATH"'
ok "completions wired into .zshrc"

# ── Set zsh as default shell ───────────────────────────────────────────────
head "Default shell"
if [ "$SHELL" != "$(which zsh)" ]; then
    sudo chsh -s "$(which zsh)" "$USER"
    ok "Default shell set to zsh (takes effect on next login)"
else
    ok "zsh already default"
fi

head "Bootstrap complete"
echo -e "${GREEN}All done!${RESET}"
echo "  Start a new WSL session to pick up zsh and all completions."
echo "  First run: gcloud init   aws configure   az login"
