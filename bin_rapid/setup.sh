#!/usr/bin/env bash
# setup.sh — pick which bootstraps to run from one checklist, then run them in order
#
# Every bootstrap_*.sh declares itself with a header line (line 2 by convention):
#   # rapid: order=20 default=on desc="What it does"
# Scripts are listed and run by ascending order; default=on ones start selected.
# Scripts without a header are still listed, last and unselected.
#
# Usage: setup.sh [-y|--yes] [-n|--dry-run]
#   -y, --yes      skip the menu and run the default selection
#   -n, --dry-run  show what would run, but don't run anything
#
# Keys: Up/Down (or Tab/Shift-Tab, j/k) move · Space toggle · a all · n none
#       Enter run · q quit
#
# Written for macOS's stock bash 3.2 (no associative arrays, no mapfile).
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TTY=/dev/tty

ASSUME_YES=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes)     ASSUME_YES=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help)    sed -n '2,15s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)            fail "Unknown option: $arg (try --help)" ;;
  esac
done

# ----- Discovery -----
# Prints: order<TAB>name<TAB>default<TAB>desc<TAB>path, sorted by order then name.
discover() {
  local f name order def desc
  for f in "$SCRIPT_DIR"/bootstrap_*.sh; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .sh)"
    name="${name#bootstrap_}"
    order="$(sed -n 's/^# rapid:.* order=\([0-9][0-9]*\).*/\1/p' "$f" | head -n 1)"
    def="$(sed -n 's/^# rapid:.* default=\([a-z]*\).*/\1/p' "$f" | head -n 1)"
    desc="$(sed -n 's/^# rapid:.* desc="\([^"]*\)".*/\1/p' "$f" | head -n 1)"
    printf '%s\t%s\t%s\t%s\t%s\n' "${order:-999}" "$name" "${def:-off}" "${desc:--}" "$f"
  done | sort -t "$(printf '\t')" -k1,1n -k2,2
}

NAMES=(); DESCS=(); PATHS=(); SEL=()
while IFS="$(printf '\t')" read -r _order name def desc path; do
  NAMES+=("$name"); DESCS+=("$desc"); PATHS+=("$path")
  if [ "$def" = "on" ]; then SEL+=(1); else SEL+=(0); fi
done < <(discover)
N=${#NAMES[@]}
[ "$N" -gt 0 ] || fail "No bootstrap_*.sh scripts found in $SCRIPT_DIR"

# ----- Checklist menu -----
restore_tty() {
  printf '\033[?25h' >"$TTY" 2>/dev/null || true   # show cursor
  stty echo <"$TTY" 2>/dev/null || true
}

menu() {
  local cur=0 drawn=0 i key rest mark line
  local lines=$((N + 2))

  trap restore_tty EXIT
  trap 'restore_tty; echo; exit 130' INT TERM
  printf '\033[?25l' >"$TTY"   # hide cursor

  while :; do
    [ "$drawn" -eq 1 ] && printf '\033[%dA' "$lines" >"$TTY"
    drawn=1
    {
      printf '\r\033[2K\033[1mSelect bootstraps to run (top to bottom):\033[0m\n'
      for ((i = 0; i < N; i++)); do
        if [ "${SEL[$i]}" -eq 1 ]; then mark="[x]"; else mark="[ ]"; fi
        line="$(printf ' %s %-22s %s' "$mark" "${NAMES[$i]}" "${DESCS[$i]}")"
        if [ "$i" -eq "$cur" ]; then
          printf '\r\033[2K\033[7m>%s\033[0m\n' "$line"
        else
          printf '\r\033[2K %s\n' "$line"
        fi
      done
      printf '\r\033[2K\033[2m  ↑/↓ Tab move · Space toggle · a all · n none · Enter run · q quit\033[0m\n'
    } >"$TTY"

    key=""; rest=""
    IFS= read -rsn1 key <"$TTY" || key="q"
    case "$key" in
      $'\e')
        IFS= read -rsn2 -t 1 rest <"$TTY" || true
        case "$rest" in
          '[A'|'OA'|'[Z') cur=$(( (cur - 1 + N) % N )) ;;   # Up, Shift-Tab
          '[B'|'OB')      cur=$(( (cur + 1) % N )) ;;       # Down
        esac
        ;;
      $'\t'|j) cur=$(( (cur + 1) % N )) ;;
      k)       cur=$(( (cur - 1 + N) % N )) ;;
      ' ')     SEL[$cur]=$(( 1 - SEL[cur] )) ;;
      a)       for ((i = 0; i < N; i++)); do SEL[$i]=1; done ;;
      n)       for ((i = 0; i < N; i++)); do SEL[$i]=0; done ;;
      '')      break ;;   # Enter
      q|Q)     restore_tty; info "Cancelled; nothing was run."; exit 0 ;;
    esac
  done

  restore_tty
  trap - EXIT INT TERM
}

have_tty() { { : <"$TTY"; } 2>/dev/null; }

if [ "$ASSUME_YES" -eq 0 ]; then
  have_tty || fail "No terminal available for the menu; re-run with --yes to use the defaults."
  menu
fi

# ----- Run -----
# bootstrap_dev may install Homebrew mid-run; each script is a new process, so
# put brew on PATH here for the scripts that follow.
load_brew() {
  need_cmd brew && return 0
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [ -x "$b" ]; then
      eval "$("$b" shellenv)"
      return 0
    fi
  done
  return 0
}

PLAN=()
for ((i = 0; i < N; i++)); do
  [ "${SEL[$i]}" -eq 1 ] && PLAN+=("$i")
done

if [ "${#PLAN[@]}" -eq 0 ]; then
  info "Nothing selected; nothing to do."
  exit 0
fi

echo
info "Will run, in order: $(for i in "${PLAN[@]}"; do printf '%s ' "${NAMES[$i]}"; done)"
if [ "$DRY_RUN" -eq 1 ]; then
  for i in "${PLAN[@]}"; do printf '    %s\n' "${PATHS[$i]}"; done
  exit 0
fi

RESULTS=()
FAILED=0
for i in "${PLAN[@]}"; do
  section "bootstrap_${NAMES[$i]}  —  ${DESCS[$i]}"
  load_brew
  start=$SECONDS
  # Bootstraps prompt for input, so give them the terminal even if stdin is piped.
  if have_tty; then
    if bash "${PATHS[$i]}" <"$TTY"; then rc=0; else rc=$?; fi
  else
    if bash "${PATHS[$i]}"; then rc=0; else rc=$?; fi
  fi
  secs=$(( SECONDS - start ))
  if [ "$rc" -eq 0 ]; then
    RESULTS+=("$(printf '[✓] %-22s %4ss' "${NAMES[$i]}" "$secs")")
  else
    RESULTS+=("$(printf '[✗] %-22s %4ss  (exit %s)' "${NAMES[$i]}" "$secs" "$rc")")
    FAILED=$((FAILED + 1))
  fi
done

section "Summary"
for r in "${RESULTS[@]}"; do printf '  %s\n' "$r"; done
echo
if [ "$FAILED" -gt 0 ]; then
  warn "$FAILED of ${#PLAN[@]} bootstrap(s) failed. Fix and re-run setup.sh, selecting just those."
  exit 1
fi
ok "All ${#PLAN[@]} bootstrap(s) succeeded."
info "Open a new terminal (or run 'exec zsh') to pick up shell changes."
