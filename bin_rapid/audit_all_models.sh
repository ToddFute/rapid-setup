#!/usr/bin/env bash
set -euo pipefail

# --- terminal/env safety (prevent redraw issues) ---
export TERM=xterm-256color
export LESS=-R
export PAGER=less

# --- Ollama/Aider env ---
export OLLAMA_API_BASE="${OLLAMA_API_BASE:-http://127.0.0.1:11434}"
export AIDER_NO_OPENAI_WARNING=1
# extra belt-and-suspenders for old aider versions:
export AIDER_NO_SHOW_MODEL_WARNINGS=1

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

BOOTSTRAP_AI="${HOME}/bin/rapid/bootstrap_ai.sh"
[[ -f "$BOOTSTRAP_AI" ]] || die "[!] Missing $BOOTSTRAP_AI"

# Parse models from bootstrap_ai.sh (lines like: ollama pull "model")
# We keep the *bare* model name for Aider and force provider via --provider ollama
mapfile -t RAW_MODELS < <(awk '
  /ollama[[:space:]]+pull/ {
    for (i=1; i<=NF; i++) if ($i=="pull") {
      m=$(i+1);
      gsub(/"/,"",m);
      print m
    }
  }' "$BOOTSTRAP_AI" | sort -u)

[[ ${#RAW_MODELS[@]} -gt 0 ]] || die "[!] No models found in $BOOTSTRAP_AI"

# Normalize: if someone wrote ollama:prefix, strip it to bare for Aider+--provider
MODELS=()
for m in "${RAW_MODELS[@]}"; do
  m="${m#ollama:}"
  MODELS+=("$m")
done

echo "[audit] Models: ${MODELS[*]}"
echo

restore_screen() { printf '\e[?7h'; tput rmcup || true; stty sane || true; }
trap 'restore_screen || true' EXIT

run_aider_noninteractive() {
  local model="$1"; shift
  echo "[audit] Running aider with model: $model"
  printf '\e[?7h'; tput smcup || true
  # Non-interactive, suppress model prompts, force provider & base url
  if ! aider \
      --provider ollama \
      --model "$model" \
      --ollama-base-url "$OLLAMA_API_BASE" \
      --no-show-model-warnings \
      --yes --no-auto-commits --no-gitignore --no-show-model-warnings \
      "$@"
  then
    echo "[warn] aider exited non-zero for model $model"
  fi
  restore_screen
}

RESULTS_FILE="$(mktemp)"
echo "[audit] Results will be saved to: $RESULTS_FILE"
echo

TARGET_DIR="."

for model in "${MODELS[@]}"; do
  {
    echo "===== $model ====="
    run_aider_noninteractive "$model" "$TARGET_DIR"
    echo
  } | tee -a "$RESULTS_FILE"
done

echo
echo "[✓] Audit complete. Results in $RESULTS_FILE"
