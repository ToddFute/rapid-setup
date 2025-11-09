#!/usr/bin/env zsh
# audit_all_models.sh — run the same security review across all models listed in bootstrap_ai.sh
# - Reads models dynamically from ~/bin/rapid/bootstrap_ai.sh (expects MODELS=( "..."))
# - Runs aider once per model in the current repo (cd into the codebase first)
# - Collects logs under ./model_audits and prints a summary
# Usage:
#   cd /path/to/codebase
#   ~/bin/rapid/audit_all_models.sh
# Optional env:
#   PROMPT_FILE=path/to/prompt.txt   (default: auto-generated OWASP/CWE prompt)
#   EXTRA_ARGS='--no-git --message ...'  (extra args passed to aider)

set -euo pipefail

# --- tiny logger ---
blue() { print -P "%F{33}[audit]%f $*"; }
warn() { print -P "%F{214}[warn]%f  $*"; }
err()  { print -P "%F{196}[err]%f   $*" >&2; }

# --- locate bootstrap_ai.sh and extract models ---
RAPID_DIR="${HOME}/bin/rapid"
AI_BOOT="${RAPID_DIR}/bootstrap_ai.sh"
[[ -f "$AI_BOOT" ]] || { err "Missing ${AI_BOOT}"; exit 1; }

# Extract quoted items inside a MODELS=( ... ) stanza (tolerates comments/whitespace)
# Works with BSD sed/grep on macOS.
get_models() {
  sed -n '/^[[:space:]]*MODELS[[:space:]]*=.*(/,/^[[:space:]]*)[[:space:]]*$/p' "$AI_BOOT" \
    | sed 's/#.*//' \
    | tr -d '()' \
    | grep -Eo '"[^"]+"' \
    | tr -d '"' \
    | awk 'NF>0'
}

typeset -a MODELS
MODELS=()
for m in $(get_models); do
  MODELS+=("$m")
done

if (( ${#MODELS} == 0 )); then
  err "No models found in MODELS=(...) inside ${AI_BOOT}."
  exit 1
fi

blue "Models: ${MODELS[*]}"

# --- ensure aider exists ---
if ! command -v aider >/dev/null 2>&1; then
  err "aider not found on PATH. Install it (pipx/pip/brew) and retry."
  exit 1
fi

# --- prompt prep ---
DEFAULT_PROMPT=$'Please review the following code for security vulnerabilities according to the OWASP Top 10 and CWE categories. List each issue with:\n- Title\n- Affected files/lines (if known)\n- Severity (Critical/High/Medium/Low) and rationale\n- Exploitability and impact\n- Recommended fix with example patches\n\nThen provide:\n- A prioritized remediation plan\n- A risk score out of 10 (10 = safest) for the current state\n\nIf repository secrets or misconfigurations are detected (tokens, keys, .env, hardcoded credentials, debug flags, verbose logging of sensitive data, insecure defaults), call them out explicitly.'
PROMPT_FILE="${PROMPT_FILE:-}"
if [[ -z "${PROMPT_FILE}" ]]; then
  PROMPT_FILE="$(mktemp -t aider_prompt.XXXXXX)"
  print -- "$DEFAULT_PROMPT" > "$PROMPT_FILE"
fi
blue "Using prompt: ${PROMPT_FILE}"

# --- workspace for logs ---
AUDIT_DIR="${PWD}/model_audits"
mkdir -p "$AUDIT_DIR"

timestamp() { date +"%Y-%m-%d_%H-%M-%S"; }

# --- run aider per model ---
typeset -A SCORES
typeset -A LOGPATH

for model in "${MODELS[@]}"; do
  safe="$(print -- "$model" | tr '/:' '__')"
  logf="${AUDIT_DIR}/audit_${safe}_$(timestamp).log"
  LOGPATH["$model"]="$logf"

  blue "Running aider with model: $model"
  # We let aider analyze the repo in CWD. You can add files or extra flags via EXTRA_ARGS.
  # Common helpful flags you might want in EXTRA_ARGS:
  #   --no-git, --yes, --read-only, --map-tokens 4000
  # By default we give it the prompt and exit.
  set +e
  aider --model "$model" --message "$(cat "$PROMPT_FILE")" ${=EXTRA_ARGS:-} | tee "$logf"
  rc=$?
  set -e
  if (( rc != 0 )); then
    warn "aider exited with code $rc for model $model"
  fi

  # Try to pull a "score out of 10" from output. We search a few patterns.
  score=""
  # Look for e.g., "score: 7/10" or "7 / 10" or "risk score ... 7 out of 10"
  score=$(grep -Eio '([0-9]+)[[:space:]]*/[[:space:]]*10' "$logf" | awk -F'/' '{print $1}' | tail -n1)
  if [[ -z "$score" ]]; then
    score=$(grep -Eio '([0-9]+)[[:space:]]+out of[[:space:]]+10' "$logf" | awk '{print $1}' | tail -n1)
  fi
  if [[ -z "$score" ]]; then
    score=$(grep -Eio 'risk score[^0-9]*([0-9]+)' "$logf" | awk '{print $NF}' | tail -n1)
  fi
  if [[ -n "$score" ]]; then
    SCORES["$model"]="$score"
  else
    SCORES["$model"]="—"
  fi
done

# --- summary table ---
print
blue "Summary (higher = safer)"
print -P "%B%-28s  %-6s  %s%b" "Model" "Score" "Log"
print -P "%B%-28s  %-6s  %s%b" "----------------------------" "------" "---------------------------"
for model in "${MODELS[@]}"; do
  safe="$(print -- "$model" | tr '/:' '__')"
  printf "%-28s  %-6s  %s\n" "$model" "${SCORES[$model]}" "${LOGPATH[$model]##$PWD/}"
done

# --- optional: overall ranking ---
print
blue "Ranking by score:"
# Print only those with numeric scores
{
  for model in "${MODELS[@]}"; do
    s="${SCORES[$model]}"
    [[ "$s" == "—" ]] && continue
    printf "%s\t%s\n" "$s" "$model"
  done
} | sort -nr | awk '{printf "  #%d  %s  (score %s/10)\n", NR, $2, $1}'

blue "Done. Full logs are in: ${AUDIT_DIR}"
