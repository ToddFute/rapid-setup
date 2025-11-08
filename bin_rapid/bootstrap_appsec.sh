#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

install_with_brew() {
  if need_cmd brew; then
    echo "[*] Installing trufflehog via Homebrew…"
    brew install trufflehog || return 1
    return 0
  fi
  return 1
}

install_with_pipx() {
  echo "[*] Installing trufflehog via pipx…"
  if ! need_cmd pipx; then
    if need_cmd brew; then
      brew install pipx || true
    elif need_cmd apt; then
      sudo apt update -y || true
      sudo apt install -y pipx || sudo apt install -y python3-pip && python3 -m pip install --user pipx || true
    elif need_cmd dnf; then
      sudo dnf install -y pipx || sudo dnf install -y python3-pip && python3 -m pip install --user pipx || true
    elif need_cmd pacman; then
      sudo pacman -Sy --noconfirm python-pipx || sudo pacman -Sy --noconfirm python-pip || true
    fi
    command -v pipx >/dev/null 2>&1 || python3 -m pipx ensurepath || true
  fi
  pipx install trufflehog || pipx install truffleHog
}

verify_trufflehog() {
  if command -v trufflehog >/dev/null 2>&1; then
    echo "[✓] trufflehog installed: $(trufflehog --version 2>/dev/null || echo ok)"
    return 0
  fi
  return 1
}

install_with_brew || install_with_pipx || true
verify_trufflehog || { echo "[!] Failed to install trufflehog." >&2; exit 1; }
echo "[✓] AppSec bootstrap complete."
