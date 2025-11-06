# PowerShell Windows bootstrap
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "[-] Rapid Windows bootstrap starting…"
$RepoSlug = $env:RS_REPO_SLUG ? $env:RS_REPO_SLUG : "youruser/rapid-setup"
$Branch   = $env:RS_BRANCH ? $env:RS_BRANCH : "main"
$Dest     = $env:RS_DEST ? $env:RS_DEST : (Join-Path $HOME "rapid-setup")

function Ensure-Winget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "winget not found. Install App Installer from Microsoft Store."
    exit 1
  }
}

Ensure-Winget
$Packages = @("Git.Git","GVim.GVim","Microsoft.WindowsTerminal")
foreach ($p in $Packages) {
  try { winget install --id $p --accept-source-agreements --accept-package-agreements --silent | Out-Null }
  catch { Write-Warning "Failed to install $p" }
}

if (-not (Test-Path (Join-Path $HOME "_vimrc"))) {
  @"
set number relativenumber
set tabstop=2 shiftwidth=2 expandtab
set mouse=a
syntax on
filetype plugin indent on
"@ | Set-Content (Join-Path $HOME "_vimrc")
}

if (Get-Command git -ErrorAction SilentlyContinue) {
  git clone --depth=1 --branch $Branch "https://github.com/$RepoSlug.git" $Dest
} else {
  $url = "https://codeload.github.com/$RepoSlug/zip/refs/heads/$Branch"
  $zip = "$env:TEMP\repo.zip"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath $Dest -Force
}

Write-Host "[✓] Windows bootstrap finished."
