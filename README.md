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

### Vim (after bootstrap)
`bootstrap.sh` installs `dotfiles/vim` into `~/.vim` and dot-prefixed vimrc files. For Pathogen bundles (CtrlP, ag.vim, Gundo) and the `ag` binary, run:

```bash
~/bin/rapid/bootstrap_dev.sh   # MacVim + plugins
# or only plugins:
~/bin/rapid/bootstrap_vim.sh
```

On SimpleRose machines, run `~/bin/rapid/bootstrap_simplerose.sh` to link `~/Notes`, `~/ZoomBG`, and `~/bin/SimpleRose` to Google Drive, install `~/.vimrc.simplerose`, and merge cron entries from `dotfiles/crontab.simplerose` into your user crontab.

### Terminal profiles
`bootstrap.sh` installs terminal window configs from `dotfiles/setup/` as `~/.setup.<name>`. Use the `lh` alias (from `~/.aliases`) to switch profiles — for example, `lh tl` loads `~/.setup.tl`, sets the terminal title, and restores that profile's command history.

Profiles: `bl`, `br`, `center`, `tl`, `tr`.
