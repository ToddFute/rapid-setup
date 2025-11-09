# ----------------------------------------------------------------------
# Clone the repo fresh each time (avoid diverged local branches)
# ----------------------------------------------------------------------
TMP_REPO="/tmp/rapid-setup"
REPO_URL="https://github.com/ToddFute/rapid-setup.git"
BRANCH="main"

echo "[*] Getting your repo: ToddFute/rapid-setup@$BRANCH → $TMP_REPO"

# Always start clean
if [ -d "$TMP_REPO" ]; then
  echo "[i] Removing previous temp clone at $TMP_REPO"
  rm -rf "$TMP_REPO"
fi

echo "[*] Cloning fresh copy..."
if command -v gh >/dev/null 2>&1; then
  gh repo clone ToddFute/rapid-setup "$TMP_REPO" -- --branch "$BRANCH" --depth=1
else
  git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$TMP_REPO"
fi

echo "[✓] Repo ready at $TMP_REPO"

# ----------------------------------------------------------------------
# Sync desired directories from the temp clone into the user's home
# ----------------------------------------------------------------------
echo "[*] Installing dotfiles and rapid scripts from repo..."
mkdir -p "$HOME/bin/rapid"

cp -R "$TMP_REPO/bin_rapid/"* "$HOME/bin/rapid/" 2>/dev/null || true
cp -R "$TMP_REPO/dotfiles/"* "$HOME/" 2>/dev/null || true

# Ensure executables have the right perms
chmod -R +x "$HOME/bin/rapid" 2>/dev/null || true
echo "[✓] Copied repo tools into $HOME/bin/rapid"

# Cleanup temp repo if you don’t want to keep it
rm -rf "$TMP_REPO"
