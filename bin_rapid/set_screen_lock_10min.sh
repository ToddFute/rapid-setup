#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is for macOS only." >&2
  exit 1
fi

echo "[*] Setting macOS screen lock to 10 minutes and requiring password…"

# 1) Start screensaver after 10 minutes (600 seconds)
#    Use per-host setting (recommended on macOS)
defaults -currentHost write com.apple.screensaver idleTime -int 600

# 2) Require password immediately after screensaver or sleep
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# (Optional) Also put the display to sleep after 10 minutes.
# This doesn't affect the password requirement (it will still be required).
# Uncomment if you want display sleep aligned with screensaver:
# sudo pmset -a displaysleep 10

# Nudge services so settings take effect promptly
killall -HUP cfprefsd 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

# Show results
echo "[✓] Done. Current values:"
echo "    idleTime:           $(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo 'unset')"
echo "    askForPassword:     $(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo 'unset')"
echo "    askForPasswordDelay:$(defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo 'unset')"
