#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Terminal/env safety to prevent redraw corruption
# ----------------------------------------------------------------------
export TERM=xterm-256color
export LESS=-R
export PAGER=less
export OLLAMA_API_BASE="${OLLAMA_API_BASE:-http://127.0.0.1:11434}"
export AIDER_NO_OPENAI_WARNING=1

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

restore_screen() { printf '\e[?7h'; tput rmcup || true; stty sane || true; }

run_aider_clean() {
  local model="$1"; shift
  printf '\n[audit] Running aider with model: %s\n' "$model"
  printf '\e[?7h'; tput smcup || true
  # No prompts, no model warnings; keep output non-interactive
  if ! aider \
      --model "$model" \
      --yes --no-auto-commits --no-gitignore --no-show-model-warnings \
      "$@"
  then
    echo "[warn] aider exited with a nonzero code for model $model"
  fi
  restore_screen
}

BOOTSTRAP_AI="${HOME}/bin/rapid/bootstrap_ai.sh"
[[ -f "$BOOTSTRAP_AI" ]] || { echo "[!] Missing $BOOTSTRAP_AI"; exit 1; }

# Parse model list from `ollama pull "<model>"` lines
mapfile -t RAW_MODELS < <(awk '/ollama[[:space:]]+pull/ {
  for (i=1; i<=NF; i++) if ($i == "pull") {print $(i+1)}
}' "$BOOTSTRAP_AI" | tr -d '"' | sort -u)

[[ ${#RAW_MODELS[@]} -gt 0 ]] || { echo "[!] No models found in bootstrap_ai.sh"; exit 1; }

# Ensure every model is qualified as an Ollama model
MODELS=()
for m in "${RAW_MODELS[@]}"; do
  if [[ "$m" == ollama:* ]]; then
    MODELS+=("$m")
  else
    MODELS+=("ollama:$m")
  fi
done

echo "[audit] Models: ${MODELS[*]}"
echo

RESULTS_FILE="$(mktemp)"
trap 'restore_screen; echo; echo "[✓] Results saved at '"$RESULTS_FILE"'"' EXIT

# Use current dir as the target repo (user can `cd` beforehand)
TARGET_DIR="."

for model in "${MODELS[@]}"; do
  echo "[audit] Running aider for model: $model" | tee -a "$RESULTS_FILE"
  echo "----------------------------------------" >> "$RESULTS_FILE"
  {
    run_aider_clean "$model" "$TARGET_DIR" | tee -a "$RESULTS_FILE"
  } || true
  echo >> "$RESULTS_FILE"
done

echo
echo "[✓] Audit complete. Results are in $RESULTS_FILE"
