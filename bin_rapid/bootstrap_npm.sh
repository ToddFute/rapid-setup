#!/usr/bin/env bash
set -euo pipefail
echo "[*] Running $(basename "$0") …"

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[*] Installing Node.js + npm + npx via Homebrew…"
  if ! command -v brew >/dev/null 2>&1; then
    echo "[!] Homebrew not found; install brew first." >&2
    exit 1
  fi
  brew install node || true
  echo "[✓] Node.js, npm, and npx installed on macOS."

elif [[ "$(uname -s)" == "Linux" ]]; then
  echo "[*] Installing Node.js + npm + npx on Linux…"
  if command -v apt >/dev/null 2>&1; then
    sudo apt update -y
    sudo apt install -y nodejs npm || true
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y nodejs npm || true
  else
    echo "[!] Unsupported package manager for automatic Node setup." >&2
    exit 1
  fi
  echo "[✓] Node.js, npm, and npx installed on Linux."
else
  echo "[!] Unsupported OS." >&2
  exit 1
fi
