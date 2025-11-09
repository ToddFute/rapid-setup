#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

echo "[*] Running $(basename "$0") …"

if on_macos; then
  section "Installing Node.js (includes npm & npx) via Homebrew"
  need_cmd brew || fail "Homebrew not found; install brew first."
  brew install node || true
  ok "Node.js, npm, and npx installed on macOS."

elif on_linux; then
  section "Installing Node.js, npm (and npx) on Linux"
  if need_cmd apt; then
    sudo apt update -y
    sudo apt install -y nodejs npm || true
  elif need_cmd dnf; then
    sudo dnf install -y nodejs npm || true
  else
    fail "Unsupported Linux package manager for automatic Node setup."
  fi
  ok "Node.js, npm, and npx installed on Linux."

else
  fail "Unsupported OS."
fi

# Sanity checks (don’t fail the whole script if versions can’t print)
{ command -v node >/dev/null 2>&1 && node -v || true; } | sed 's/^/[i] /'
{ command -v npm  >/dev/null 2>&1 && npm  -v || true; } | sed 's/^/[i] npm /'
{ command -v npx  >/dev/null 2>&1 && npx  --version || true; } | sed 's/^/[i] npx /'
