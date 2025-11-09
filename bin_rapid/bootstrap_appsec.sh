#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

echo "[*] Running $(basename "$0") …"

if on_macos; then
  section "Installing AppSec tools (TruffleHog, Gitleaks) with Homebrew"
  need_cmd brew || fail "Homebrew not found; install brew first."
  brew install trufflehog gitleaks || true
  ok "AppSec tools installed on macOS."

elif on_linux; then
  section "Installing AppSec tools on Linux"
  if need_cmd apt; then
    sudo apt update -y
    # TruffleHog via pipx
    if ! need_cmd pipx; then
      sudo apt install -y python3-pip pipx || true
      python3 -m pipx ensurepath || true
    fi
    pipx install trufflehog || true

    # Gitleaks via official install script (handles arch/version)
    curl -sfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | sudo bash || true
    ok "AppSec tools installed on Linux (APT)."

  elif need_cmd dnf; then
    sudo dnf install -y python3-pip || true
    if ! need_cmd pipx; then
      python3 -m pip install --user pipx || true
      python3 -m pipx ensurepath || true
      export PATH="$HOME/.local/bin:$PATH"
    fi
    pipx install trufflehog || true
    curl -sfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | sudo bash || true
    ok "AppSec tools installed on Linux (DNF)."

  else
    fail "Unsupported Linux package manager for automatic AppSec setup."
  fi

else
  fail "Unsupported OS."
fi

# Print versions if available
{ command -v trufflehog >/dev/null 2>&1 && trufflehog --version || true; } | sed 's/^/[i] /'
{ command -v gitleaks   >/dev/null 2>&1 && gitleaks   version     || true; } | sed 's/^/[i] /'
