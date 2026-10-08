# SLP cho Claude Code Agent Teams — installer (Windows PowerShell 5.1+ / pwsh 7), layout alp-paseo.
#
# One-line (project-level, chạy tại repo root):
#   irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1 | iex
# Global (~/.alp + ~/.claude):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1))) -Global
# Pin version:
#   $env:SLP_REF='v0.1.0'; irm .../install.ps1 | iex
#
# Cài đúng như install.sh: tải bundle rồi giao cho adapters/claude/alp.py (ALP.md, CLAUDE.md `@ALP.md`,
# .alp/{settings.json, WORKFLOW.md, agents/<ghế>/…}, .claude/ sinh từ .alp/, settings.json + hook dispatcher,
# manifest). Cần Python 3 — hook của SLP gọi `python3`, nên lệnh `python3` phải có trong PATH của Claude Code.
# Lỗi dùng throw (không exit) để không đóng cửa sổ khi chạy qua `irm | iex`.
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
$env:SLP_REF = $SlpRef

if ($Help) {
  @'
Usage: install.ps1 [-Global] [-Dir <path>] [-Force]
  -Global      cài vào ~/.alp + ~/.claude (agents dùng chung mọi repo, không tạo ALP.md/CLAUDE.md)
  -Dir <path>  repo root cần cài (mặc định: thư mục hiện tại)
  -Force       ghi đè file .alp/ đã sửa (backup vào .claude/backups/)
Env: SLP_REPO (mặc định phucanh08/alp-claude), SLP_REF (branch/tag, mặc định main)
'@ | Write-Host
  return
}

function Log($m) { Write-Host "  $m" }
function Warn($m) { Write-Host -NoNewline -ForegroundColor Yellow '! '; Write-Host $m }
function Die($m) { throw "✘ $m" }

# Python 3: python3 → python → py -3
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
  if (-not $Py) { Die "cần Python 3 (python3 / python / py -3) — adapter + hook của SLP chạy bằng Python" }
  if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
    Warn "không thấy lệnh 'python3' — hook trong .claude/settings.json gọi python3; tạo alias/shim python3 trước khi mở claude."
  }

  $scriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $null }
  if ($scriptDir -and (Test-Path (Join-Path $scriptDir 'adapters/claude/alp.py')) -and (Test-Path (Join-Path $scriptDir 'templates/role-skills.json'))) {
    $Src = $scriptDir
    Log "nguồn: local clone $Src"
  } else {
    $Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("slp-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $Tmp | Out-Null
    $url = "https://github.com/$SlpRepo/archive/$SlpRef.zip"
    Log "tải $url"
    $zip = Join-Path $Tmp 'bundle.zip'
    try {
      $pp = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
      Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
      Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $Tmp 'x') -Force
      $ProgressPreference = $pp
    } catch { Die "không tải/giải nén được $url (repo/ref đúng chưa?) — $($_.Exception.Message)" }
    $Src = @(Get-ChildItem -LiteralPath (Join-Path $Tmp 'x') -Directory)[0].FullName
  }
  $Adapter = Join-Path $Src 'adapters/claude/alp.py'
  if (-not (Test-Path $Adapter)) { Die "bundle thiếu adapters/claude/alp.py" }

  $pyArgs = @($Py | Select-Object -Skip 1) + @($Adapter, 'install', '--src', $Src)
  if ($Global) { $pyArgs += '--global' } elseif ($Dir) { $pyArgs += @('--dir', $Dir) }
  if ($Force) { $pyArgs += '--force' }
  $env:PYTHONIOENCODING = 'utf-8'
  & $Py[0] @pyArgs
  if ($LASTEXITCODE -ne 0) { Die "alp.py install lỗi (exit $LASTEXITCODE)" }

  $gl = if ($Global) { ' -Global' } else { '' }
  @"

Xong. Bước tiếp theo:
  1. $(if ($Global) { 'Mỗi repo vẫn cần ALP.md + CLAUDE.md (@ALP.md) riêng — template: templates/ALP.md' } else { 'Điền ALP.md (contract boundary, lệnh test, path cấm sửa, external side-effect policy). CLAUDE.md chỉ import nó.' })
  2. Smart (mặc định): mở 'claude' như thường — session chạy ghế main (.claude/settings.json → agent: main).
     Supervised: cd <repo root>; claude --agent lead --name lead      # workspace nhiều repo: --name lead-<repo>
  3. (tuỳ chọn) Supervisor — thư mục trung lập: claude --agent supervisor --name supervisor --settings <root>\.claude\slp-supervisor.settings.json
  4. Tuỳ biến ghế ở .alp/agents/<ghế>/ (AGENT.md, skills/, hooks/<Event>.py|.ps1, .mcp.json); hook SessionStart tự sinh lại .claude/.
     Quy trình: .alp/WORKFLOW.md. Lab: docs/labs/README.md.

Gỡ: & ([scriptblock]::Create((irm https://raw.githubusercontent.com/$SlpRepo/$SlpRef/uninstall.ps1)))$gl
"@ | Write-Host
} finally {
  if ($Tmp -and (Test-Path $Tmp)) { Remove-Item -Recurse -Force -LiteralPath $Tmp }
}
