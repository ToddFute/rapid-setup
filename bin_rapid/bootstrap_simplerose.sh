#!/usr/bin/env bash
# bootstrap_simplerose.sh — SimpleRose workstation setup
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

SIMPLE_ROSE_LINK="$HOME/bin/SimpleRose"
SIMPLE_ROSE_TARGET="$HOME/Library/CloudStorage/GoogleDrive-todd@simplerose.com/Other computers/My MacBook Pro/bin/SimpleRose"

ICLOUD_DOCUMENTS="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents"
PERSONAL_ICLOUD="$ICLOUD_DOCUMENTS/Personal"
PERSONAL_HOME="$HOME/Personal"
PERSONAL_DOWNLOADS="$HOME/Downloads/Personal"
ITERM2_SETTINGS_LINK="$HOME/iTerm2Settings"
ITERM2_SETTINGS_TARGET="$ICLOUD_DOCUMENTS/iTerm2Settings"

ensure_symlink() {
  local link="$1" target="$2"

  mkdir -p "$(dirname "$link")"

  if [ -L "$link" ]; then
    local current
    current="$(readlink "$link")"
    if [ "$current" = "$target" ]; then
      ok "Symlink already correct: $link -> $target"
      return 0
    fi
    warn "Replacing existing symlink ($link -> $current)"
    rm "$link"
  elif [ -e "$link" ]; then
    fail "$link exists but is not a symlink. Remove it manually and re-run."
  fi

  if [ ! -e "$target" ]; then
    warn "Target does not exist yet (Google Drive may still be syncing): $target"
  fi

  ln -s "$target" "$link"
  ok "Created symlink: $link -> $target"
}

section "SimpleRose bootstrap"

if ! on_macos; then
  warn "SimpleRose bootstrap is macOS-specific. Skipping."
  exit 0
fi

section "Linking ~/bin/SimpleRose to Google Drive"
ensure_symlink "$SIMPLE_ROSE_LINK" "$SIMPLE_ROSE_TARGET"

section "Linking iCloud shortcuts"
ensure_symlink "$PERSONAL_HOME" "$PERSONAL_ICLOUD"
ensure_symlink "$PERSONAL_DOWNLOADS" "$PERSONAL_HOME"
ensure_symlink "$ITERM2_SETTINGS_LINK" "$ITERM2_SETTINGS_TARGET"

section "Adding SimpleRose to PATH in ~/.zshrc"
PATH_BLOCK_CONTENT='
export PATH="$HOME/bin/SimpleRose:$PATH"
'
upsert_block "$HOME/.zshrc" \
  "# >>> managed: simplerose-path" \
  "# <<< managed: simplerose-path" \
  "$PATH_BLOCK_CONTENT"
ok "PATH block ensured in ~/.zshrc"

ok "SimpleRose bootstrap complete."
