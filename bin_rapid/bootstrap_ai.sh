#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

if on_macos; then
  if ! need_cmd brew; then
    echo "[!] Homebrew not found on macOS. Install brew first." >&2
    exit 1
  fi

  echo "[*] Installing AI tools (Ollama, Aider, Expect)…"
  brew install --cask ollama || true

  # Aider via brew or pipx fallback
  if ! brew install aider || ! command -v aider >/dev/null 2>&1; then
    echo "[i] Falling back to pipx for Aider…"
    brew install pipx || true
    pipx install aider-chat || true
  fi

  brew install expect || true

  # Prompt user to open Ollama if it hasn't been launched yet
  if ! pgrep -f "[o]llama" >/dev/null 2>&1; then
    echo
    echo ">>> Opening Ollama to initialize its service."
    echo ">>> Please approve any macOS prompts, then press Enter to continue."
    open -a "Ollama" || true
    read -r _
  fi

  echo
  echo "[*] Pulling recommended AI models for code & security reviews..."
  MODELS=(
    "llama3.1:8b-instruct-q4_K_M"
    "granite-code:8b"
    "mistral:7b"
    "codellama:7b"
    "gemma2:9b"
    "foundation-sec:8b-instruct"
  )
  for model in "${MODELS[@]}"; do
    echo "[*] Pulling ${model}..."
    ollama pull "$model" || echo "[!] Warning: could not pull ${model}"
  done

  echo "[✓] AI tools installed and models available on macOS."

elif on_linux; then
  echo "[*] Installing AI tools on Linux…"
  if need_cmd apt; then
    sudo apt update -y
    sudo apt install -y expect python3-pip || true
    if ! need_cmd pipx; then
      sudo apt install -y pipx || python3 -m pip install --user pipx || true
      python3 -m pipx ensurepath || true
    fi
    pipx install aider-chat || true
    echo "[i] For Ollama on Linux, see: https://ollama.ai/download"
  elif need_cmd dnf; then
    sudo dnf install -y expect python3-pip || true
    if ! need_cmd pipx; then
      sudo dnf install -y pipx || python3 -m pip install --user pipx || true
      python3 -m pipx ensurepath || true
    fi
    pipx install aider-chat || true
    echo "[i] For Ollama on Linux, see: https://ollama.ai/download"
  else
    echo "[!] Unsupported Linux distro for automated AI setup." >&2
    exit 1
  fi
else
  echo "[!] Unsupported OS." >&2
  exit 1
fi
