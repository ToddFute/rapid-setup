#!/usr/bin/env bash
set -euo pipefail

RS_REPO_SLUG="${RS_REPO_SLUG:-youruser/rapid-setup}"
RS_BRANCH="${RS_BRANCH:-main}"
RS_DEST="${RS_DEST:-$HOME/rapid-setup}"

echo "[-] Rapid bootstrap starting…"
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

need_cmd() { command -v "$1" >/dev/null 2>&1; }
have_sudo() { command -v sudo >/dev/null 2>&1; }

mac_setup() {
  echo "[*] Detected macOS"
  /usr/bin/xcode-select -p >/dev/null 2>&1 || xcode-select --install || true
  if ! need_cmd brew; then
    echo "[*] Installing Homebrew…"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  brew update
  brew install git curl wget tree macvim || true
  brew install --cask iterm2 || true
  ensure_vim_configs
}

linux_setup() {
  echo "[*] Detected Linux"
  if need_cmd apt; then
    sudo apt update -y && sudo apt install -y git curl wget tree vim-gtk3 tar
  elif need_cmd dnf; then
    sudo dnf install -y git curl wget tree gvim tar
  elif need_cmd pacman; then
    sudo pacman -Syu --noconfirm git curl wget tree gvim tar
  else
    echo "Unsupported Linux distro" >&2; exit 1
  fi
  ensure_vim_configs
}

ensure_vim_configs() {
  if [ ! -f "$HOME/.vimrc" ]; then
    cat > "$HOME/.vimrc" <<'EOF'
set nocompatible
set number relativenumber
set tabstop=2 shiftwidth=2 expandtab
set mouse=a
syntax on
filetype plugin indent on
set clipboard=unnamedplus
EOF
  fi
  if [ ! -f "$HOME/.gvimrc" ]; then
    cat > "$HOME/.gvimrc" <<'EOF'
set lines=40 columns=120
EOF
  fi
}

clone_repo() {
  if command -v git >/dev/null 2>&1; then
    [ -d "$RS_DEST/.git" ] || git clone --depth=1 --branch "$RS_BRANCH" "https://github.com/${RS_REPO_SLUG}.git" "$RS_DEST"
  else
    curl -fsSL "https://codeload.github.com/${RS_REPO_SLUG}/zip/refs/heads/${RS_BRANCH}" -o /tmp/rsrepo.zip
    mkdir -p "$RS_DEST"
    unzip -q /tmp/rsrepo.zip -d /tmp
    cp -R /tmp/$(basename ${RS_REPO_SLUG})-*/* "$RS_DEST"
  fi
}

run_repo_bootstrap() {
  if [ -x "$RS_DEST/bootstrap.sh" ]; then
    (cd "$RS_DEST" && bash ./bootstrap.sh)
  fi
}

[ "$PLATFORM" = "macos" ] && mac_setup || linux_setup
clone_repo
run_repo_bootstrap
echo "[✓] Bootstrap finished."
