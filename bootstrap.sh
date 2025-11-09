#!/usr/bin/env bash
# Rapid Setup bootstrap (no recursion)
set -euo pipefail

# ---------- Config ----------
RS_REPO_SLUG="${RS_REPO_SLUG:-ToddFute/rapid-setup}"
RS_BRANCH="${RS_BRANCH:-main}"
RS_DEST="${RS_DEST:-$HOME/rapid-setup}"

# ---------- Arg capture ----------
declare -a BOOTSTRAP_PARAMS=()
if [ -n "${0-}" ] && [ "$0" != "bash" ] && [ "$0" != "-bash" ]; then
  BOOTSTRAP_PARAMS=( "$0" "$@" )
else
  BOOTSTRAP_PARAMS=( "$@" )
fi
# Strip out -- and empties
_tmp=()
for a in "${BOOTSTRAP_PARAMS[@]}"; do
  [ -z "$a" ] && continue
  [ "$a" = "--" ] && continue
  _tmp+=( "$a" )
done
BOOTSTRAP_PARAMS=( "${_tmp[@]}" )
unset _tmp

# ---------- Helpers ----------
need_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_line() {
  local file="$1" line="$2"
  grep -Fqx -- "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >> "$file"
}

ensure_block() {
  # Remove any prior block delimited by start/end markers, then append a fresh one.
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

# Optional: install Vim bits if referenced by ~/.vimrc
ensure_vim_plugins() {
  # Pathogen
  if grep -qs 'pathogen#infect' "$HOME/.vimrc"; then
    if [ ! -f "$HOME/.vim/autoload/pathogen.vim" ]; then
      echo "[*] Installing pathogen.vim…"
      mkdir -p "$HOME/.vim/autoload" "$HOME/.vim/bundle"
      curl -fsSLo "$HOME/.vim/autoload/pathogen.vim" \
        https://tpo.pe/pathogen.vim
    fi
  fi
  # Badwolf theme
  if grep -qs 'colorscheme[[:space:]]\+badwolf' "$HOME/.vimrc"; then
    if [ ! -d "$HOME/.vim/bundle/badwolf" ]; then
      echo "[*] Installing badwolf colorscheme…"
      git clone --depth=1 https://github.com/sjl/badwolf.git "$HOME/.vim/bundle/badwolf"
    fi
  fi
}

# ---------- Dotfiles installer (prefers dotfiles/, falls back to legacy vim/) ----------
_mapped_target_name() {
  case "$1" in
    vimrc)            echo ".vimrc" ;;
    gvimrc)           echo ".gvimrc" ;;
    p10k.zsh)         echo ".p10k.zsh" ;;
    aliases)          echo ".aliases" ;;
    gitconfig)        echo ".gitconfig" ;;
    gitignore_global) echo ".gitignore_global" ;;
    zshrc)            echo ".zshrc" ;;          # <— add this line
    zshrc.extra)      echo ".zshrc.extra" ;;
    *)                echo ".$1" ;;
  esac
}

install_dotfiles_from_repo() {
  local SRC_DIR=""
  if [ -d "$RS_DEST/dotfiles" ]; then
    SRC_DIR="$RS_DEST/dotfiles"
  elif [ -d "$RS_DEST/vim" ]; then
    SRC_DIR="$RS_DEST/vim"   # legacy support
  fi
  [ -n "$SRC_DIR" ] || { echo "[i] No dotfiles directory found; skipping."; return 0; }

  local MODE="${RS_DOTFILES_MODE:-copy}"
  local BAK_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BAK_DIR"

  # Track whether we installed a full ~/.zshrc from dotfiles
  ZSHRC_INSTALLED_FROM_REPO=0

  shopt -s nullglob
  for path in "$SRC_DIR"/*; do
    [ -f "$path" ] || continue
    local base target
    base="$(basename "$path")"

    if [ "$(basename "$SRC_DIR")" = "vim" ]; then
      case "$base" in
        .vimrc|.gvimrc) target="$HOME/$base" ;;
        vimrc)           target="$HOME/.vimrc" ;;
        gvimrc)          target="$HOME/.gvimrc" ;;
        *)               continue ;;
      esac
    else
      target="$HOME/$(_mapped_target_name "$base")"
    fi

    # backup if different
    if [ -e "$target" ] && ! cmp -s "$path" "$target"; then
      mv -f "$target" "$BAK_DIR/$(basename "$target")"
      echo "[i] Backed up $(basename "$target") → $BAK_DIR/"
    fi

    if [ "$MODE" = "link" ]; then
      ln -snf "$path" "$target"
    else
      cp -f "$path" "$target"
    fi
    echo "[✓] Installed $(basename "$target") from repo"

    # Remember if we installed ~/.zshrc
    if [ "$target" = "$HOME/.zshrc" ]; then
      ZSHRC_INSTALLED_FROM_REPO=1
    fi
  done
  shopt -u nullglob

  # Ensure Vim plugins if referenced
  [ -f "$HOME/.vimrc" ] && ensure_vim_plugins || true
}

install_rapid_bin() {
  local SRC="$RS_DEST/bin_rapid"
  local DST="$HOME/bin/rapid"
  if [ -d "$SRC" ]; then
    mkdir -p "$DST"
    shopt -s dotglob nullglob
    cp -R "$SRC"/* "$DST"/ 2>/dev/null || true
    shopt -u dotglob nullglob
    chmod -R u+x "$DST" || true
    echo "[✓] Installed ~/bin/rapid from repo/bin_rapid"
  fi
}

setup_shell_env() {
  echo "[*] Setting up shell environment…"

  # Aliases file + include
  touch "$HOME/.aliases"
  ensure_line "$HOME/.aliases" 'alias windiff=opendiff'
  ensure_line "$HOME/.zshrc" '[ -f ~/.aliases ] && source ~/.aliases' || true
  ensure_line "$HOME/.bashrc" '[ -f ~/.aliases ] && source ~/.aliases' || true

  # EDITOR
  if ! grep -Eq '^\s*export\s+EDITOR=' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export EDITOR=vim' >> "$HOME/.zshrc"
  fi

  # PATH: ~/bin/local first, then ~/bin/rapid
  mkdir -p "$HOME/bin/local"
  local PATH_BLOCK='
# >>> Rapid PATH >>>
if [ -d "$HOME/bin/local" ]; then PATH="$HOME/bin/local:$PATH"; fi
if [ -d "$HOME/bin/rapid" ]; then PATH="$HOME/bin/rapid:$PATH"; fi
export PATH
# <<< Rapid PATH <<<
'
  ensure_block "$HOME/.zshrc" "# >>> RAPID PATH START" "# >>> RAPID PATH END" "$PATH_BLOCK"

  # Only inject the Oh My Zsh + Powerlevel10k block if we did NOT install a full .zshrc from repo.
  if [ "${ZSHRC_INSTALLED_FROM_REPO:-0}" -ne 1 ]; then
    ensure_block "$HOME/.zshrc" "# >>> RAPID OMZ START" "# >>> RAPID OMZ END" \
'export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
[ -f ~/.zshrc.extra ] && source ~/.zshrc.extra'
  fi
}

# ---------- macOS setup ----------
mac_setup() {
  echo "[*] Detected macOS"

  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "Don't run this as root on macOS." >&2; exit 1
  fi

  if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
    echo "[*] Installing Xcode Command Line Tools…"
    xcode-select --install || true
    echo ">>> After the installer finishes, press Enter to continue."
    read -r _
  fi

  echo "[*] Caching sudo (enter your macOS password once)…"
  if sudo -v; then
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
  else
    echo "[!] Could not cache sudo; Homebrew may prompt or fail if you aren't an Admin." >&2
  fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "[*] Installing Homebrew…"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  local BREW_BIN
  if   [ -x /opt/homebrew/bin/brew ]; then BREW_BIN=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then BREW_BIN=/usr/local/bin/brew
  else BREW_BIN="$(command -v brew)"; fi

  local SHELLENV_LINE='eval "$('"$BREW_BIN"' shellenv)"'
  ensure_line "$HOME/.zprofile" "$SHELLENV_LINE"
  eval "$("$BREW_BIN" shellenv)"

  echo "[*] Installing core tools…"
  brew update
  brew install git curl wget tree macvim gh the_silver_searcher || true
  brew install --cask iterm2 brave-browser || true

  echo "[*] Setting up Oh My Zsh and Powerlevel10k…"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  # Try Nerd Font (ignore failures if tap/layout changes)
  brew install --cask font-meslo-lg-nerd-font || true

  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
  fi

  # Ensure Zsh loads OMZ + P10k and optional config
  ensure_block "$HOME/.zshrc" "# >>> RAPID OMZ START" "# >>> RAPID OMZ END" \
'export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
[ -f ~/.zshrc.extra ] && source ~/.zshrc.extra'
}

# ---------- Linux setup ----------
linux_setup() {
  echo "[*] Detected Linux"
  local SUDO=""; command -v sudo >/dev/null 2>&1 && SUDO="sudo"
  if command -v apt >/dev/null 2>&1; then
    $SUDO apt update -y
    $SUDO apt install -y git curl wget tree vim-gtk3 gh silversearcher-ag || true
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y git curl wget tree gvim gh the_silver_searcher || true
  elif command -v pacman >/dev/null 2>&1; then
    $SUDO pacman -Syu --noconfirm git curl wget tree gvim github-cli the_silver_searcher || true
  fi
}

# ---------- Repo clone / refresh ----------
clone_repo() {
  echo "[*] Getting your repo: $RS_REPO_SLUG@$RS_BRANCH → $RS_DEST"
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    echo "[*] Using gh clone (fresh copy)…"
    rm -rf "$RS_DEST"
    gh repo clone "$RS_REPO_SLUG" "$RS_DEST" -- --depth=1 --branch "$RS_BRANCH"
  else
    if [ -d "$RS_DEST/.git" ]; then
      echo "[*] Existing repo — refreshing from remote…"
      ( cd "$RS_DEST" && git fetch origin "$RS_BRANCH" --depth=1 && git reset --hard "origin/$RS_BRANCH" && git clean -fdx )
    else
      git clone --depth=1 --branch "$RS_BRANCH" "https://github.com/${RS_REPO_SLUG}.git" "$RS_DEST"
    fi
  fi
  echo "[✓] Repo ready."
}

# ---------- Run requested task scripts ----------
run_tasks() {
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
      if [ -f "$candidate" ]; then script="$candidate"; break; fi
    done
    if [ -z "$script" ]; then
      echo "[i] Skipping '${task}': no bootstrap_${task}.sh found."
      continue
    fi
    ( cd "$(dirname "$script")" && bash "./$(basename "$script")" )
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
# Make repo shell scripts executable
find "$RS_DEST" -type f -name "*.sh" -exec chmod +x {} \; || true

install_rapid_bin
install_dotfiles_from_repo
setup_shell_env
run_tasks

echo "[✓] Bootstrap finished."
