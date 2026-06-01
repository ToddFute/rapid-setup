#!/usr/bin/env bash
# bootstrap_vim.sh — pathogen bundles, Silver Searcher, and ~/.vim-tmp for backups
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap_common.sh"

info() { printf "\033[1;34m[VIM]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }

VIM_BUNDLE="${HOME}/.vim/bundle"

clone_bundle() {
  local name="$1" url="$2"
  local dest="${VIM_BUNDLE}/${name}"

  if [ -d "${dest}/.git" ]; then
    info "Updating ${name}…"
    git -C "$dest" pull --ff-only 2>/dev/null || warn "Could not update ${name}"
    return 0
  fi

  mkdir -p "$VIM_BUNDLE"
  info "Installing ${name}…"
  git clone --depth=1 "$url" "$dest" || warn "Could not clone ${name}"
}

info "Ensuring backup/swap directory ~/.vim-tmp…"
mkdir -p "${HOME}/.vim-tmp"

info "Installing Pathogen bundles…"
clone_bundle "ctrlp.vim" "https://github.com/ctrlpvim/ctrlp.vim.git"
clone_bundle "ag" "https://github.com/rking/ag.vim"
clone_bundle "gundo" "https://github.com/sjl/gundo.vim.git"

if on_macos && command -v brew >/dev/null 2>&1; then
  if command -v ag >/dev/null 2>&1; then
    ok "ag (The Silver Searcher) already on PATH."
  else
    info "Installing The Silver Searcher (ag) via Homebrew…"
    brew install the_silver_searcher 2>/dev/null || brew upgrade the_silver_searcher 2>/dev/null || true
    if command -v ag >/dev/null 2>&1; then
      ok "ag installed at $(command -v ag)."
    else
      warn "ag not found; CtrlP/ag.vim may not search until you install the_silver_searcher."
    fi
  fi
else
  warn "Skipping Homebrew ag install (macOS + brew required for automatic install)."
fi

ok "Vim bootstrap complete."
