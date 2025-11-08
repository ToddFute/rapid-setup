#!/usr/bin/env bash
set -euo pipefail

# Collect any positional args, e.g. "ai comm misc"
BOOTSTRAP_PARAMS=( "$@" )

# Usage examples:
#   bootstrap.sh                         # no extra tasks
#   bootstrap.sh ai                      # runs bootstrap_ai.sh
#   bootstrap.sh ai comm                 # runs bootstrap_ai.sh, then bootstrap_comm.sh

# ========= Configurable bits =========
RS_REPO_SLUG="${RS_REPO_SLUG:-ToddFute/rapid-setup}"   # <— set your real default
RS_BRANCH="${RS_BRANCH:-main}"
RS_DEST="${RS_DEST:-$HOME/rapid-setup}"
# =====================================

# Prevent recursive re-entry when we exec the repo bootstrap
if [ "${RS_NESTED:-0}" = "1" ]; then
  echo "[i] Nested bootstrap detected; skipping to avoid recursion."
  exit 0
fi

echo "[-] Rapid bootstrap starting…"
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

need_cmd() { command -v "$1" >/dev/null 2>&1; }
have_sudo() { command -v sudo >/dev/null 2>&1; }

# Append LINE to FILE only if it's not already present (exact match).
ensure_line() {
  # $1=file $2=line
  local file="$1" line="$2"
  grep -Fqx -- "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >> "$file"
}

setup_shell_env() {
  echo "[*] Setting up shell aliases…"
  touch "$HOME/.aliases"

  # Ensure windiff alias exists
  ensure_line "$HOME/.aliases" 'alias windiff=opendiff'

  # Ensure .zshrc sources .aliases
  ensure_line "$HOME/.zshrc" '[ -f ~/.aliases ] && source ~/.aliases'

  # Ensure .bashrc sources .aliases too (for Linux/bash users)
  ensure_line "$HOME/.bashrc" '[ -f ~/.aliases ] && source ~/.aliases'
}

# Append/replace a marked block in FILE without duplicating on re-runs.
# Usage: ensure_block "$HOME/.zshrc" "# >>> RAPID START" "# >>> RAPID END" "$BLOCK_CONTENT"
ensure_block() {
  local file="$1" start="$2" end="$3" content="$4"
  local tmp_content tmp_out
  tmp_content="$(mktemp)"
  tmp_out="$(mktemp)"
  printf '%s\n' "$content" > "$tmp_content"

  # If the file exists, remove any existing block between markers (exact line match)
  if [ -f "$file" ]; then
    awk -v s="$start" -v e="$end" '
      $0==s {inblock=1; next}
      $0==e {inblock=0; next}
      !inblock {print}
    ' "$file" > "$tmp_out" && mv "$tmp_out" "$file"
  fi

  # Append fresh block
  {
    printf '%s\n' "$start"
    cat "$tmp_content"
    printf '%s\n' "$end"
  } >> "$file"

  rm -f "$tmp_content" "$tmp_out"
}

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
  ensure_line "$HOME/.zprofile" "$SHELLENV_LINE"
  eval "$("$BREW_BIN" shellenv)"

  ensure_line "$HOME/.zshrc" 'export PATH="$HOME/bin/rapid:$PATH"'
  
  echo "[*] brew update && essentials…"
  brew update

  # ---- Oh My Zsh + Powerlevel10k setup ----
  echo "[*] Setting up Oh My Zsh and Powerlevel10k…"

  # Install Oh My Zsh (non-interactive)
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    echo "[✓] Installed Oh My Zsh."
  else
    echo "[i] Oh My Zsh already present."
  fi

  # Install a Nerd Font (Powerlevel10k requires one)
  brew install --cask font-meslo-lg-nerd-font || true

  # Install Powerlevel10k theme
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    echo "[✓] Installed Powerlevel10k theme."
  else
    echo "[i] Powerlevel10k already installed."
  fi

  # Create or update .zshrc block (idempotent)
  ZSH_BLOCK='export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh'
  ensure_block "$HOME/.zshrc" "# >>> RAPID START" "# >>> RAPID END" "$ZSH_BLOCK"

  # Default to zsh shell if not already
  if [ "$SHELL" != "/bin/zsh" ] && command -v chsh >/dev/null 2>&1; then
    echo "[*] Setting default shell to zsh (you may be prompted for your password)…"
    chsh -s /bin/zsh || true
  fi
  # ---- end Oh My Zsh + Powerlevel10k setup ----
  
  # ---- Aliases and opendiff (Xcode) ----

  # Ensure opendiff is available. It's part of Xcode (FileMerge), not just CLT.
  if ! command -v opendiff >/dev/null 2>&1; then
    echo "[*] opendiff not found. It’s part of Xcode (FileMerge)."
    echo "    I’ll open the App Store to Xcode. Please install it, launch Xcode once,"
    echo "    then press Enter here to continue."
    # Open Xcode page in App Store
    open 'macappstore://itunes.apple.com/app/id497799835' || true
    read -r _
    # Re-check
    if ! command -v opendiff >/dev/null 2>&1; then
      echo "[!] opendiff still not found. After installing Xcode, launch it once to finish setup,"
      echo "    then re-run this bootstrap. You can also run:"
      echo "      sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    else
      echo "[✓] opendiff is available."
    fi
  else
    echo "[i] opendiff is available."
  fi
  # ---- end Aliases and opendiff ----

  brew install git curl wget tree macvim || true
  brew install --cask iterm2 || true
  brew install the_silver_searcher || true
  brew install gh || true
  brew install --cask brave-browser || true

  ensure_vim_configs
}

# ---------- Linux ----------
linux_setup() {
  echo "[*] Detected Linux"
  if need_cmd apt; then
    SUDO="$(have_sudo && echo sudo || echo "")"
    $SUDO apt update -y
    $SUDO apt install -y git curl wget tree vim-gtk3 tar || true
    $SUDO apt install -y gh || true   # may require GitHub CLI repo on some distros
    $SUDO apt install -y silversearcher-ag || true
  elif need_cmd dnf; then
    SUDO="$(have_sudo && echo sudo || echo "")"
    $SUDO dnf install -y git curl wget tree gvim tar || true
    $SUDO dnf install -y gh || true   # package name is 'gh' on recent Fedora
    $SUDO dnf install -y the_silver_searcher || true
  elif need_cmd pacman; then
    SUDO="$(have_sudo && echo sudo || echo "")"
    $SUDO pacman -Syu --noconfirm git curl wget tree gvim tar || true
    $SUDO pacman -S --noconfirm github-cli || true
    $SUDO pacman -S --noconfirm the_silver_searcher || true
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

install_rapid_bin() {
  local SRC="$RS_DEST/bin_rapid"
  local DST="$HOME/bin/rapid"
  if [ -d "$SRC" ]; then
    mkdir -p "$DST"
    rsync -a "$SRC"/ "$DST"/
    chmod -R u+x "$DST" || true
    echo "[✓] Installed ~/bin/rapid from repo/bin_rapid"
    ensure_line "$HOME/.zshrc" 'export PATH="$HOME/bin/rapid:$PATH"'
  else
    echo "[i] bin_rapid not found in repo; skipping ~/bin/rapid install."
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
  # 1) First, run a conventional repo bootstrap if present
  if [ -x "$RS_DEST/bootstrap.sh" ]; then
    # avoid recursion if it's literally the same file
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

  # 2) Then, run any task scripts requested via CLI parameters
  if [ "${#BOOTSTRAP_PARAMS[@]}" -gt 0 ]; then
    echo "[*] Running requested task bootstrap scripts: ${BOOTSTRAP_PARAMS[*]}"
  fi

  for task in "${BOOTSTRAP_PARAMS[@]}"; do
    # search order (first match wins):
    #   a) repo root:           $RS_DEST/bootstrap_<task>.sh
    #   b) repo bin directory:  $RS_DEST/bin_rapid/bootstrap_<task>.sh
    #   c) user's rapid bin:    $HOME/bin/rapid/bootstrap_<task>.sh
    script=""
    for candidate in \
      "$RS_DEST/bootstrap_${task}.sh" \
      "$RS_DEST/bin_rapid/bootstrap_${task}.sh" \
      "$HOME/bin/rapid/bootstrap_${task}.sh"
    do
      if [ -f "$candidate" ]; then
        script="$candidate"
        break
      fi
    done

    if [ -z "$script" ]; then
      echo "[i] Skipping '${task}': no bootstrap_${task}.sh found."
      continue
    fi

    # ensure it's runnable; prefer executing with bash so +x isn’t strictly required
    echo "[*] Running ${script} …"
    ( cd "$(dirname "$script")" && RS_NESTED=1 bash "./$(basename "$script")" ) || {
      echo "[!] bootstrap_${task}.sh failed." >&2
      exit 1
    }
  done
}

# ---------- Execute ----------
if [ "$PLATFORM" = "macos" ]; then
  mac_setup
else
  linux_setup
fi

clone_repo

# Ensure all .sh files are executable
echo "[*] Fixing permissions on shell scripts…"
if [ -d "$RS_DEST" ]; then
  find "$RS_DEST" -type f -name "*.sh" -exec chmod +x {} \;
fi

# Ensure ~/bin/local exists and is before ~/bin/rapid in PATH
mkdir -p "$HOME/bin/local"

# Ensure PATH order in .zshrc or .bashrc
PATH_BLOCK='
# >>> Rapid local bin setup >>>
if [ -d "$HOME/bin/local" ]; then
  PATH="$HOME/bin/local:$PATH"
fi
if [ -d "$HOME/bin/rapid" ]; then
  PATH="$HOME/bin/rapid:$PATH"
fi
export PATH
# <<< Rapid local bin setup <<<
'

# Append only once (using a marker)
if ! grep -q ">>> Rapid local bin setup >>>" "$HOME/.zshrc" 2>/dev/null; then
  echo "$PATH_BLOCK" >> "$HOME/.zshrc"
fi
setup_shell_env

# Ensure EDITOR is set to vim in .zshrc
ensure_line "$HOME/.zshrc" 'export EDITOR=vim'

install_rapid_bin
install_vim_configs_from_repo
ensure_vim_plugins
run_repo_bootstrap

echo "[✓] Bootstrap finished."
