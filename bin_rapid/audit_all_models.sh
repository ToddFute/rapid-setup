#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Environment and terminal setup
# ----------------------------------------------------------------------
export TERM=xterm-256color
export LESS=-R
export PAGER=less
export OLLAMA_API_BASE="${OLLAMA_API_BASE:-http://127.0.0.1:11434}"
export AIDER_NO_OPENAI_WARNING=1
export AIDER_NO_SHOW_MODEL_WARNINGS=1

# ----------------------------------------------------------------------
# Utility functions
# ----------------------------------------------------------------------
die() { echo "❌ $*" >&2; exit 1; }

restore_screen() { printf '\e[?7h'; tput rmcup || true; stty sane || true; }

run_aider_noninteractive() {
  local model="$1"; shift
  echo "[audit] Running aider with model: $model"
  printf '\e[?7h'; tput smcup || true
  if ! aider \
      --provider ollama \
      --model "$model" \
      --ollama-base-url "$OLLAMA_API_BASE" \
      --no-show-model-warnings \
      --yes --no-auto-commits --no-gitignore \
      "$@"
  then
    echo "[warn] aider exited non-zero for model $model"
  fi
  restore_screen
}

# ----------------------------------------------------------------------
# Locate bootstrap_ai.sh to discover installed models
# ----------------------------------------------------------------------
BOOTSTRAP_AI="${HOME}/bin/rapid/bootstrap_ai.sh"
[[ -f "$BOOTSTRAP_AI" ]] || die "[!] Missing $BOOTSTRAP_AI"

# Extract model names from bootstrap_ai.sh
mapfile -t RAW_MODELS < <(awk '
  /ollama[[:space:]]+pull/ {
    for (i=1; i<=NF; i++) if ($i=="pull") {
      m=$(i+1); gsub(/"/,"",m); print m
    }
  }' "$BOOTSTRAP_AI" | sort -u)

[[ ${#RAW_MODELS[@]} -gt 0 ]] || die "[!] No models found in $BOOTSTRAP_AI"

# Normalize names (strip ollama: prefix)
MODELS=()
for m in "${RAW_MODELS[@]}"; do
  MODELS+=("${m#ollama:}")
done

echo "[audit] Models discovered: ${MODELS[*]}"
echo

RESULTS_FILE="$(mktemp)"
trap 'restore_screen || true; echo; echo "[✓] Results saved at $RESULTS_FILE"' EXIT

TARGET_DIR="."

# ----------------------------------------------------------------------
# Main loop
# ----------------------------------------------------------------------
for model in "${MODELS[@]}"; do
  {
    echo "===== $model ====="
    run_aider_noninteractive "$model" "$TARGET_DIR"
    echo
  } | tee -a "$RESULTS_FILE"
done

echo
echo "[✓] Audit complete. Results are in $RESULTS_FILE"
