#!/usr/bin/env bash
set -euo pipefail
echo "[*] Running $(basename "$0") …"

OS="$(uname -s)"
case "$OS" in
  Darwin)
    echo "[*] Installing AppSec tools (TruffleHog, Gitleaks)…"
    if ! command -v brew >/dev/null 2>&1; then
      echo "[!] Homebrew not found; install brew first." >&2
      exit 1
    fi
    brew install trufflehog gitleaks || true
    echo "[✓] AppSec tools installed on macOS."
    ;;

  Linux)
    echo "[*] Installing AppSec tools on Linux…"
    if command -v apt >/dev/null 2>&1; then
      sudo apt update -y
      sudo apt install -y python3-pip wget unzip || true
      pip install --user trufflehog || true
      curl -sSL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_$(uname -s)_x64.tar.gz \
        | sudo tar -xz -C /usr/local/bin gitleaks || true
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y python3-pip wget unzip || true
      pip install --user trufflehog || true
      curl -sSL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_$(uname -s)_x64.tar.gz \
        | sudo tar -xz -C /usr/local/bin gitleaks || true
    else
      echo "[!] Unsupported package manager for automatic AppSec setup." >&2
      exit 1
    fi
    echo "[✓] AppSec tools installed on Linux."
    ;;

  *)
    echo "[!] Unsupported OS: $OS" >&2
    exit 1
    ;;
esac
