#!/usr/bin/env bash
set -euo pipefail

# macOS via Homebrew
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[*] Installing AI tools…"
  if command -v brew >/dev/null 2>&1; then
    # Try installing directly from brew
    brew install ollama aider expect || true

    # If aider not found, fall back to pipx
    if ! command -v aider >/dev/null 2>&1; then
      echo "[i] Installing aider via pipx…"
      brew install pipx || true
      pipx ensurepath || true
      pipx install aider-chat || true
    fi
  else
    echo "[!] Homebrew not found; skipping brew installs."
  fi
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
