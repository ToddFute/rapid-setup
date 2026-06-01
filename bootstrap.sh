# ----------------------------------------------------------------------
# Clone the repo fresh each time (avoid diverged local branches)
# ----------------------------------------------------------------------
TMP_REPO="/tmp/rapid-setup"
REPO_URL="https://github.com/ToddFute/rapid-setup.git"
BRANCH="main"

echo "[*] Getting your repo: ToddFute/rapid-setup@$BRANCH → $TMP_REPO"

# Always start clean
if [ -d "$TMP_REPO/.git" ]; then
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

if [ -d "$TMP_REPO/bin_rapid" ]; then
  cp -R "$TMP_REPO/bin_rapid/"* "$HOME/bin/rapid/" 2>/dev/null || true
fi

if [ -d "$TMP_REPO/dotfiles" ]; then
  # Dot-prefixed names in $HOME (repo files omit the leading dot)
  for dotname in vimrc gvimrc vimrc.simplerose vimrc.local zshrc; do
    if [ -f "$TMP_REPO/dotfiles/$dotname" ]; then
      cp "$TMP_REPO/dotfiles/$dotname" "$HOME/.$dotname"
    fi
  done
  if [ -f "$TMP_REPO/dotfiles/p10k.zsh" ]; then
    cp "$TMP_REPO/dotfiles/p10k.zsh" "$HOME/.p10k.zsh"
  fi
  if [ -f "$TMP_REPO/dotfiles/aliases" ]; then
    cp "$TMP_REPO/dotfiles/aliases" "$HOME/.aliases"
  fi
  if [ -d "$TMP_REPO/dotfiles/vim" ]; then
    mkdir -p "$HOME/.vim"
    cp -R "$TMP_REPO/dotfiles/vim/." "$HOME/.vim/"
    echo "[✓] Installed ~/.vim from dotfiles/vim"
  fi
fi

# Ensure executables have the right perms
chmod -R +x "$HOME/bin/rapid" 2>/dev/null || true
echo "[✓] Copied repo tools into $HOME/bin/rapid"

# ----------------------------------------------------------------------
# Keep TMP_REPO for inspection
# ----------------------------------------------------------------------
echo "[i] Temporary repo retained at $TMP_REPO (not removed)."
