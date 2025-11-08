# Common helpers for bootstrap_* scripts
set -euo pipefail

need_cmd() { command -v "$1" >/dev/null 2>&1; }
have_sudo() { command -v sudo >/dev/null 2>&1; }
on_macos() { [ "$(uname -s)" = "Darwin" ]; }
on_linux() { [ "$(uname -s)" = "Linux" ]; }

bootstrap_announce() {
  local script="${1:-${BASH_SOURCE[1]:-$0}}"
  echo "[*] Running $(basename "$script") …"
}

# Auto-announce when this file is sourced (can be disabled with RS_NO_ANNOUNCE=1)
if [ "${RS_NO_ANNOUNCE:-0}" != "1" ]; then
  bootstrap_announce "${BASH_SOURCE[1]:-$0}"
fi
