#!/usr/bin/env bash
# bootstrap_dev.sh — macOS-friendly developer bootstrap
# - Installs VS Code (Homebrew cask)
# - Ensures `code` CLI
# - Installs VSCodeVim extension
# - Optionally merges Vim-friendly settings via jq
# - Uses same helper style as other bootstrap scripts (no sed -i)

set -euo pipefail

# -------- pretty logging --------
info() { printf "\033[1;34m[DEV]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
die()  { printf "\033[1;31m[✗]\033[0m %s\n" "$*" >&2; exit 1; }

# -------- helpers (macOS-safe) --------
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

is_apple_silicon() {
  [ "$(uname -s)" = "Darwin" ] || return 1
  sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -qi "Apple" && return 0 || return 1
}

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    info "Homebrew present."
    return 0
  fi
  info "Homebrew not found. Install it? (y/N)"
  read -r ans
  if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
    info "Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || die "Homebrew install failed."
    # Add brew to PATH for this session
    if is_apple_silicon; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(/usr/local/bin/brew shellenv 2>/dev/null || true)"
    fi
    ok "Homebrew installed."
  else
    die "Homebrew is required for this script. Aborting."
  fi
}

ensure_code_cli() {
  if command -v code >/dev/null 2>&1; then
    return 0
  fi
  # Try to symlink the code binary that ships inside the app bundle.
  local app_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  if [ -x "$app_bin" ]; then
    local target_bin
    if is_apple_silicon; then
      target_bin="/opt/homebrew/bin/code"
      mkdir -p /opt/homebrew/bin 2>/dev/null || true
    else
      target_bin="/usr/local/bin/code"
      mkdir -p /usr/local/bin 2>/dev/null || true
    fi
    info "Creating symlink for 'code' CLI → $target_bin"
    ln -sf "$app_bin" "$target_bin"
    if command -v code >/dev/null 2>&1; then
      ok "'code' CLI is available."
      return 0
    fi
  fi
  warn "Could not set up 'code' CLI automatically. You can enable it from VS Code: Command Palette → 'Shell Command: Install `code` command in PATH'."
}

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  info "jq not found. Install via Homebrew? (y/N)"
  read -r ans
  if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
    brew install jq || die "Failed to install jq."
    ok "jq installed."
  else
    warn "Skipping jq install; settings merge will be skipped."
    return 1
  fi
}

merge_vscode_settings() {
  # Merge a small vim-friendly block into VS Code settings
  local settings_dir="$HOME/Library/Application Support/Code/User"
  local settings="$settings_dir/settings.json"
  local tmp="$(mktemp -t vscodesettings.XXXXXX || mktemp)"

  mkdir -p "$settings_dir"
  [ -f "$settings" ] || echo '{}' > "$settings"

  local payload='{
    "editor.cursorBlinking": "solid",
    "editor.cursorSmoothCaretAnimation": true,
    "editor.cursorStyle": "block",
    "editor.minimap.enabled": false,
    "editor.renderWhitespace": "boundary",
    "editor.smoothScrolling": true,
    "files.trimTrailingWhitespace": true,
    "search.useIgnoreFiles": true,
    "terminal.integrated.defaultProfile.osx": "zsh",

    "vim.useSystemClipboard": true,
    "vim.hlsearch": true,
    "vim.cursorStylePerMode": true,
    "vim.easymotion": true,
    "vim.sneak": true,
    "vim.smartRelativeLine": true,
    "vim.useCtrlKeys": true,
    "vim.handleKeys": {
      "<C-c>": false
    }
  }'

  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not available; skipping settings merge."
    return 0
  fi

  info "Merging Vim-friendly settings into VS Code settings.json"
  # shellcheck disable=SC2002
  if ! cat "$settings" | jq -s 'add * input' --argjson input "$payload" > "$tmp" 2>/dev/null; then
    # Fallback merge (jq older syntax): . * payload
    if ! cat "$settings" | jq --argjson payload "$payload" '. * $payload' > "$tmp" 2>/dev/null; then
      warn "jq merge failed; leaving settings unchanged."
      rm -f "$tmp"
      return 0
    fi
  fi

  mv "$tmp" "$settings"
  ok "VS Code settings updated."
}

# -------- QoL block in shell rc --------
install_qol_block() {
  local rc
  # Choose a primary rc to upsert (prefer ~/.zshrc if it exists; else ~/.bashrc)
  if [ -f "$HOME/.zshrc" ]; then
    rc="$HOME/.zshrc"
  else
    rc="$HOME/.bashrc"
  fi
  local content='
# macOS-friendly pager/term defaults
export TERM=xterm-256color
export LESS=-R
export PAGER=less
'
  upsert_block "$rc" \
    "# >>> managed: dev-qol-defaults" \
    "# <<< managed: dev-qol-defaults" \
    "$content"
  ok "QoL env block ensured in $rc"
}

# -------- Cursor AI install --------
install_cursor() {
  # If Cursor is already installed, bail out early.
  if [ -d "/Applications/Cursor.app" ]; then
    ok "Cursor already installed."
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found; cannot install Cursor automatically."
    warn "Install Homebrew from https://brew.sh and then run: brew install --cask cursor"
    return 1
  fi

  info "Installing / updating Cursor (Homebrew cask)…"
  # Install or upgrade if present
  brew install --cask cursor >/dev/null 2>&1 || brew upgrade --cask cursor >/dev/null 2>&1 || true
  ok "Cursor installed (or already up to date)."
}

# ---------------- Main ----------------
info "Developer bootstrap starting…"

ensure_brew

info "Installing / updating VS Code (Homebrew cask)…"
brew install --cask visual-studio-code >/dev/null || brew upgrade --cask visual-studio-code >/dev/null || true
ok "VS Code installed."

ensure_code_cli

info "Installing VSCodeVim extension…"
if command -v code >/dev/null 2>&1; then
  code --install-extension vscodevim.vim >/dev/null 2>&1 || true
  ok "VSCodeVim installed (or already present)."
else
  warn "'code' CLI not found; please install it from VS Code and re-run to auto-install extensions."
fi

# Optional: merge settings with jq (ask to install jq if missing)
if command -v jq >/dev/null 2>&1 || ensure_jq; then
  merge_vscode_settings
fi

# Install Cursor AI editor
install_cursor

install_qol_block

ok "Developer bootstrap complete."
