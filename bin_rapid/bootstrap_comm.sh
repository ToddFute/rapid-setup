#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

echo "[*] Running $(basename "$0") …"

if on_macos; then
  section "Installing communication apps (Slack, Signal, Session)"
  need_cmd brew || fail "Homebrew not found; install brew first."
  brew install --cask slack   || true
  brew install --cask signal  || true
  brew install --cask session || true
  ok "Communication tools installed on macOS."

elif on_linux; then
  section "Installing communication apps on Linux"
  if need_cmd apt; then
    sudo apt update -y
    sudo apt install -y curl wget gpg || true

    info "Installing Slack…"
    wget -qO /tmp/slack.deb "https://downloads.slack-edge.com/releases/linux/latest/amd64/slack.deb"
    sudo dpkg -i /tmp/slack.deb || sudo apt -f install -y

    info "Installing Signal…"
    curl -s https://updates.signal.org/desktop/apt/keys.asc | sudo apt-key add -
    echo "deb [arch=amd64] https://updates.signal.org/desktop/apt xenial main" | sudo tee /etc/apt/sources.list.d/signal-xenial.list
    sudo apt update && sudo apt install -y signal-desktop || true

    info "Installing Session…"
    wget -qO /tmp/session.deb "https://getsession.org/linux/download/session-desktop-latest.deb"
    sudo dpkg -i /tmp/session.deb || sudo apt -f install -y

    ok "Communication tools installed on Linux (APT)."
  elif need_cmd dnf; then
    info "Using DNF package manager…"
    sudo dnf install -y slack signal-desktop session-desktop || true
    ok "Communication tools installed on Linux (DNF)."
  else
    fail "Unsupported Linux distro for this script."
  fi

else
  fail "Unsupported OS."
fi
