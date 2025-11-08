#!/usr/bin/env bash
set -euo pipefail

# macOS via Homebrew
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[*] Installing AI tools…"
  if command -v brew >/dev/null 2>&1; then
    # Try installing directly from brew
    brew install aider expect || true

    brew install --cask ollama || true

    # If the app isn't actually installed yet, prompt user
    if [ ! -d "/Applications/Ollama.app" ]; then
      open -a Ollama || true
      echo
      echo "⚠️  Ollama app installation requires user confirmation."
      echo "👉 macOS should now show a dialog asking to install Ollama."
      echo "   Please approve it in the dialog, wait for installation to finish,"
      echo "   then press [Enter] here to continue..."
      read -r _
    fi

    # wait for server to respond
    for i in {1..60}; do
      if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
    ollama pull llama3.1:8b-instruct-q4_K_M || true
    ollama pull granite-code:8b || true

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
