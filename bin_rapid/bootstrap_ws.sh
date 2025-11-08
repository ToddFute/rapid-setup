#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

if ! on_macos; then
  echo "[i] Workspace lock script is macOS-specific. Skipping."
  exit 0
fi

echo "[*] Setting macOS screen lock to 10 minutes and requiring password…"
# Idle timeout in seconds
defaults -currentHost write com.apple.screensaver idleTime -int 600
# Require password immediately
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

echo "[✓] Done. Current values:"
printf "    idleTime:           %s\n" "$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo unset)"
printf "    askForPassword:     %s\n" "$(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo unset)"
printf "    askForPasswordDelay:%s\n" "$(defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo unset)"
