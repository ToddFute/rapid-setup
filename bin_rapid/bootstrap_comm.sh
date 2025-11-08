#!/usr/bin/env bash
# bootstrap_comm.sh — install communication tools: Slack, Signal, Session
set -euo pipefail

echo "[-] Communication tools bootstrap starting…"

OS="$(uname -s)"
case "$OS" in
  Darwin)
    echo "[*] Detected macOS"

    # Ensure Homebrew exists
    if ! command -v brew >/dev/null 2>&1; then
      echo "[!] Homebrew not found. Installing…"
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    else
      echo "[i] Homebrew already installed."
    fi

    echo "[*] Installing communication apps (Slack, Signal, Session)…"
    brew install --cask slack || true
    brew install --cask signal || true
    brew install --cask session || true

    echo "[✓] Communication tools installed on macOS."
    ;;

  Linux)
    echo "[*] Detected Linux"

    if command -v apt >/dev/null 2>&1; then
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

    elif command -v dnf >/dev/null 2>&1; then
      echo "[*] Using DNF package manager (Fedora/RHEL)…"
      sudo dnf install -y slack signal-desktop session-desktop || true
    else
      echo "[!] Unsupported Linux distro. Please install apps manually."
    fi
    ;;

  *)
    echo "[!] Unsupported OS: $OS"
    exit 1
    ;;
esac

echo "[✓] bootstrap_comm.sh completed."
