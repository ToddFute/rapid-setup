#!/usr/bin/env bash
# rapid: order=40 default=on desc="Oh My Zsh, Powerlevel10k, iTerm2 app and settings"
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

# -------- iTerm2 app --------
# Skips on an existing /Applications/iTerm.app (even a non-Homebrew install, which
# would make `brew install --cask` fail). No upgrade: the cask is auto_updates.
if ! on_macos; then
  info "Not macOS; skipping iTerm2 install."
elif [ -d "/Applications/iTerm.app" ]; then
  info "iTerm2 already installed."
elif ! need_cmd brew; then
  warn "Homebrew not found; skipping iTerm2 install."
else
  info "Installing iTerm2…"
  brew install --cask iterm2 || warn "Could not install iTerm2"
fi

# -------- iTerm2 shell integration --------
if [ -f "$HOME/.iterm2_shell_integration.zsh" ]; then
  info "iTerm2 shell integration already present."
else
  info "Installing iTerm2 shell integration…"
  curl -fsSL https://iterm2.com/shell_integration/zsh \
    -o "$HOME/.iterm2_shell_integration.zsh" || warn "Could not install iTerm2 shell integration"
fi

# -------- iTerm2 settings from iCloud --------
ITERM2_SETTINGS_LINK="$HOME/iTerm2Settings"
ITERM2_SETTINGS_TARGET="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/iTerm2Settings"
if ! on_macos; then
  info "Not macOS; skipping iTerm2 settings."
elif [ ! -d "$ITERM2_SETTINGS_TARGET" ]; then
  warn "iCloud iTerm2Settings not found (not signed in or not synced yet); skipping: $ITERM2_SETTINGS_TARGET"
elif [ -e "$ITERM2_SETTINGS_LINK" ] && [ ! -L "$ITERM2_SETTINGS_LINK" ]; then
  warn "$ITERM2_SETTINGS_LINK exists but is not a symlink; skipping iTerm2 settings."
else
  if [ "$(readlink "$ITERM2_SETTINGS_LINK" 2>/dev/null || true)" = "$ITERM2_SETTINGS_TARGET" ]; then
    info "iTerm2Settings symlink already correct."
  else
    rm -f "$ITERM2_SETTINGS_LINK"
    ln -s "$ITERM2_SETTINGS_TARGET" "$ITERM2_SETTINGS_LINK"
    ok "Linked $ITERM2_SETTINGS_LINK -> $ITERM2_SETTINGS_TARGET"
  fi
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$ITERM2_SETTINGS_LINK"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  ok "iTerm2 set to load settings from $ITERM2_SETTINGS_LINK"
  if pgrep -xq iTerm2; then
    warn "iTerm2 is running: quit and reopen it to load the iCloud settings."
  fi
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

# -------- Remove duplicate loaders --------
# dotfiles/zshrc already sets the theme and loads oh-my-zsh, iTerm2, the
# functional plugin and syntax highlighting. Earlier versions of this script
# (and older marker styles) appended second copies; strip them.
remove_block "$ZSHRC" "# >>> managed: zsh-theme" "# <<< managed: zsh-theme"
remove_block "$ZSHRC" "# >>> managed: zsh-loads" "# <<< managed: zsh-loads"
remove_legacy_blocks "$ZSHRC"

ok "Zsh bootstrap complete."
# This script runs under bash, which can't parse zsh syntax in ~/.zshrc, and a
# child process can't reload the caller's shell anyway.
info "Open a new terminal or run 'exec zsh' to load the updated ~/.zshrc."
