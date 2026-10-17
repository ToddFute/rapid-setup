#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

echo "[*] Running $(basename "$0") …"

section "Installing Node.js, npm, npx, and yarn"

if on_macos; then
  need_cmd brew || fail "Homebrew not found on macOS. Please install it first."
  
  # Install Node.js (includes npm and npx)
  if ! command -v node >/dev/null 2>&1; then
    echo "[*] Installing Node.js (includes npm and npx)…"
    brew install node || true
  else
    info "Node.js already installed."
  fi

  # Yarn
  if ! command -v yarn >/dev/null 2>&1; then
    echo "[*] Installing Yarn package manager…"
    brew install yarn || true
  else
    info "Yarn already installed."
  fi

  ok "Node.js, npm, npx, and Yarn installed on macOS."

elif on_linux; then
  if need_cmd apt; then
    section "Installing Node.js (Debian/Ubuntu)"
    sudo apt update -y
    sudo apt install -y nodejs npm curl || true

    # Yarn setup via Corepack (recommended by Node.js team)
    if ! command -v yarn >/dev/null 2>&1; then
      echo "[*] Installing Yarn via Corepack…"
      sudo corepack enable || true
    fi

  elif need_cmd dnf; then
    section "Installing Node.js (Fedora/RHEL)"
    sudo dnf install -y nodejs npm curl || true
    if ! command -v yarn >/dev/null 2>&1; then
      echo "[*] Installing Yarn via npm…"
      sudo npm install -g yarn || true
    fi

  else
    fail "Unsupported Linux package manager. Install Node.js manually."
  fi

  ok "Node.js, npm, npx, and Yarn installed on Linux."

else
  fail "Unsupported OS."
fi
