#!/usr/bin/env bash
# bootstrap_interrogate_hostname.sh
# Ask user for desired system name; update ComputerName, LocalHostName, HostName (macOS).
# Also manages a /etc/hosts block safely & idempotently.

set -euo pipefail

# ------------- utils -------------
info() { printf "\033[1;34m[i]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
die()  { printf "\033[1;31m[✗]\033[0m %s\n" "$*" >&2; exit 1; }

remove_block() {
  local file="$1" begin="$2" end="$3"
  [ -f "$file" ] || return 0
  awk -v begin="$begin" -v end="$end" '
    $0==begin {skip=1; next}
    $0==end   {skip=0; next}
    !skip
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

upsert_block() {
  local file="$1" begin="$2" end="$3" content="$4"
  [ -f "$file" ] || touch "$file"
  remove_block "$file" "$begin" "$end"
  {
    printf "%s\n" "$begin"
    printf "%s\n" "$content"
    printf "%s\n" "$end"
  } | sudo tee -a "$file" >/dev/null
}

sanitize_localhost() {
  # LocalHostName may include only A–Z, a–z, 0–9, and hyphen; no spaces.
  # Convert spaces to '-', strip invalid chars, collapse hyphens.
  local s="$1"
  s="${s// /-}"
  # shellcheck disable=SC2001
  s="$(printf "%s" "$s" | sed -E 's/[^A-Za-z0-9-]+/-/g; s/-+/-/g; s/^-//; s/-$//')"
  printf "%s" "$s"
}

lower() { awk '{print tolower($0)}' <<<"$1"; }

interrogate_and_set_hostname() {
  # Read current
  local current_comp current_host current_local
  current_comp="$(scutil --get ComputerName     2>/dev/null || true)"
  current_host="$(scutil --get HostName         2>/dev/null || true)"
  current_local="$(scutil --get LocalHostName   2>/dev/null || true)"

  # Fallback to `scutil --get ComputerName` if some are empty
  [ -n "$current_comp" ] || current_comp="$(hostname)"
  [ -n "$current_local" ] || current_local="$(sanitize_localhost "$current_comp")"
  [ -n "$current_host" ] || current_host="$(lower "$current_local")"

  info "Current names:"
  printf "  ComputerName   : %s\n" "${current_comp:-<unset>}"
  printf "  LocalHostName  : %s\n" "${current_local:-<unset>}"
  printf "  HostName       : %s\n" "${current_host:-<unset>}"
  printf "\n"

  # Prompt
  local desired
  read -r -p "System name [${current_comp}]: " desired
  desired="${desired:-$current_comp}"

  # If unchanged, exit quietly
  if [ "$desired" = "$current_comp" ]; then
    ok "System name unchanged. Nothing to do."
    return 0
  fi

  # Derive the other names
  local new_comp new_local new_host
  new_comp="$desired"
  new_local="$(sanitize_localhost "$desired")"
  new_host="$(lower "$new_local")"

  info "Proposed names:"
  printf "  ComputerName   : %s\n" "$new_comp"
  printf "  LocalHostName  : %s\n" "$new_local"
  printf "  HostName       : %s\n" "$new_host"
  printf "\n"

  # Confirm
  read -r -p "Apply these changes? (y/N): " confirm
  case "${confirm:-N}" in
    y|Y) ;;
    *) warn "Aborted by user."; return 1 ;;
  esac

  # Need sudo
  info "Requesting sudo to set system names…"
  sudo -v || die "sudo required."

  # Apply
  info "Setting ComputerName…"
  sudo scutil --set ComputerName    "$new_comp"
  info "Setting LocalHostName…"
  sudo scutil --set LocalHostName   "$new_local"
  info "Setting HostName…"
  sudo scutil --set HostName        "$new_host"

  # /etc/hosts managed block
  local begin="# >>> managed: hostname-bootstrap"
  local end="# <<< managed: hostname-bootstrap"
  local hosts_line="127.0.0.1   ${new_host} ${new_local}.local localhost"
  info "Updating /etc/hosts managed block…"
  upsert_block "/etc/hosts" "$begin" "$end" "$hosts_line"

  # Flush caches
  info "Flushing DNS & caches…"
  sudo dscacheutil -flushcache || true
  sudo killall -HUP mDNSResponder 2>/dev/null || true

  ok "Hostname updated."
  printf "You may need to close and reopen terminal sessions for prompts to reflect the new name.\n"
}

# If executed directly, run; if sourced, just define the function.
if [[ "${BASH_SOURCE[0]:-}" == "$0" ]]; then
  interrogate_and_set_hostname
fi
