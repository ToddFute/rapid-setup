# Rapid Setup
Cross-platform bootstrap scripts for quickly configuring new machines.

## Quick Start

### macOS/Linux
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ToddFute/rapid-setup/main/bootstrap.sh)"
```

Or
```
/bin/bash -c "$(curl -fsSL https://tinyurl.com/toddbfute/bootstrap.sh)"
```

### Windows (PowerShell)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://gist.githubusercontent.com/<you>/<id>/raw/bootstrap.ps1 | iex"
```

### Pick and run bootstraps
After `bootstrap.sh`, run the checklist menu to choose which bootstraps to run:

```bash
~/bin/rapid/setup.sh        # menu: ↑/↓ or Tab move, Space toggle, Enter run
~/bin/rapid/setup.sh -y     # skip the menu, run the defaults
~/bin/rapid/setup.sh -n     # dry run: show the plan only
```

The defaults are set up for a new SimpleRose Mac. Bootstraps run in dependency order, and any that fail are listed in a summary at the end. Each `bootstrap_*.sh` sets its order, default and description on its second line:

```bash
# rapid: order=20 default=on desc="Homebrew, gh, MacVim, VS Code, Cursor (also runs vim)"
```

### Vim (after bootstrap)
`bootstrap.sh` installs `dotfiles/vim` into `~/.vim` and dot-prefixed vimrc files. For Pathogen bundles (CtrlP, ag.vim, Gundo) and the `ag` binary, run:

```bash
~/bin/rapid/bootstrap_dev.sh   # MacVim + plugins
# or only plugins:
~/bin/rapid/bootstrap_vim.sh
```

On SimpleRose machines, run `~/bin/rapid/bootstrap_simplerose.sh` to link `~/Notes`, `~/ZoomBG`, and `~/bin/SimpleRose` to Google Drive, install `~/.vimrc.simplerose`, and merge cron entries from `dotfiles/crontab.simplerose` into your user crontab.

### iTerm2 settings
`~/bin/rapid/bootstrap_zsh.sh` installs iTerm2 with Homebrew if `/Applications/iTerm.app` isn't already there, then links `~/iTerm2Settings` to `iCloud Drive/Documents/iTerm2Settings` and sets iTerm2 to load its settings from that folder (macOS only; skipped if the iCloud folder isn't there yet). Restart iTerm2 afterward.

### Terminal profiles
`bootstrap.sh` installs terminal window configs from `dotfiles/setup/` as `~/.setup.<name>`. Use the `lh` alias (from `~/.aliases`) to switch profiles — for example, `lh tl` loads `~/.setup.tl`, sets the terminal title, and restores that profile's command history.

Profiles: `bl`, `br`, `center`, `tl`, `tr`.
