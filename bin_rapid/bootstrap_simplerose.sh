#!/usr/bin/env bash
# bootstrap_simplerose.sh — SimpleRose workstation setup
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

GOOGLE_DRIVE_ROOT="${HOME}/Library/CloudStorage/GoogleDrive-todd@simplerose.com"
SIMPLE_ROSE_LINK="${HOME}/bin/SimpleRose"
SIMPLE_ROSE_TARGET="${GOOGLE_DRIVE_ROOT}/Other computers/My MacBook Pro/bin/SimpleRose"
NOTES_LINK="${HOME}/Notes"
NOTES_TARGET="${GOOGLE_DRIVE_ROOT}/My Drive/Notes"
ZOOMBG_LINK="${HOME}/ZoomBG"
ZOOMBG_TARGET="${GOOGLE_DRIVE_ROOT}/My Drive/ZoomBG"

ICLOUD_DOCUMENTS="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/Documents"
PERSONAL_ICLOUD="${ICLOUD_DOCUMENTS}/Personal"
PERSONAL_HOME="${HOME}/Personal"
PERSONAL_DOWNLOADS="${HOME}/Downloads/Personal"
ITERM2_SETTINGS_LINK="${HOME}/iTerm2Settings"
ITERM2_SETTINGS_TARGET="${ICLOUD_DOCUMENTS}/iTerm2Settings"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

section "Linking ~/Notes to Google Drive"
ensure_symlink "$NOTES_LINK" "$NOTES_TARGET"

section "Linking ~/ZoomBG to Google Drive"
ensure_symlink "$ZOOMBG_LINK" "$ZOOMBG_TARGET"

section "Linking iCloud shortcuts"
ensure_symlink "$PERSONAL_HOME" "$PERSONAL_ICLOUD"
ensure_symlink "$PERSONAL_DOWNLOADS" "$PERSONAL_HOME"
ensure_symlink "$ITERM2_SETTINGS_LINK" "$ITERM2_SETTINGS_TARGET"

section "Installing ~/.vimrc.simplerose"
VIMRC_SIMPLE_ROSE_SRC="${REPO_ROOT}/dotfiles/vimrc.simplerose"
if [ -f "$VIMRC_SIMPLE_ROSE_SRC" ]; then
  cp "$VIMRC_SIMPLE_ROSE_SRC" "${HOME}/.vimrc.simplerose"
  ok "Installed ${HOME}/.vimrc.simplerose"
else
  warn "Not found: $VIMRC_SIMPLE_ROSE_SRC (run from rapid-setup repo checkout)"
fi

section "Adding SimpleRose to PATH in ~/.zshrc"
PATH_BLOCK_CONTENT='
export PATH="$HOME/bin/SimpleRose:$PATH"
'
upsert_block "$HOME/.zshrc" \
  "# >>> managed: simplerose-path" \
  "# <<< managed: simplerose-path" \
  "$PATH_BLOCK_CONTENT"
ok "PATH block ensured in ~/.zshrc"

section "Installing SimpleRose cron entries"
CRONTAB_SRC="${REPO_ROOT}/dotfiles/crontab.simplerose"
CRONTAB_TMP="$(mktemp)"
if [ -f "$CRONTAB_SRC" ]; then
  crontab -l 2>/dev/null > "$CRONTAB_TMP" || true
  CRONTAB_CONTENT="$(cat "$CRONTAB_SRC")"
  upsert_block "$CRONTAB_TMP" \
    "# >>> managed: simplerose-cron" \
    "# <<< managed: simplerose-cron" \
    "$CRONTAB_CONTENT"
  crontab "$CRONTAB_TMP"
  rm -f "$CRONTAB_TMP"
  ok "Installed SimpleRose cron entries"
else
  warn "Not found: $CRONTAB_SRC (run from rapid-setup repo checkout)"
fi

ok "SimpleRose bootstrap complete."
