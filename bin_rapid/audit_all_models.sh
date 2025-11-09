#!/usr/bin/env bash
set -euo pipefail

# Location of the bootstrap that defines MODEL_CATALOG
RAPID_DIR="${RAPID_DIR:-$HOME/bin/rapid}"
BOOTSTRAP_AI="$RAPID_DIR/bootstrap_ai.sh"

# Aider & Ollama checks
need_cmd() { command -v "$1" >/dev/null 2>&1; }
die() { echo "[!] $*" >&2; exit 1; }

need_cmd grep || die "grep required"
need_cmd awk  || die "awk required"
need_cmd sed  || die "sed required"
need_cmd tr   || die "tr required"
need_cmd date || die "date required"
need_cmd mkdir || die "mkdir required"
need_cmd aider || die "aider is required on PATH"
need_cmd ollama || echo "[i] Warning: ollama not on PATH. If Aider uses Ollama, ensure OLLAMA_API_BASE is set."

[[ -f "$BOOTSTRAP_AI" ]] || die "Cannot find $BOOTSTRAP_AI"

# ------------------------------------------------------------------------------
# Extract model tags from the associative array MODEL_CATALOG in bootstrap_ai.sh
# Format expected: declare -A MODEL_CATALOG=( ["1"]="tag" ["2"]="tag" ... )
# ------------------------------------------------------------------------------
readarray -t MODEL_TAGS < <(
  awk '
    /declare[[:space:]]+-A[[:space:]]+MODEL_CATALOG[[:space:]]*=\(/ {inarr=1; next}
    inarr && /\)/ {inarr=0}
    inarr {
      # capture ["n"]="value" or [n]="value"
      if (match($0, /\[[^]]+\][[:space:]]*=[[:space:]]*\"([^\"]+)\"/, m)) {
        print m[1]
      }
    }
  ' "$BOOTSTRAP_AI" \
  | sed 's/[[:space:]]\+$//' \
  | grep -v '^[[:space:]]*$' \
  || true
)

if [[ ${#MODEL_TAGS[@]} -eq 0 ]]; then
  die "No models found in MODEL_CATALOG within $BOOTSTRAP_AI"
fi

# ------------------------------------------------------------------------------
# Config
# ------------------------------------------------------------------------------
PROMPT=${PROMPT:-"Please review the following code for security vulnerabilities according to OWASP Top 10 and CWE categories. List issues found with severity and recommended fixes, then provide a score out of 10."}

TS="$(date +%Y%m%d-%H%M%S)"
OUTDIR="${OUTDIR:-ai_audit_reports/run-$TS}"
mkdir -p "$OUTDIR"

# Optional: limit runtime per model (seconds) if your shells support `timeout`
TIMEOUT_SECS="${TIMEOUT_SECS:-0}"  # 0 = no timeout

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
run_aider_once() {
  local model_tag="$1"
  local outfile="$2"

  local cmd=(aider --model "ollama:${model_tag}" --message "$PROMPT" --no-stream)
  # You can add flags (e.g., --no-git) if you don’t want Aider to touch the repo.
  # cmd+=(--no-git)

  echo "[*] Running Aider with model: ollama:${model_tag}"
  if [[ "$TIMEOUT_SECS" != "0" ]] && need_cmd timeout; then
    timeout "${TIMEOUT_SECS}"s "${cmd[@]}" >"$outfile" 2>&1 || true
  else
    "${cmd[@]}" >"$outfile" 2>&1 || true
  fi
}

extract_score() {
  # Try to find a "X/10" or "score ... X/10" pattern
  local file="$1"
  local s
  s="$(grep -Eio '(^|[^0-9])([0-9]+(\.[0-9]+)?)[[:space:]]*/[[:space:]]*10([^0-9]|$)' "$file" | head -n1 | grep -Eo '[0-9]+(\.[0-9]+)?')" || true
  if [[ -n "$s" ]]; then echo "$s"; else echo "N/A"; fi
}

extract_issue_count() {
  # Heuristic: count lines that look like enumerated issues or callouts referencing OWASP/CWE.
  local file="$1"
  local n=0
  local bullets cwe owasp
  bullets="$(grep -E '^[[:space:]]*[-*•]|^[0-9]+\.' "$file" | wc -l | tr -d ' ')" || bullets=0
  cwe="$(grep -Eoi 'CWE-?[0-9]+' "$file" | wc -l | tr -d ' ')" || cwe=0
  owasp="$(grep -Eoi 'OWASP|A[0-9]{2}:' "$file" | wc -l | tr -d ' ')" || owasp=0

  # Favor bullet count; if none, fall back to CWE/OWASP sightings
  if [[ "$bullets" -gt 0 ]]; then
    n="$bullets"
  else
    n=$(( cwe + owasp ))
  fi
  echo "$n"
}

# ------------------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------------------
declare -a SUMMARY_ROWS
printf "%s\n" "[*] Models discovered:" "${MODEL_TAGS[@]/#/  - }"

for tag in "${MODEL_TAGS[@]}"; do
  safe_tag="$(echo "$tag" | tr '/:' '__')"
  outfile="$OUTDIR/${safe_tag}.txt"

  run_aider_once "$tag" "$outfile"

  score="$(extract_score "$outfile")"
  issues="$(extract_issue_count "$outfile")"
  SUMMARY_ROWS+=("$tag|$issues|$score|$outfile")
done

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo
echo "================ Security Review Summary ================"
printf "%-30s | %8s | %7s | %s\n" "Model" "Issues" "Score" "Report"
printf -- "---------------------------------------------------------------\n"

# Sort by score desc where possible (N/A go last)
{
  for row in "${SUMMARY_ROWS[@]}"; do
    IFS='|' read -r tag issues score path <<<"$row"
    if [[ "$score" == "N/A" ]]; then
      # put N/A at the end in sorting
      printf "NA\t%s\t%s\t%s\t%s\n" "$tag" "$issues" "$score" "$path"
    else
      # numeric sort key (invert for descending by multiplying by -1 not trivial, use sort -nr later)
      printf "%s\t%s\t%s\t%s\t%s\n" "$score" "$tag" "$issues" "$score" "$path"
    fi
  done
} \
| sort -t$'\t' -k1,1nr -k2,2 \
| awk -F'\t' '{
    if ($1=="NA") {
      printf "%-30s | %8s | %7s | %s\n", $2, $3, $4, $5
    } else {
      printf "%-30s | %8s | %7s | %s\n", $2, $3, $4, $5
    }
  }'

echo
echo "Reports saved in: $OUTDIR"
echo
echo "Tip:"
echo "  - Make sure OLLAMA_API_BASE is set if Ollama isn’t on default port."
echo "  - You can set TIMEOUT_SECS=180 to cap each model run."
