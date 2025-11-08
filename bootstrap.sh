#!/usr/bin/env bash
# Rapid Setup bootstrap
set -euo pipefail

# ---------- Config (override via env) ----------
RS_REPO_SLUG="${RS_REPO_SLUG:-ToddFute/rapid-setup}"
RS_BRANCH="${RS_BRANCH:-main}"
RS_DEST="${RS_DEST:-$HOME/rapid-setup}"

# ---------- Args capture (robust for bash -c / -s / direct run) ----------
declare -a BOOTSTRAP_PARAMS=()
if [ -n "${0-}" ] && [ "$0" != "bash" ] && [ "$0" != "-bash" ]; then
  BOOTSTRAP_PARAMS=( "$0" "$@" )
else
  BOOTSTRAP_PARAMS=( "$@" )
fi

# ---------- Nested guard flag (don’t re-chain in children) ----------
if [ "${RS_NESTED:-0}" = "1" ]; then
  NESTED=1
else
  NESTED=0
fi

# ---------- Helpers ----------
need_cmd() { command -v "$1" >/dev/null 2>&1; }
have_sudo() { command -v sudo >/dev/null 2>&1; }

ensure_line() {
  # ensure_line FILE LINE
  local file="$1" line="$2"
  grep -Fqx -- "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >> "$file"
}

ensure_block() {
  # ensure_block FILE START_MARK END_MARK CONTENT
  local file="$1" start="$2" end="$3" content="$4"
  local tmp_content tmp_out
  tmp_content="$(mktemp)"; tmp_out="$(mktemp)"
  printf '%s\n' "$content" > "$tmp_content"
  if [ -f "$file" ]; then
    awk -v s="$start" -v e="$end" '
      $0==s {inblock=1; next}
      $0==e {inblock=0; next}
      !inblock {print}
    ' "$file" > "$tmp_out" && mv "$tmp_out" "$file"
  fi
  { printf '%s\n' "$start"; cat "$tmp_content"; printf '%s\n' "$end"; } >> "$file"
  rm -f "$tmp_content" "$tmp_out"
}

ensure_vim_plugins() {
  # Only install if .vimrc references pathogen/badwolf
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

install_vim_configs_from_repo() {
  # Copy .vimrc / .gvimrc from repo if present
  if [ -f "$RS_DEST/.vimrc" ]; then
    cp -f "$RS_DEST/.vimrc" "$HOME/.vimrc"
    echo "[✓] Installed ~/.vimrc from repo"
  fi
  if [ -f "$RS_DEST/.gvimrc" ]; then
    cp -f "$RS_DEST/.gvimrc" "$HOME/.gvimrc"
    echo "[✓] Installed ~/.gvimrc from repo"
  fi
}

install_rapid_bin() {
  local SRC="$RS_DEST/bin_rapid"
  local DST="$HOME/bin/rapid"
  if [ -d "$SRC" ]; then
    mkdir -p "$DST"
    # portable copy (no rsync dependency)
    shopt -s dotglob nullglob
    cp -R "$SRC"/* "$DST"/ 2>/dev/null || true
    shopt -u dotglob nullglob
    chmod -R u+x "$DST" || true
    echo "[✓] Installed ~/bin/rapid from repo/bin_rapid"
  else
    echo "[i] bin_rapid not found in repo; skipping ~/bin/rapid install."
  fi
}

setup_shell_env() {
  echo "[*] Setting up common shell environment…"
  # Ensure ~/.aliases with windiff
  touch "$HOME/.aliases"
  ensure_line "$HOME/.aliases" 'alias windiff=opendiff'
  # Source .aliases in zsh & bash
  ensure_line "$HOME/.zshrc" '[ -f ~/.aliases ] && source ~/.aliases'
  ensure_line "$HOME/.bashrc" '[ -f ~/.aliases ] && source ~/.aliases'
  # EDITOR
  if ! grep -Eq '^\s*export\s+EDITOR=' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export EDITOR=vim' >> "$HOME/.zshrc"
  fi
  # ~/bin/local before ~/bin/rapid
  mkdir -p "$HOME/bin/local"
  local PATH_BLOCK='
# >>> Rapid local/rapid bin setup >>>
if [ -d "$HOME/bin/local" ]; then
  PATH="$HOME/bin/local:$PATH"
fi
if [ -d "$HOME/bin/rapid" ]; then
  PATH="$HOME/bin/rapid:$PATH"
fi
export PATH
# <<< Rapid local/rapid bin setup <<<
'
  ensure_block "$HOME/.zshrc" "# >>> RAPID PATH START" "# >>> RAPID PATH END" "$PATH_BLOCK"
}

# ---------- OS-specific setup ----------
mac_setup() {
  echo "[*] Detected macOS"

  # Not as root (Homebrew refuses root)
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "Don't run this script with sudo on macOS. Re-run as your normal user." >&2
    exit 1
  fi

  # Xcode Command Line Tools
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

  # Cache sudo so brew can use it internally
  echo "[*] Caching sudo (enter your macOS password once)…"
  if sudo -v; then
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
  else
    echo "[!] Could not cache sudo; Homebrew may prompt or fail if you aren't an Admin." >&2
  fi

  # Install Homebrew if missing
  if ! command -v brew >/dev/null 2>&1; then
    echo "[*] Installing Homebrew…"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Activate brew in current and future shells
  local BREW_BIN
  if [ -x /opt/homebrew/bin/brew ]; then
    BREW_BIN=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    BREW_BIN=/usr/local/bin/brew
  else
    BREW_BIN="$(command -v brew)"
  fi
  local SHELLENV_LINE
  SHELLENV_LINE='eval "$('"$BREW_BIN"' shellenv)"'
  ensure_line "$HOME/.zprofile" "$SHELLENV_LINE"
  eval "$("$BREW_BIN" shellenv)"

  echo "[*] brew update && essentials…"
  brew update
  # CLI
  brew install git curl wget tree macvim gh the_silver_searcher || true
  # Apps
  brew install --cask iterm2 brave-browser || true

  # Oh-My-Zsh + Powerlevel10k
  echo "[*] Setting up Oh My Zsh and Powerlevel10k…"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    echo "[✓] Installed Oh My Zsh."
  else
    echo "[i] Oh My Zsh already present."
  fi
  brew install --cask font-meslo-lg-nerd-font || true
  local ZSH_CUSTOM
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    echo "[✓] Installed Powerlevel10k theme."
  else
    echo "[i] Powerlevel10k already installed."
  fi
  local ZSH_BLOCK
  ZSH_BLOCK='export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh'
  ensure_block "$HOME/.zshrc" "# >>> RAPID OMZ START" "# >>> RAPID OMZ END" "$ZSH_BLOCK"

  # opendiff requires full Xcode (FileMerge). Prompt if missing.
  if ! command -v opendiff >/dev/null 2>&1; then
    echo "[*] opendiff not found. It’s part of Xcode (FileMerge)."
    echo "    Opening App Store to Xcode. Install it, launch once, then press Enter here."
    open 'macappstore://itunes.apple.com/app/id497799835' || true
    read -r _
  fi

  # Default to zsh (optional, no-op if already zsh)
  if [ "${SHELL:-}" != "/bin/zsh" ] && command -v chsh >/dev/null 2>&1; then
    chsh -s /bin/zsh || true
  fi
}

linux_setup() {
  echo "[*] Detected Linux"
  local SUDO=""
  if have_sudo; then SUDO="sudo"; fi

  if need_cmd apt; then
    $SUDO apt update -y
    $SUDO apt install -y git curl wget tree vim-gtk3 tar || true
    # gh may require GH CLI repo on some distros; try best-effort
    $SUDO apt install -y gh || true
    $SUDO apt install -y silversearcher-ag || true
  elif need_cmd dnf; then
    $SUDO dnf install -y git curl wget tree gvim tar || true
    $SUDO dnf install -y gh || true
    $SUDO dnf install -y the_silver_searcher || true
  elif need_cmd pacman; then
    $SUDO pacman -Syu --noconfirm git curl wget tree gvim tar || true
    $SUDO pacman -S --noconfirm github-cli the_silver_searcher || true
  else
    echo "Unsupported Linux distro (apt/dnf/pacman not found)." >&2
    exit 1
  fi
}

# ---------- Repo clone / refresh ----------
clone_repo() {
  echo "[*] Getting your repo: $RS_REPO_SLUG@$RS_BRANCH → $RS_DEST"

  # Prefer gh if available & authed
  if need_cmd gh && gh auth status >/dev/null 2>&1; then
    echo "[*] Using gh to clone (forces fresh copy)…"
    rm -rf "$RS_DEST"
    gh repo clone "$RS_REPO_SLUG" "$RS_DEST" -- --depth=1 --branch "$RS_BRANCH"
    echo "[✓] Repo refreshed from remote"
    return
  fi

  if need_cmd git; then
    if [ -d "$RS_DEST/.git" ]; then
      echo "[*] Existing repo found — forcing remote to override local copy"
      ( cd "$RS_DEST"
        git fetch origin "$RS_BRANCH" --depth=1
        git reset --hard "origin/$RS_BRANCH"
        git clean -fdx
      )
    else
      echo "[*] Cloning fresh repo…"
      git clone --depth=1 --branch "$RS_BRANCH" "https://github.com/${RS_REPO_SLUG}.git" "$RS_DEST"
    fi
    echo "[✓] Repo ready at $RS_DEST"
  else
    echo "[!] git not found and gh not available — cannot fetch repo." >&2
    exit 1
  fi
}

# ---------- Run repo bootstrap and requested tasks ----------
run_repo_bootstrap() {
  # If we’re already inside a child bootstrap, don’t chain further.
  if [ "${NESTED:-0}" = "1" ]; then
    echo "[i] Nested call: skipping run_repo_bootstrap to avoid recursion."
  else
    if [ -x "$RS_DEST/bootstrap.sh" ]; then
      # skip if literally same file to avoid self-loop
      if cmp -s "$0" "$RS_DEST/bootstrap.sh"; then
        echo "[i] Repo bootstrap is the same script; skipping to avoid loop."
      else
        echo "[*] Running repo bootstrap.sh…"
        ( cd "$RS_DEST" && RS_NESTED=1 bash ./bootstrap.sh )
      fi
    elif [ -x "$RS_DEST/macos/setup.sh" ] && [ "${PLATFORM:-}" = "macos" ]; then
      echo "[*] Running macOS setup…"
      ( cd "$RS_DEST/macos" && RS_NESTED=1 bash ./setup.sh )
    elif [ -x "$RS_DEST/linux/setup.sh" ] && [ "${PLATFORM:-}" = "linux" ]; then
      echo "[*] Running Linux setup…"
      ( cd "$RS_DEST/linux" && RS_NESTED=1 bash ./setup.sh )
    else
      echo "[i] No repo bootstrap found; proceeding to task scripts (if any)."
    fi
  fi

  # Run requested task scripts: bootstrap_<param>.sh
  if (( ${#BOOTSTRAP_PARAMS[@]} )); then
    echo "[*] Running requested task bootstrap scripts: ${BOOTSTRAP_PARAMS[*]}"
  fi
  for task in "${BOOTSTRAP_PARAMS[@]}"; do
    local script=""
    for candidate in \
      "$RS_DEST/bootstrap_${task}.sh" \
      "$RS_DEST/bin_rapid/bootstrap_${task}.sh" \
      "$HOME/bin/rapid/bootstrap_${task}.sh"
    do
      if [ -f "$candidate" ]; then
        script="$candidate"; break
      fi
    done
    if [ -z "$script" ]; then
      echo "[i] Skipping '${task}': no bootstrap_${task}.sh found."
      continue
    fi
    echo "[*] Running ${script} …"
    ( cd "$(dirname "$script")" && RS_NESTED=1 bash "./$(basename "$script")" )
  done
}

# ---------- Main ----------
echo "[-] Rapid bootstrap starting…"

OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos"; mac_setup ;;
  Linux)  PLATFORM="linux"; linux_setup ;;
  *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

clone_repo

# Fix permissions on any .sh in repo
echo "[*] Fixing permissions on shell scripts…"
find "$RS_DEST" -type f -name "*.sh" -exec chmod +x {} \; || true

install_vim_configs_from_repo
install_rapid_bin
setup_shell_env
ensure_vim_plugins || true

run_repo_bootstrap

echo "[✓] Bootstrap finished."
