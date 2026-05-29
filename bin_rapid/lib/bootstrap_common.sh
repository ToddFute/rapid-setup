#!/usr/bin/env bash
# Common helpers for Rapid Setup task bootstraps
# This file is sourced by scripts like bootstrap_ai.sh, bootstrap_appsec.sh, etc.
# shellcheck shell=bash

set -euo pipefail

# ----- Pretty printers -----
say() {
  # Usage: say "[*]" "message"
  local prefix="$1"; shift
  local msg="$*"
  printf '%b %s\n' "$prefix" "$msg"
}

ok()    { say "[✓]" "$*"; }
info()  { say "[i]" "$*"; }
warn()  { say "[!]" "$*"; }
fail()  { say "[✗]" "$*" >&2; exit 1; }

# ----- Platform helpers -----
on_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
on_linux() { [[ "$(uname -s)" == "Linux" ]]; }

# ----- Command checks -----
need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  if ! need_cmd "$1"; then
    fail "Required command '$1' not found."
  fi
}

# ----- Sudo helpers -----
ensure_sudo() {
  if command -v sudo >/dev/null 2>&1; then
    sudo -v || warn "Sudo may prompt later if needed."
  else
    warn "No sudo available — continuing as current user."
  fi
}

# ----- OS-safe package install wrappers -----
install_brew_pkg() {
  local pkg="$1"
  if need_cmd brew; then
    brew list --versions "$pkg" >/dev/null 2>&1 || brew install "$pkg" || true
  else
    warn "Homebrew not found — skipping $pkg"
  fi
}

install_apt_pkg() {
  local pkg="$1"
  if need_cmd apt; then
    sudo apt update -y && sudo apt install -y "$pkg" || true
  else
    warn "apt not found — skipping $pkg"
  fi
}

install_dnf_pkg() {
  local pkg="$1"
  if need_cmd dnf; then
    sudo dnf install -y "$pkg" || true
  else
    warn "dnf not found — skipping $pkg"
  fi
}

# ----- Logging wrappers for section starts -----
section() {
  local msg="$*"
  echo
  echo "──────────────────────────────────────────────"
  echo "[*] $msg"
  echo "──────────────────────────────────────────────"
}

# ----- Environment utilities -----
is_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }

# ----- Managed config blocks (macOS-safe; no sed -i) -----
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
  } >> "$file"
}

remove_block_sudo() {
  local file="$1" begin="$2" end="$3"
  [ -f "$file" ] || return 0
  awk -v begin="$begin" -v end="$end" '
    $0==begin {skip=1; next}
    $0==end   {skip=0; next}
    !skip
  ' "$file" | sudo tee "${file}.tmp" >/dev/null && sudo mv "${file}.tmp" "$file"
}

upsert_block_sudo() {
  local file="$1" begin="$2" end="$3" content="$4"
  [ -f "$file" ] || sudo touch "$file"
  remove_block_sudo "$file" "$begin" "$end"
  {
    printf "%s\n" "$begin"
    printf "%s\n" "$content"
    printf "%s\n" "$end"
  } | sudo tee -a "$file" >/dev/null
}

# ----- End of bootstrap_common.sh -----
