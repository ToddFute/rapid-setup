#!/usr/bin/env bash
# bootstrap_rapid.sh — install rapid-setup repo and link bin_rapid for local maintenance
#
# Expects a fresh clone at /tmp/rapid (or /tmp/rapid-setup from bootstrap.sh).
# Moves it to ~/githome/github/rapid-setup and symlinks bin_rapid -> ~/bin/rapid.
#
# WARNING: ~/bin/rapid must not be a regular directory when you run this.
# Back up or relocate any local files there first — they will block the symlink step.
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

REPO_HOME="$HOME/githome/github/rapid-setup"
BIN_RAPID_LINK="$HOME/bin/rapid"
BIN_RAPID_TARGET="$REPO_HOME/bin_rapid"

find_temp_clone() {
  local candidate
  for candidate in /tmp/rapid /tmp/rapid-setup; do
    if [ -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

ensure_symlink() {
  local link="$1" target="$2"

  mkdir -p "$(dirname "$link")"

  if [ -L "$link" ]; then
    local current
    current="$(readlink "$link")"
    if [ "$current" = "$target" ]; then
      ok "Symlink already correct: $link -> $target"
      return 0
    fi
    warn "Replacing existing symlink ($link -> $current)"
    rm "$link"
  elif [ -e "$link" ]; then
    fail "$link exists but is not a symlink. Back it up or remove it, then re-run."
  fi

  if [ ! -d "$target" ]; then
    fail "Symlink target not found: $target"
  fi

  ln -s "$target" "$link"
  ok "Created symlink: $link -> $target"
}

section "Rapid setup bootstrap"

if [ -e "$BIN_RAPID_LINK" ] && [ ! -L "$BIN_RAPID_LINK" ]; then
  fail "$BIN_RAPID_LINK is a regular directory. Copy or move your local changes elsewhere before running this script."
fi

if [ -e "$REPO_HOME" ]; then
  fail "$REPO_HOME already exists. Remove or rename it before moving the temp clone."
fi

TMP_REPO="$(find_temp_clone)" || fail "No temp clone found at /tmp/rapid or /tmp/rapid-setup. Run bootstrap.sh first."

section "Moving temp clone to $REPO_HOME"
mkdir -p "$(dirname "$REPO_HOME")"
mv "$TMP_REPO" "$REPO_HOME"
ok "Repo installed at $REPO_HOME"

if [ ! -d "$BIN_RAPID_TARGET" ]; then
  fail "Expected bin_rapid directory missing at $BIN_RAPID_TARGET"
fi

section "Linking ~/bin/rapid to repo bin_rapid"
ensure_symlink "$BIN_RAPID_LINK" "$BIN_RAPID_TARGET"

ok "Rapid setup bootstrap complete."
info "Edit scripts in $REPO_HOME/bin_rapid and commit from $REPO_HOME."
