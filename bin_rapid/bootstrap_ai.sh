#!/usr/bin/env bash
set -euo pipefail

# macOS via Homebrew
if [[ "$(uname -s)" == "Darwin" ]]; then
  command -v brew >/dev/null 2>&1 || { echo "Homebrew required"; exit 1; }
  brew install ollama aider-expect expect || true
  # If aider-expect formula isn’t available on your tap, fallback to pipx:
  if ! command -v aider >/dev/null 2>&1; then
    brew install pipx || true
    pipx ensurepath || true
    pipx install aider-chat || true
  fi
  echo "[✓] AI tools installed (ollama/aider/expect) on macOS"
  exit 0
fi

# Linux (optional convenience)
if command -v apt >/dev/null 2>&1; then
  sudo apt update -y
  curl -fsSL https://ollama.com/install.sh | sh
  sudo apt install -y expect pipx || true
  pipx ensurepath || true
  pipx install aider-chat || true
  echo "[✓] AI tools installed (ollama/aider/expect) on Debian/Ubuntu"
  exit 0
elif command -v dnf >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
  sudo dnf install -y expect python3-pip || true
  python3 -m pip install --user pipx && ~/.local/bin/pipx ensurepath || true
  ~/.local/bin/pipx install aider-chat || true
  echo "[✓] AI tools installed (ollama/aider/expect) on Fedora/RHEL"
  exit 0
fi

echo "[i] Unsupported OS/distro for automatic AI setup." >&2
