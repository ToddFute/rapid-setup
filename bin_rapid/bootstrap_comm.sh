#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

if on_macos; then
  if ! need_cmd brew; then
    echo "[!] Homebrew not found on macOS. Install brew first." >&2
    exit 1
  fi
  echo "[*] Installing communication apps (Slack, Signal, Session)…"
  brew install --cask slack || true
  brew install --cask signal || true
  brew install --cask session || true
  echo "[✓] Communication tools installed on macOS."
elif on_linux; then
  if need_cmd apt; then
    sudo apt update -y
    sudo apt install -y curl wget gpg || true

    echo "[*] Installing Slack…"
    wget -qO /tmp/slack.deb "https://downloads.slack-edge.com/releases/linux/latest/amd64/slack.deb"
    sudo dpkg -i /tmp/slack.deb || sudo apt -f install -y

    echo "[*] Installing Signal…"
    curl -s https://updates.signal.org/desktop/apt/keys.asc | sudo apt-key add -
    echo "deb [arch=amd64] https://updates.signal.org/desktop/apt xenial main" | sudo tee /etc/apt/sources.list.d/signal-xenial.list
    sudo apt update && sudo apt install -y signal-desktop || true

    echo "[*] Installing Session…"
    wget -qO /tmp/session.deb "https://getsession.org/linux/download/session-desktop-latest.deb"
    sudo dpkg -i /tmp/session.deb || sudo apt -f install -y

    echo "[✓] Communication tools installed on Linux (APT)."
  elif need_cmd dnf; then
    echo "[*] Using DNF package manager…"
    sudo dnf install -y slack signal-desktop session-desktop || true
  else
    echo "[!] Unsupported Linux distro for this script." >&2
    exit 1
  fi
else
  echo "[!] Unsupported OS." >&2
  exit 1
fi
