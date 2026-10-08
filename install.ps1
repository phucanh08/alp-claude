# SLP for Claude Code Agent Teams - installer (Windows PowerShell 5.1+ / pwsh 7), alp-paseo layout.
#
# One-line (project-level, run at the repo root):
#   irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1 | iex
# Global (~/.alp + ~/.claude):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1))) -Global
# Pin version:
#   $env:SLP_REF='v0.1.0'; irm .../install.ps1 | iex
#
# Same as install.sh: download the bundle, then hand over to adapters/claude/alp.py (ALP.md, CLAUDE.md
# `@ALP.md`, .alp/{settings.json, WORKFLOW.md, agents/<seat>/...}, .claude/ generated from .alp/,
# settings.json + hook dispatcher, manifest). Needs Python 3; on Windows the hooks call the exact
# interpreter that ran the install (the `python3` there is often the WindowsApps stub).
#
# Keep this file ASCII-only: Windows PowerShell 5.1 reads a BOM-less script as ANSI (Vietnamese bytes
# turn into smart quotes and break parsing), while a BOM breaks `irm | iex`. User-facing text is
# printed by alp.py. Errors use throw (not exit) so `irm | iex` does not close the window.
param(
  [switch]$Global,
  [string]$Dir = "",
  [switch]$Force,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$SlpRepo = if ($env:SLP_REPO) { $env:SLP_REPO } else { 'phucanh08/alp-claude' }
$SlpRef  = if ($env:SLP_REF)  { $env:SLP_REF }  else { 'main' }
$env:SLP_REPO = $SlpRepo
$env:SLP_REF = $SlpRef

if ($Help) {
  @'
Usage: install.ps1 [-Global] [-Dir <path>] [-Force]
  -Global      install into ~/.alp + ~/.claude (agents shared by every repo; no ALP.md/CLAUDE.md)
  -Dir <path>  repo root to install into (default: current directory)
  -Force       overwrite customized .alp/ files (backup in .claude/backups/)
Env: SLP_REPO (default phucanh08/alp-claude), SLP_REF (branch/tag, default main)
'@ | Write-Host
  return
}

function Log($m) { Write-Host "  $m" }
function Die($m) { throw "x $m" }

# Python 3: python3 -> python -> py -3
function Find-Python {
  foreach ($c in @(@('python3'), @('python'), @('py', '-3'))) {
    if (Get-Command $c[0] -ErrorAction SilentlyContinue) {
      $exe = $c[0]; $rest = @($c | Select-Object -Skip 1)
      $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
      try { $v = & $exe @rest -c 'import sys; print(sys.version_info[0])' 2>$null } finally { $ErrorActionPreference = $old }
      if ($LASTEXITCODE -eq 0 -and "$v".Trim() -eq '3') { return ,$c }
    }
  }
  return $null
}

$Tmp = $null
try {
  $Py = Find-Python
  if (-not $Py) { Die "can Python 3 (python3 / python / py -3) - adapter + hook cua SLP chay bang Python" }

  $scriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $null }
  if ($scriptDir -and (Test-Path (Join-Path $scriptDir 'adapters/claude/alp.py')) -and (Test-Path (Join-Path $scriptDir 'templates/role-skills.json'))) {
    $Src = $scriptDir
    Log "nguon: local clone $Src"
  } else {
    $Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("slp-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $Tmp | Out-Null
    $url = "https://github.com/$SlpRepo/archive/$SlpRef.zip"
    Log "tai $url"
    $zip = Join-Path $Tmp 'bundle.zip'
    try {
      $pp = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
      Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
      Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $Tmp 'x') -Force
      $ProgressPreference = $pp
    } catch { Die "khong tai/giai nen duoc $url (repo/ref dung chua?) - $($_.Exception.Message)" }
    $Src = @(Get-ChildItem -LiteralPath (Join-Path $Tmp 'x') -Directory)[0].FullName
  }
  $Adapter = Join-Path $Src 'adapters/claude/alp.py'
  if (-not (Test-Path $Adapter)) { Die "bundle thieu adapters/claude/alp.py" }

  $pyArgs = @($Py | Select-Object -Skip 1) + @($Adapter, 'install', '--src', $Src, '--shell', 'ps1')
  if ($Global) { $pyArgs += '--global' } elseif ($Dir) { $pyArgs += @('--dir', $Dir) }
  if ($Force) { $pyArgs += '--force' }
  $env:PYTHONIOENCODING = 'utf-8'
  & $Py[0] @pyArgs
  if ($LASTEXITCODE -ne 0) { Die "alp.py install loi (exit $LASTEXITCODE)" }
} finally {
  if ($Tmp -and (Test-Path $Tmp)) { Remove-Item -Recurse -Force -LiteralPath $Tmp }
}
