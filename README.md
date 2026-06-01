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

Optional: copy `dotfiles/vimrc.simplerose` to `~/.vimrc.simplerose` on work machines (sourced from `~/.vimrc`).
