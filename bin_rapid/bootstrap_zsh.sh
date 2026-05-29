#!/usr/bin/env bash
# bootstrap_zsh.sh — ensure Oh My Zsh, Powerlevel10k, syntax highlighting, functional plugin, and Pygments
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

info() { printf "\033[1;34m[ZSH]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
die()  { printf "\033[1;31m[✗]\033[0m %s\n" "$*" >&2; exit 1; }

ZSHRC="$HOME/.zshrc"
ZSH_DIR="$HOME/.oh-my-zsh"

info "Ensuring ~/.zshrc exists…"
touch "$ZSHRC"

# -------- Install Oh My Zsh --------
if [ ! -d "$ZSH_DIR" ]; then
  info "Installing Oh My Zsh…"
  RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
else
  info "Oh My Zsh already installed."
fi

# -------- iTerm2 shell integration --------
if [ -f "$HOME/.iterm2_shell_integration.zsh" ]; then
  info "iTerm2 shell integration already present."
else
  info "Installing iTerm2 shell integration…"
  curl -fsSL https://iterm2.com/shell_integration/zsh \
    -o "$HOME/.iterm2_shell_integration.zsh" || warn "Could not install iTerm2 shell integration"
fi

# -------- Powerlevel10k theme --------
if [ ! -d "$ZSH_DIR/custom/themes/powerlevel10k" ]; then
  info "Installing Powerlevel10k theme…"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_DIR/custom/themes/powerlevel10k"
else
  info "Powerlevel10k already installed."
fi

# -------- Functional plugin --------
FUNCTIONAL_DIR="$HOME/.zsh/functional"
if [ -f "$FUNCTIONAL_DIR/functional.plugin.zsh" ] && [ -d "$FUNCTIONAL_DIR/src" ]; then
  info "Functional plugin already present."
elif [ -d "$FUNCTIONAL_DIR/.git" ]; then
  info "Updating zsh functional plugin…"
  git -C "$FUNCTIONAL_DIR" pull --ff-only || warn "Could not update zsh functional plugin"
else
  info "Installing zsh functional plugin…"
  mkdir -p "$HOME/.zsh"
  rm -rf "$FUNCTIONAL_DIR"
  git clone --depth=1 https://github.com/Tarrasch/zsh-functional.git "$FUNCTIONAL_DIR" \
    || warn "Could not install zsh functional plugin"
fi

# -------- Syntax highlighting --------
if [ ! -f "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  info "Installing zsh-syntax-highlighting…"
  brew install zsh-syntax-highlighting || warn "Could not install zsh-syntax-highlighting"
else
  info "zsh-syntax-highlighting already installed."
fi

# -------- Install pygments if missing --------
if ! command -v pygmentize >/dev/null 2>&1; then
  info "Installing Pygments (provides pygmentize)…"
  if command -v brew >/dev/null 2>&1; then
    brew install pygments || warn "Homebrew Pygments install failed"
  else
    python3 -m pip install --user Pygments || warn "pip Pygments install failed"
  fi
fi

# -------- pygmentize guard (fallback) --------
PYGMENTIZE_BLOCK_CONTENT='
# Prevent zsh errors when pygmentize is missing
if ! command -v pygmentize >/dev/null 2>&1; then
  alias pygmentize="cat"
fi
'
upsert_block "$ZSHRC" \
  "# >>> managed: pygmentize-guard" \
  "# <<< managed: pygmentize-guard" \
  "$PYGMENTIZE_BLOCK_CONTENT"

# -------- QoL block --------
QOL_BLOCK_CONTENT='
# Emacs line editing (Ctrl-P/A/N history & motion; macOS zsh defaults to self-insert)
bindkey -e

export TERM=xterm-256color
export LESS=-R
export PAGER=less
export EDITOR=vim
'
upsert_block "$ZSHRC" \
  "# >>> managed: zsh-qol-defaults" \
  "# <<< managed: zsh-qol-defaults" \
  "$QOL_BLOCK_CONTENT"

# -------- Theme setup --------
THEME_BLOCK_CONTENT='
ZSH_THEME="powerlevel10k/powerlevel10k"
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
'
upsert_block "$ZSHRC" \
  "# >>> managed: zsh-theme" \
  "# <<< managed: zsh-theme" \
  "$THEME_BLOCK_CONTENT"

# -------- Load shell extras --------
LOAD_BLOCK_CONTENT='
# Load iTerm2 integration
[[ -f ~/.iterm2_shell_integration.zsh ]] && source ~/.iterm2_shell_integration.zsh

# Load functional plugin
[[ -f ~/.zsh/functional/functional.plugin.zsh ]] && source ~/.zsh/functional/functional.plugin.zsh

# Load syntax highlighting
[[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
'
upsert_block "$ZSHRC" \
  "# >>> managed: zsh-loads" \
  "# <<< managed: zsh-loads" \
  "$LOAD_BLOCK_CONTENT"

ok "Reloading ~/.zshrc…"
# shellcheck disable=SC1090
source "$ZSHRC" || warn "Some startup warnings may appear on first load."

ok "Zsh bootstrap complete."
