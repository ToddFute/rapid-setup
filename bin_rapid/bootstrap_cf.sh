#!/usr/bin/env bash
# bootstrap_cf.sh - Set up Cloudflare Tunnel for VNC access on macOS
#
# Steps:
#   1. Open System Settings → Sharing so you can enable Screen Sharing + VNC.
#   2. Run `cloudflared tunnel login`.
#   3. Run `cloudflared tunnel create SYSTEM-NAME-remote`.
#   4. Ensure ~/.cloudflared exists.
#   5. Create ~/.cloudflared/config.yml with a VNC ingress.
#   6. Test `cloudflared tunnel run SYSTEM-NAME-remote` briefly.
#   7. `cloudflared service install`
#   8. `brew services start cloudflared`
#
# The script stops on real errors (set -euo pipefail), except the
# UI automation which is best-effort and falls back to manual steps.

set -euo pipefail

info()  { printf '[i] %s\n' "$*"; }
ok()    { printf '[✓] %s\n' "$*"; }
warn()  { printf '[warn] %s\n' "$*" >&2; }
die()   { printf '❌ %s\n' "$*" >&2; exit 1; }

on_macos() {
  [ "$(uname -s)" = "Darwin" ]
}

ensure_macos() {
  on_macos || die "This script is intended for macOS only."
}

ensure_cloudflared() {
  if ! command -v cloudflared >/dev/null 2>&1; then
    die "cloudflared not found on PATH. Install it (e.g. via Homebrew: 'brew install cloudflared') and re-run."
  fi
  ok "cloudflared found at $(command -v cloudflared)"
}

ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found; will skip 'brew services start cloudflared'."
    return 1
  fi
  ok "Homebrew found at $(command -v brew)"
  return 0
}

get_system_name() {
  # Prefer the macOS LocalHostName (no spaces), fallback to hostname -s.
  local name
  if name="$(scutil --get LocalHostName 2>/dev/null)"; then
    printf '%s\n' "$name"
  else
    hostname -s
  fi
}

open_sharing_pane() {
  info "Opening System Settings → Sharing (so you can enable Screen Sharing + VNC)…"

  # Best-effort AppleScript. If this fails, we just warn and you do it manually.
  if ! osascript <<'EOF' >/dev/null 2>&1
try
  tell application "System Settings"
    activate
    try
      -- macOS Ventura / Sonoma style
      reveal pane id "com.apple.Sharing-Settings.extension"
    on error
      -- Older macOS: fall back to traditional Sharing pane
      reveal anchor "sharing" of pane id "com.apple.preference.sharing"
    end try
  end tell
end try
EOF
  then
    warn "Unable to drive System Settings automatically."
  fi

  cat <<'INSTRUCTIONS'

=== ACTION REQUIRED ===
1. In System Settings, go to:
     General → Sharing (or directly to "Sharing" if already visible).
2. Turn ON "Screen Sharing".
3. Click the ⓘ / "i" or "Details…" / "Computer Settings…" button for Screen Sharing.
4. Enable: "VNC viewers may control screen with password" (or similar).
5. Set a strong VNC password and confirm.

When you are finished setting the VNC password, return to this terminal.

INSTRUCTIONS

  printf "Press Enter here once Screen Sharing is ON and VNC-with-password is enabled… "
  # shellcheck disable=SC2034
  IFS= read -r _
  ok "Continuing with Cloudflare Tunnel setup."
}

dns_safe_name() {
  local n
  n="$(scutil --get LocalHostName 2>/dev/null || true)"
  [ -n "$n" ] || n="$(scutil --get HostName 2>/dev/null || true)"
  [ -n "$n" ] || n="$(hostname -s)"
  printf '%s\n' "$n"
}

cloudflared_login() {
  info "Running 'cloudflared tunnel login' (this will open a browser to authenticate with Cloudflare)…"
  cloudflared tunnel login
  ok "cloudflared login completed."
}

create_tunnel() {
  local tunnel_name="$1"
  info "Creating Cloudflare tunnel: ${tunnel_name}"
  cloudflared tunnel create "$tunnel_name"
  ok "Tunnel '${tunnel_name}' created."
}

ensure_credentials_symlink() {
  local config_dir="$1"
  local tunnel_name="$2"

  mkdir -p "$config_dir"
  # Cloudflared typically writes a UUID.json; we link it to NAME.json so
  # the config file can refer to a stable path.
  local latest_json
  latest_json="$(ls -t "${config_dir}"/*.json 2>/dev/null | head -n 1 || true)"

  if [ -z "$latest_json" ]; then
    die "Could not locate any tunnel credentials JSON in ${config_dir} after 'cloudflared tunnel create'."
  fi

  local cred_file="${config_dir}/${tunnel_name}.json"
  if [ "$latest_json" != "$cred_file" ]; then
    info "Linking ${latest_json} → ${cred_file}"
    ln -sf "$latest_json" "$cred_file"
  fi

  printf '%s\n' "$cred_file"
}

write_config_yml() {
  local config_dir="$1"
  local tunnel_name="$2"
  local cred_file="$3"
  local fqdn="$4"

  local config_file="${config_dir}/config.yml"

  info "Writing Cloudflare config to ${config_file}"

  cat >"$config_file" <<EOF
tunnel: ${tunnel_name}
credentials-file: ${cred_file}

ingress:
  - hostname: ${fqdn}
    service: vnc://localhost:5900
  - service: http_status:404
EOF

  ok "Config written to ${config_file}"
}

test_tunnel_run() {
  local tunnel_name="$1"

  info "Quick test: running 'cloudflared tunnel run ${tunnel_name}' briefly…"
  cloudflared tunnel run "$tunnel_name" &
  local pid=$!

  # Give it a few seconds to start up
  sleep 5

  if ! kill -0 "$pid" 2>/dev/null; then
    die "cloudflared tunnel run '${tunnel_name}' exited prematurely; check your Cloudflare setup."
  fi

  # Stop the test instance
  kill "$pid" 2>/dev/null || true
  ok "Tunnel run test succeeded (process started and stayed alive briefly)."
}

install_service() {
  info "Installing cloudflared as a service (launchd)…"
  cloudflared service install
  ok "cloudflared system service installed."

  if ensure_brew; then
    info "Starting cloudflared via Homebrew services…"
    brew services start cloudflared
    ok "cloudflared started with 'brew services start cloudflared'."
  else
    warn "Skipping 'brew services start cloudflared' because Homebrew is not available."
    warn "You may need to start the service manually."
  fi
}

main() {
  ensure_macos
  ensure_cloudflared

  local system_name
  system_name="$(dns_safe_name)"
  local tunnel_name="${system_name}-remote"
  local config_dir="${HOME}/.cloudflared"

  info "Detected system name: ${system_name}"
  info "Tunnel will be named: ${tunnel_name}"

  # Ask what FQDN to use; provide a sensible default.
  local default_fqdn="${system_name}.your-domain.com"
  printf "Enter the new computer name (short, letters/numbers only): "
  IFS= read -r fqdn
  fqdn="${fqdn:-$default_fqdn}"
  ok "Using hostname: ${fqdn}"

  # Step 1: Guide user to enable Screen Sharing + VNC
  open_sharing_pane

  # Step 2: Cloudflare auth
  cloudflared_login

  # Step 3: Create tunnel
  create_tunnel "$tunnel_name"

  # Step 4/5: Ensure ~/.cloudflared and write config
  mkdir -p "$config_dir"
  local cred_file
  cred_file="$(ensure_credentials_symlink "$config_dir" "$tunnel_name")"

  write_config_yml "$config_dir" "$tunnel_name" "$cred_file" "$fqdn"

  # Step 6: Test tunnel run
  test_tunnel_run "$tunnel_name"

  # Step 7 & 8: Install as a service and start
  install_service

  ok "Cloudflare VNC tunnel bootstrap complete."
  ok "You should now be able to reach this Mac via VNC through Cloudflare at: ${fqdn}"
}

main "$@"
