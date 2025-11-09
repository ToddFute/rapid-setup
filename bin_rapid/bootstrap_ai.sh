#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

echo "[*] Running $(basename "$0") …"

# ---- Default Model List ----
declare -a KNOWN_MODELS=(
  "llama3.1:8b-instruct-q4_K_M"
  "granite-code:8b"
  "mistral:7b"
  "phi3:mini"
  "codellama:7b"
  "gemma2:9b"
)

# ---- Helpers ----
menu_pull_models() {
  local -a choices
  local num=1
  echo
  echo "📦 Available models to pull:"
  echo "---------------------------"
  for m in "${KNOWN_MODELS[@]}"; do
    echo "  [$num] $m"
    ((num++))
  done
  echo "  [a]  All of the above"
  echo "  [s]  Skip model pulls"
  echo
  read -rp "Select model(s) (e.g., 1 3 or 'a'): " -a choices

  if [[ "${choices[*]}" =~ [sS] ]]; then
    info "Skipping model pulls."
    return 0
  fi

  local selected=()
  if [[ "${choices[*]}" =~ [aA] ]]; then
    selected=("${KNOWN_MODELS[@]}")
  else
    for c in "${choices[@]}"; do
      if [[ "$c" =~ ^[0-9]+$ ]] && ((c>=1 && c<=${#KNOWN_MODELS[@]})); then
        selected+=("${KNOWN_MODELS[$((c-1))]}")
      fi
    done
  fi

  if ((${#selected[@]}==0)); then
    info "No valid selections. Skipping."
    return 0
  fi

  section "Pulling selected models"
  for m in "${selected[@]}"; do
    echo "→ ollama pull $m"
    ollama pull "$m" || warn "Failed to pull $m"
  done
}

wait_for_ollama() {
  local secs="${1:-60}"
  info "Waiting up to ${secs}s for Ollama service…"
  for _ in $(seq 1 "$secs"); do
    if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
      ok "Ollama is responding."
      return 0
    fi
    sleep 1
  done
  warn "Ollama did not respond within ${secs}s."
}

install_aider_with_fallback() {
  if need_cmd brew; then
    brew install aider || true
    if ! command -v aider >/dev/null 2>&1; then
      info "Installing Aider via pipx (fallback)…"
      brew install pipx || true
      pipx install aider-chat || true
    fi
  else
    if ! command -v pipx >/dev/null 2>&1; then
      if need_cmd apt; then
        sudo apt install -y python3-pip pipx || true
      elif need_cmd dnf; then
        sudo dnf install -y python3-pip pipx || true
      fi
      python3 -m pipx ensurepath || true
    fi
    pipx install aider-chat || true
  fi
}

# ---- Main Logic ----
if on_macos; then
  section "Installing AI tools (Ollama, Aider, Expect)"
  need_cmd brew || fail "Homebrew not found."

  brew install --cask ollama || true
  brew install expect || true
  install_aider_with_fallback

  # Launch Ollama if not active
  if ! pgrep -f "[o]llama" >/dev/null 2>&1; then
    echo
    echo ">>> Opening Ollama app to initialize service."
    echo ">>> Complete any prompts, then press Enter here to continue."
    open -a "Ollama" || true
    read -r _
  fi

  wait_for_ollama || true
  menu_pull_models
  ok "AI tools installed on macOS."

elif on_linux; then
  section "Installing AI tools on Linux"
  if need_cmd apt; then
    sudo apt update -y
    sudo apt install -y expect python3-pip || true
  elif need_cmd dnf; then
    sudo dnf install -y expect python3-pip || true
  fi
  install_aider_with_fallback
  info "See https://ollama.ai/download for Linux Ollama installation."
  ok "AI tools installed on Linux."

else
  fail "Unsupported OS."
fi
