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
      --yes --no-auto-commits --no-gitignore \
      "$@"
  then
    echo "[warn] aider exited non-zero for model $model"
  fi
  restore_screen
}
