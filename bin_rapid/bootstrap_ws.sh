#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

echo "[*] Running $(basename "$0") …"

if ! on_macos; then
  info "Workspace lock script is macOS-specific. Skipping."
  exit 0
fi

section "Ensuring cloudflared is installed"
if command -v cloudflared >/dev/null 2>&1; then
  ok "cloudflared already installed at $(command -v cloudflared)"
else
  if command -v brew >/dev/null 2>&1; then
    info "Installing cloudflared via Homebrew…"
    # idempotent: install or upgrade if already present
    brew install cloudflared >/dev/null 2>&1 || brew upgrade cloudflared >/dev/null 2>&1 || true

    if command -v cloudflared >/dev/null 2>&1; then
      ok "cloudflared installed."
    else
      info "Tried to install cloudflared, but it is still not on PATH."
    fi
  else
    info "Homebrew not found; cannot auto-install cloudflared. Install it manually and re-run if needed."
  fi
fi

section "Setting macOS screen lock to 10 minutes and requiring password"
# Idle timeout in seconds
defaults -currentHost write com.apple.screensaver idleTime -int 600
# Require password immediately
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

ok "Done. Current values:"
printf "    idleTime:           %s\n" "$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo unset)"
printf "    askForPassword:     %s\n" "$(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo unset)"
printf "    askForPasswordDelay:%s\n" "$(defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo unset)"
