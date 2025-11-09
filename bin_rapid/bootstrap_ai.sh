#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

# ---- Tunables (override via env) ----
: "${AI_WAIT_SECS:=60}"                         # how long to wait for Ollama to respond
: "${AI_PULL_MODELS:=0}"                        # set to 1 to pull models automatically
: "${AI_MODELS:=llama3.1:8b-instruct-q4_K_M granite-code:8b}"  # space-separated list
: "${AI_LINUX_INSTALL_OLLAMA:=0}"               # set to 1 to auto-run Ollama official installer on Linux

ollama_url="http://localhost:11434"

wait_for_ollama() {
  local secs="${1:-$AI_WAIT_SECS}"
  info "Waiting up to ${secs}s for Ollama service…"
  local i
  for i in $(seq 1 "$secs"); do
    if curl -fsS "${ollama_url}/api/tags" >/dev/null 2>&1; then
      ok "Ollama is responding."
      return 0
    fi
    sleep 1
  done
  warn "Ollama did not respond within ${secs}s."
  return 1
}

pull_models_if_requested() {
  if [ "${AI_PULL_MODELS}" != "1" ]; then
    info "Skipping model pulls (set AI_PULL_MODELS=1 to enable)."
    return 0
  fi
  if ! command -v ollama >/dev/null 2>&1; then
    warn "ollama CLI not found; skipping model pulls."
    return 0
  fi
  section "Pulling models"
  # shellcheck disable=SC2086
  for m in ${AI_MODELS}; do
    ollama pull "$m" || true
  done
}

install_aider_with_fallback() {
  if need_cmd brew; then
    brew install aider || true
    if ! command -v aider >/dev/null 2>&1; then
      info "Installing Aider via pipx (fallback)…"
      brew install pipx || true
      command -v pipx >/dev/null 2>&1 || python3 -m pip install --user pipx || true
      command -v pipx >/dev/null 2>&1 || python3 -m pipx ensurepath || true
      pipx install aider-chat || true
    fi
  else
    if ! command -v pipx >/dev/null 2>&1; then
      if need_cmd apt; then
        sudo apt update -y || true
        sudo apt install -y pipx || sudo apt install -y python3-pip && python3 -m pip install --user pipx || true
      elif need_cmd dnf; then
        sudo dnf install -y pipx || sudo dnf install -y python3-pip && python3 -m pip install --user pipx || true
      elif need_cmd pacman; then
        sudo pacman -Sy --noconfirm python-pipx || sudo pacman -Sy --noconfirm python-pip || true
      fi
      command -v pipx >/dev/null 2>&1 || python3 -m pipx ensurepath || true
    fi
    pipx install aider-chat || true
  fi
}

echo "[*] Running $(basename "$0") …"

if on_macos; then
  need_cmd brew || fail "Homebrew not found on macOS. Install brew first."

  section "Installing AI tools (Ollama, Aider, Expect)"
  brew install --cask ollama || true

  # Ensure the daemon is initialized at least once
  if ! pgrep -f "[o]llama" >/dev/null 2>&1; then
    echo
    echo ">>> Launching the Ollama app to initialize the service."
    echo ">>> Complete any prompts, then press Enter here to continue."
    open -a "Ollama" || true
    read -r _
  fi

  brew install expect || true
  install_aider_with_fallback

  wait_for_ollama || true
  pull_models_if_requested
  ok "AI tools installed on macOS."

elif on_linux; then
  section "Installing AI tools on Linux"
  if need_cmd apt; then
    sudo apt update -y
    sudo apt install -y expect python3-pip || true
  elif need_cmd dnf; then
    sudo dnf install -y expect python3-pip || true
  elif need_cmd pacman; then
    sudo pacman -Sy --noconfirm expect python-pip || true
  fi
  install_aider_with_fallback

  if [ "${AI_LINUX_INSTALL_OLLAMA}" = "1" ]; then
    section "Installing Ollama via official script"
    curl -fsSL https://ollama.com/install.sh | sh || warn "Ollama installation script failed (continuing without Ollama)."
    (command -v systemctl >/dev/null 2>&1 && sudo systemctl start ollama) || true
    wait_for_ollama || true
    pull_models_if_requested
  else
    info "Not installing Ollama automatically on Linux (AI_LINUX_INSTALL_OLLAMA=1 to enable)."
    info "See: https://ollama.ai/download"
  fi

  ok "AI tools installed on Linux."

else
  fail "Unsupported OS."
fi
