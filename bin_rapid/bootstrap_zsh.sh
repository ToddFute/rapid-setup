#!/usr/bin/env bash
# bootstrap_zsh.sh — self-healing Zsh stack for macOS/Linux
# - Fixes export ZSH in ~/.zshrc
# - Installs Oh My Zsh (unattended) if missing
# - Installs iTerm2 shell integration (zsh)
# - Installs "functional" plugin
# - Installs zsh-syntax-highlighting (via Homebrew if available)
# - Adds guarded `source` lines to ~/.zshrc so missing files don't error
# Safe to run repeatedly.

set -euo pipefail

log()  { printf "\033[1;34m[ZSH]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m  %s\n" "$*" >&2; }

detect_brew_prefix() {
  if command -v brew >/dev/null 2>&1; then
    brew --prefix 2>/dev/null || true
  else
    echo ""
  fi
}

ensure_file() {
  local path="$1"
  [ -f "$path" ] || touch "$path"
}

sed_in_place() {
  # macOS and GNU sed compatible in-place replace
  if sed --version >/dev/null 2>&1; then
    sed -i -e "$@"
  else
    sed -i '' -e "$@"
  fi
}

add_guarded_source() {
  local zrc="$1"
  local file="$2"
  local guard="# >>> managed: ${file}"
  # Remove any previous managed block for this file
  sed_in_place "/${guard}/,/^# <<< managed/d" "$zrc" || true
  {
    echo "$guard"
    echo "[ -f \"$file\" ] && source \"$file\""
    echo "# <<< managed"
  } >> "$zrc"
}

install_oh_my_zsh() {
  local omz_dir="$1"
  if [ -d "$omz_dir" ]; then
    log "Oh My Zsh already installed."
    return
  fi
  log "Installing Oh My Zsh (unattended)…"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_iterm2_shell_integration() {
  local it2="$1"
  if [ -f "$it2" ]; then
    log "iTerm2 shell integration already present."
    return
  fi
  log "Installing iTerm2 shell integration for zsh…"
  curl -fsSL https://iterm2.com/shell_integration/zsh -o "$it2" || warn "Could not fetch iTerm2 integration (non-fatal)."
}

install_functional_plugin() {
  local func_file="$1"
  local func_dir
  func_dir="$(dirname "$func_file")"
  if [ -f "$func_file" ]; then
    log "functional plugin already present."
    return
  fi
  log "Installing zsh functional plugin…"
  mkdir -p "$func_dir"
  curl -fsSL https://raw.githubusercontent.com/Tarrasch/zsh-functional/master/functional.plugin.zsh \
    -o "$func_file"
}

install_zsh_syntax_highlighting() {
  local brew_prefix="$1"
  local zsh_highlight_file=""

  # Prefer Homebrew if available
  if [ -n "$brew_prefix" ]; then
    if [ ! -f "${brew_prefix}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
      log "Installing zsh-syntax-highlighting via Homebrew…"
      if ! brew list zsh-syntax-highlighting >/dev/null 2>&1; then
        brew install zsh-syntax-highlighting
      fi
    fi
    zsh_highlight_file="${brew_prefix}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  else
    # Common locations without brew
    for p in \
      /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
      /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
      [ -f "$p" ] && zsh_highlight_file="$p" && break
    done
    if [ -z "$zsh_highlight_file" ]; then
      warn "Homebrew not found and zsh-syntax-highlighting not located. You can install Homebrew or clone the plugin manually."
    fi
  fi

  echo "$zsh_highlight_file"
}

setup_brew_shellenv_block() {
  local zrc="$1"
  if ! grep -q '# >>> managed: brew path' "$zrc"; then
    {
      echo '# >>> managed: brew path'
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true'
      echo 'eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true'
      echo '# <<< managed'
    } >> "$zrc"
  fi
}

setup_zsh_stack() {
  local ZRC="$HOME/.zshrc"
  local OMZ_DIR="$HOME/.oh-my-zsh"
  local IT2="$HOME/.iterm2_shell_integration.zsh"
  local FUNC_DIR="$HOME/.zsh/functional"
  local FUNC_FILE="$FUNC_DIR/functional.plugin.zsh"

  log "Ensuring ~/.zshrc exists…"
  ensure_file "$ZRC"

  # Ensure export ZSH points to ~/.oh-my-zsh
  if grep -qE '^export ZSH=' "$ZRC"; then
    sed_in_place "s|^export ZSH=.*|export ZSH=\"\$HOME/.oh-my-zsh\"|" "$ZRC"
  else
    printf '\nexport ZSH="$HOME/.oh-my-zsh"\n' >> "$ZRC"
  fi

  # Install pieces
  install_oh_my_zsh "$OMZ_DIR"
  install_iterm2_shell_integration "$IT2"
  install_functional_plugin "$FUNC_FILE"

  local BREW_PREFIX
  BREW_PREFIX="$(detect_brew_prefix)"
  local ZSH_HIGHLIGHT_FILE
  ZSH_HIGHLIGHT_FILE="$(install_zsh_syntax_highlighting "$BREW_PREFIX")"

  # Guarded source blocks
  add_guarded_source "$ZRC" "$OMZ_DIR/oh-my-zsh.sh"
  add_guarded_source "$ZRC" "$IT2"
  add_guarded_source "$ZRC" "$FUNC_FILE"
  if [ -n "$ZSH_HIGHLIGHT_FILE" ]; then
    add_guarded_source "$ZRC" "$ZSH_HIGHLIGHT_FILE"
  fi

  # Brew shellenv convenience
  if command -v brew >/dev/null 2>&1; then
    setup_brew_shellenv_block "$ZRC"
  fi

  log "Reloading ~/.zshrc…"
  # shellcheck disable=SC1090
  source "$ZRC" || true

  log "✅ Zsh stack ready. Open a new terminal window if anything still looks off."
}

main() {
  setup_zsh_stack
}

main "$@"
