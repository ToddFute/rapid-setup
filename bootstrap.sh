#!/usr/bin/env bash
set -euo pipefail

# ========= Configurable bits =========
RS_REPO_SLUG="${RS_REPO_SLUG:-ToddFute/rapid-setup}"   # <— set your real default
RS_BRANCH="${RS_BRANCH:-main}"
RS_DEST="${RS_DEST:-$HOME/rapid-setup}"
# =====================================

echo "[-] Rapid bootstrap starting…"
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

need_cmd() { command -v "$1" >/dev/null 2>&1; }
have_sudo() { command -v sudo >/dev/null 2>&1; }

# ---------- macOS ----------
mac_setup() {
  echo "[*] Detected macOS"

  # Homebrew refuses root; require normal user
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "Don't run this script with sudo on macOS. Re-run as your normal user." >&2
    exit 1
  fi

  # Ensure Xcode Command Line Tools (needed by Homebrew)
  if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
    echo "[*] Installing Xcode Command Line Tools (a dialog may appear)…"
    xcode-select --install || true
    echo
    echo ">>> After the installer finishes, press Enter to continue."
    read -r _
    until /usr/bin/xcode-select -p >/dev/null 2>&1; do
      echo "…still not detected. Finish the CLT installer, then press Enter to check again."
      read -r _
    done
    echo "[✓] Xcode Command Line Tools detected."
  fi

  # Warm & keep-alive sudo so Homebrew can run its internal sudo cleanly
  echo "[*] Caching sudo (enter your macOS password once)…"
  if sudo -v; then
    # Refresh sudo timestamp every 60s while this script runs
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
  else
    echo "[!] Could not cache sudo; Homebrew may prompt or fail if you aren't an Admin." >&2
  fi

  # Install Homebrew if missing
  if ! command -v brew >/dev/null 2>&1; then
    echo "[*] Installing Homebrew…"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Determine brew path and activate for this shell + future sessions
  if [ -x /opt/homebrew/bin/brew ]; then
    BREW_BIN=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    BREW_BIN=/usr/local/bin/brew
  else
    BREW_BIN="$(command -v brew)"
  fi

  SHELLENV_LINE='eval "$('"$BREW_BIN"' shellenv)"'
  if ! grep -Fq "$SHELLENV_LINE" "$HOME/.zprofile" 2>/dev/null; then
    echo "$SHELLENV_LINE" >> "$HOME/.zprofile"
  fi
  eval "$("$BREW_BIN" shellenv)"

  echo "[*] brew update && essentials…"
  brew update
  brew install git curl wget tree macvim || true
  brew install --cask iterm2 || true

  ensure_vim_configs
}

# ---------- Linux ----------
linux_setup() {
  echo "[*] Detected Linux"
  if need_cmd apt; then
    SUDO="$(have_sudo && echo sudo || echo "")"
    $SUDO apt update -y
    $SUDO apt install -y git curl wget tree vim-gtk3 tar
  elif need_cmd dnf; then
    SUDO="$(have_sudo && echo sudo || echo "")"
    $SUDO dnf install -y git curl wget tree gvim tar
  elif need_cmd pacman; then
    SUDO="$(have_sudo && echo sudo || echo "")"
    $SUDO pacman -Syu --noconfirm git curl wget tree gvim tar
  else
    echo "Unsupported Linux distro (apt/dnf/pacman not found)." >&2
    exit 1
  fi
  ensure_vim_configs
}

# ---------- Shared helpers ----------
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
    echo "[✓] Wrote $HOME/.vimrc"
  fi

  if [ ! -f "$HOME/.gvimrc" ]; then
    cat > "$HOME/.gvimrc" <<'EOF'
set lines=40 columns=120
EOF
    echo "[✓] Wrote $HOME/.gvimrc"
  fi
}

download_tarball() {
  local url="https://github.com/${RS_REPO_SLUG}/archive/refs/heads/${RS_BRANCH}.tar.gz"
  local tmpdir; tmpdir="$(mktemp -d)"
  echo "[*] Fetching repo tarball: $url"
  curl -fsSL "$url" -o "$tmpdir/repo.tar.gz"
  mkdir -p "$RS_DEST"
  tar -xzf "$tmpdir/repo.tar.gz" -C "$tmpdir"
  # Move extracted folder (named <reponame>-<branch>) into RS_DEST
  local src_dir
  src_dir="$(find "$tmpdir" -maxdepth 1 -type d -name "$(basename "$RS_REPO_SLUG")-$RS_BRANCH" -o -name "$(basename "$RS_REPO_SLUG")-*" | head -n1)"
  if [ -z "$src_dir" ] || [ ! -d "$src_dir" ]; then
    echo "[!] Could not locate extracted repo dir; leaving tarball in $tmpdir" >&2
    return 1
  fi
  shopt -s dotglob
  cp -R "$src_dir"/* "$RS_DEST"/
  shopt -u dotglob
  echo "[✓] Repo contents placed in $RS_DEST"
}

clone_repo() {
  if [ "${RS_SKIP_CLONE:-0}" = "1" ]; then
    echo "[*] RS_SKIP_CLONE=1 set; skipping repo fetch."
    return 0
  fi

  echo "[*] Getting your repo: $RS_REPO_SLUG@$RS_BRANCH → $RS_DEST"

  # If gh is authenticated, prefer it
  if need_cmd gh && gh auth status >/dev/null 2>&1; then
    echo "[*] Using gh to clone (forces fresh copy)…"
    rm -rf "$RS_DEST"
    gh repo clone "$RS_REPO_SLUG" "$RS_DEST" -- --depth=1 --branch "$RS_BRANCH"
    echo "[✓] Repo refreshed from remote"
    return
  fi

  # Fallback to plain git if gh not available
  if need_cmd git; then
    if [ -d "$RS_DEST/.git" ]; then
      echo "[*] Existing repo found — forcing remote to override local copy"
      (
        cd "$RS_DEST"
        git fetch origin "$RS_BRANCH" --depth=1
        # Hard reset to remote branch
        git reset --hard "origin/$RS_BRANCH"
        git clean -fdx
      )
    else
      echo "[*] Cloning fresh repo…"
      git clone --depth=1 --branch "$RS_BRANCH" "https://github.com/${RS_REPO_SLUG}.git" "$RS_DEST"
    fi
    echo "[✓] Repo ready at $RS_DEST"
  else
    echo "[*] git not found; using tarball method."
    download_tarball
  fi
}

install_vim_configs_from_repo() {
  # Choose the first existing source path for each file (root or vim/ directory)
  local SRC_VIMRC=""
  local SRC_GVIMRC=""
  [ -f "$RS_DEST/.vimrc" ]        && SRC_VIMRC="$RS_DEST/.vimrc"
  [ -z "$SRC_VIMRC" ] && [ -f "$RS_DEST/vim/.vimrc" ] && SRC_VIMRC="$RS_DEST/vim/.vimrc"

  [ -f "$RS_DEST/.gvimrc" ]       && SRC_GVIMRC="$RS_DEST/.gvimrc"
  [ -z "$SRC_GVIMRC" ] && [ -f "$RS_DEST/vim/gvimrc" ] && SRC_GVIMRC="$RS_DEST/vim/gvimrc"

  # Copy if present; back up existing files if they differ
  if [ -n "$SRC_VIMRC" ]; then
    if [ -f "$HOME/.vimrc" ] && ! cmp -s "$SRC_VIMRC" "$HOME/.vimrc"; then
      cp "$HOME/.vimrc" "$HOME/.vimrc.bak.$(date +%Y%m%d%H%M%S)"
    fi
    cp -f "$SRC_VIMRC" "$HOME/.vimrc"
    echo "[✓] Installed ~/.vimrc from repo"
  fi

  if [ -n "$SRC_GVIMRC" ]; then
    if [ -f "$HOME/.gvimrc" ] && ! cmp -s "$SRC_GVIMRC" "$HOME/.gvimrc"; then
      cp "$HOME/.gvimrc" "$HOME/.gvimrc.bak.$(date +%Y%m%d%H%M%S)"
    fi
    cp -f "$SRC_GVIMRC" "$HOME/.gvimrc"
    echo "[✓] Installed ~/.gvimrc from repo"
  fi
}

ensure_vim_plugins() {
  # Only install if .vimrc references pathogen or badwolf
  if grep -q 'pathogen#infect' "$HOME/.vimrc" 2>/dev/null; then
    mkdir -p "$HOME/.vim/autoload" "$HOME/.vim/bundle"
    if [ ! -f "$HOME/.vim/autoload/pathogen.vim" ]; then
      echo "[*] Installing pathogen…"
      curl -fLo "$HOME/.vim/autoload/pathogen.vim" --create-dirs https://tpo.pe/pathogen.vim
    fi
  fi

  if grep -q 'badwolf' "$HOME/.vimrc" 2>/dev/null; then
    if [ ! -d "$HOME/.vim/bundle/badwolf" ]; then
      echo "[*] Installing badwolf colorscheme…"
      git clone --depth=1 https://github.com/sjl/badwolf.git "$HOME/.vim/bundle/badwolf"
    fi
  fi
}

run_repo_bootstrap() {
  if [ -x "$RS_DEST/bootstrap.sh" ]; then
    echo "[*] Running repo bootstrap.sh…"
    (cd "$RS_DEST" && bash ./bootstrap.sh)
  elif [ -x "$RS_DEST/macos/setup.sh" ] && [ "$PLATFORM" = "macos" ]; then
    echo "[*] Running macOS setup…"
    (cd "$RS_DEST/macos" && bash ./setup.sh)
  elif [ -x "$RS_DEST/linux/setup.sh" ] && [ "$PLATFORM" = "linux" ]; then
    echo "[*] Running Linux setup…"
    (cd "$RS_DEST/linux" && bash ./setup.sh)
  else
    echo "[i] No repo bootstrap found; base tools installed. You can customize later in $RS_DEST."
  fi
}

# ---------- Execute ----------
if [ "$PLATFORM" = "macos" ]; then
  mac_setup
else
  linux_setup
fi

clone_repo
install_vim_configs_from_repo
ensure_vim_plugins
run_repo_bootstrap

echo "[✓] Bootstrap finished."
