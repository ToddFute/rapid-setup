#!/usr/bin/env bash
# bootstrap_zsh.sh — macOS-safe Zsh bootstrap
# - Avoids BSD sed issues by using awk for block management
# - Guards all source lines so missing files don't explode
# - Places p10k Instant Prompt near the top of ~/.zshrc
# - Reloads properly (exec zsh -l if not already in zsh)

set -euo pipefail

# -------- pretty logging --------
info() { printf "\033[1;34m[ZSH]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
die()  { printf "\033[1;31m[✗]\033[0m %s\n" "$*" >&2; exit 1; }

ZSHRC="$HOME/.zshrc"
OMZ_DIR="$HOME/.oh-my-zsh"
ITERM_SHELL="$HOME/.iterm2_shell_integration.zsh"
FUNC_DIR="$HOME/.zsh/functional"
FUNC_PLUGIN="$FUNC_DIR/functional.plugin.zsh"

# -------- helpers (macOS-safe) --------
# Remove a managed block delimited by exact BEGIN/END marker lines.
remove_block() {
  local file="$1" begin="$2" end="$3"
  [ -f "$file" ] || return 0
  awk -v begin="$begin" -v end="$end" '
    $0==begin {skip=1; next}
    $0==end   {skip=0; next}
    !skip
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# Upsert a managed block (remove old, then append new content at end).
upsert_block() {
  local file="$1" begin="$2" end="$3" content="$4"
  [ -f "$file" ] || touch "$file"
  remove_block "$file" "$begin" "$end"
  {
    printf "%s\n" "$begin"
    printf "%s\n" "$content"
    printf "%s\n" "$end"
  } >> "$file"
}

# Insert a single line near the very top (after shebang if present), only if absent.
ensure_line_near_top() {
  local file="$1" needle="$2"
  [ -f "$file" ] || touch "$file"
  grep -Fqx "$needle" "$file" 2>/dev/null && return 0
  if head -1 "$file" | grep -qE '^#!'; then
    { head -1 "$file"; echo "$needle"; tail -n +2 "$file"; } > "${file}.tmp" && mv "${file}.tmp" "$file"
  else
    { echo "$needle"; cat "$file"; } > "${file}.tmp" && mv "${file}.tmp" "$file"
  fi
}

# -------- ensure ~/.zshrc exists --------
info "Ensuring ~/.zshrc exists…"
[ -f "$ZSHRC" ] || { touch "$ZSHRC"; ok "Created $ZSHRC"; }

# -------- optional: install Oh My Zsh (unattended) --------
if [ ! -d "$OMZ_DIR" ]; then
  info "Oh My Zsh not found. Install it? (y/N)"
  read -r ans
  if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
    info "Installing Oh My Zsh (unattended)…"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || warn "Oh My Zsh install skipped/failed."
  else
    warn "Skipping Oh My Zsh install."
  fi
else
  info "Oh My Zsh already installed."
fi

# Upsert guarded Oh My Zsh source block
OMZ_BLOCK_CONTENT='[ -s "$HOME/.oh-my-zsh/oh-my-zsh.sh" ] && source "$HOME/.oh-my-zsh/oh-my-zsh.sh"'
upsert_block "$ZSHRC" \
  "# >>> managed: oh-my-zsh" \
  "# <<< managed: oh-my-zsh" \
  "$OMZ_BLOCK_CONTENT"

# -------- optional: install iTerm2 shell integration --------
if [ ! -f "$ITERM_SHELL" ]; then
  info "iTerm2 shell integration not found. Install it? (y/N)"
  read -r ans
  if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
    info "Installing iTerm2 shell integration…"
    curl -fsSL https://iterm2.com/shell_integration/zsh -o "$ITERM_SHELL" || warn "iTerm2 shell integration download failed."
  else
    warn "Skipping iTerm2 shell integration."
  fi
else
  info "iTerm2 shell integration already present."
fi

ITERM_BLOCK_CONTENT='[ -s "$HOME/.iterm2_shell_integration.zsh" ] && source "$HOME/.iterm2_shell_integration.zsh"'
upsert_block "$ZSHRC" \
  "# >>> managed: iterm2-shell-integration" \
  "# <<< managed: iterm2-shell-integration" \
  "$ITERM_BLOCK_CONTENT"

# -------- optional: zsh functional plugin (guarded) --------
# If you have this repo locally, we’ll create the dir if missing and just guard-source it.
if [ ! -f "$FUNC_PLUGIN" ]; then
  info "zsh functional plugin not found at $FUNC_PLUGIN."
  info "Create the folder for a manual plugin drop? (y/N)"
  read -r ans
  if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
    mkdir -p "$FUNC_DIR"
    ok "Created $FUNC_DIR (place functional.plugin.zsh there when ready)."
  else
    warn "Skipping functional plugin folder creation."
  fi
fi

FUNC_BLOCK_CONTENT='[ -s "$HOME/.zsh/functional/functional.plugin.zsh" ] && source "$HOME/.zsh/functional/functional.plugin.zsh"'
upsert_block "$ZSHRC" \
  "# >>> managed: zsh-functional" \
  "# <<< managed: zsh-functional" \
  "$FUNC_BLOCK_CONTENT"

# -------- Powerlevel10k Instant Prompt line (must be near the top) --------
# NOTE: this line uses zsh-specific ${(%)...} syntax; adding it to the file is fine.
P10K_INSTANT='if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"; fi'
ensure_line_near_top "$ZSHRC" "$P10K_INSTANT"

# -------- Quality-of-life defaults (optional) --------
# Keep these as a managed block you can edit/remove later.
QOL_BLOCK_CONTENT='
# macOS-friendly pager/term defaults
export TERM=xterm-256color
export LESS=-R
export PAGER=less
'
upsert_block "$ZSHRC" \
  "# >>> managed: qol-defaults" \
  "# <<< managed: qol-defaults" \
  "$QOL_BLOCK_CONTENT"

ok "Updated $ZSHRC."

# -------- reload safely --------
# Don’t source zsh code from bash (prevents “bad substitution” errors)
if [ -n "${ZSH_VERSION:-}" ]; then
  info "Reloading ~/.zshrc in current zsh…"
  # shellcheck disable=SC1090
  source "$ZSHRC"
  ok "Reloaded."
else
  info "Switching to a login zsh to apply changes…"
  exec zsh -l
fi
