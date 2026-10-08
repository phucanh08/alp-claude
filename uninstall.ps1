# SLP cho Claude Code Agent Teams — uninstaller (Windows PowerShell 5.1+ / pwsh 7).
#
# One-line (project-level, chạy tại repo root):
#   irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.ps1 | iex
# Global:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.ps1))) -Global
#
# Giống uninstall.sh: giao cho adapter đã cài (.claude/slp/alp.py; không có thì tải bản trên GitHub),
# gỡ đúng những gì .claude/slp-manifest.json ghi (manifest layout cũ cũng đọc được). File .alp/ đã sửa,
# ALP.md/CLAUDE.md đã sửa và agent memory được giữ trừ khi -Force.
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

if ($Help) {
  @'
Usage: uninstall.ps1 [-Global] [-Dir <path>] [-Force]
  -Global      gỡ khỏi ~/.alp + ~/.claude
  -Dir <path>  repo root (mặc định: thư mục hiện tại)
  -Force       không có manifest vẫn gỡ theo tên SLP; xóa .alp/, ALP.md/CLAUDE.md kể cả đã sửa;
               xóa luôn agent memory (.claude/agent-memory-local/{lead,supervisor}; -Global: ~/.claude/agent-memory/supervisor)
'@ | Write-Host
  return
}

function Die($m) { throw "✘ $m" }

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

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("slp-" + [guid]::NewGuid().ToString('N'))
try {
  $Py = Find-Python
  if (-not $Py) { Die "cần Python 3 (python3 / python / py -3)" }
  $Root = if ($Global) { $HOME } elseif ($Dir) { $Dir } else { (Get-Location).Path }
  New-Item -ItemType Directory -Path $Tmp | Out-Null
  $Adapter = Join-Path $Tmp 'alp.py'
  $installed = Join-Path $Root '.claude/slp/alp.py'
  if (Test-Path -LiteralPath $installed) {
    Copy-Item -LiteralPath $installed -Destination $Adapter   # chạy bản copy: uninstall xóa chính file đã cài
  } else {
    $url = "https://raw.githubusercontent.com/$SlpRepo/$SlpRef/adapters/claude/alp.py"
    try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $Adapter } catch { Die "không tải được $url — $($_.Exception.Message)" }
  }
  $pyArgs = @($Py | Select-Object -Skip 1) + @($Adapter, 'uninstall')
  if ($Global) { $pyArgs += '--global' } elseif ($Dir) { $pyArgs += @('--dir', $Dir) }
  if ($Force) { $pyArgs += '--force' }
  $env:PYTHONIOENCODING = 'utf-8'
  & $Py[0] @pyArgs
  if ($LASTEXITCODE -ne 0) { Die "alp.py uninstall lỗi (exit $LASTEXITCODE)" }
} finally {
  if (Test-Path $Tmp) { Remove-Item -Recurse -Force -LiteralPath $Tmp }
}
