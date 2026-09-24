# SLP cho Claude Code Agent Teams — uninstaller (Windows PowerShell 5.1+ / pwsh 7).
#
# One-line (project-level, chạy tại repo root):
#   irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.ps1 | iex
# Global:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.ps1))) -Global
#
# Gỡ đúng những gì installer đã ghi trong .claude/slp-manifest.json (giống uninstall.sh):
#   - agent files, skill dirs, slp-supervisor.settings.json
#   - key trong settings.json do SLP thêm (không đụng key khác); xóa file nếu SLP tạo và giờ rỗng
#   - CLAUDE.md chỉ khi SLP tạo từ template VÀ chưa ai sửa (sha256 khớp)
param(
  [switch]$Global,
  [string]$Dir = "",
  [switch]$Force,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$Mode   = if ($Global) { 'global' } else { 'project' }
$Skills = @('ask-alp','goal-griller','xia','sequence-execution-plan','prompt-leverage','smart-commits','bug-loop')
$Agents = @('lead','peer','supervisor')

if ($Help) {
  @'
Usage: uninstall.ps1 [-Global] [-Dir <path>] [-Force]
  -Global      gỡ khỏi ~/.claude
  -Dir <path>  repo root (mặc định: thư mục hiện tại)
  -Force       không có manifest vẫn gỡ agents/{lead,peer,supervisor}.md + 7 skill dir; xóa CLAUDE.md kể cả đã sửa;
               xóa luôn agent memory (.claude/agent-memory-local/{lead,supervisor}; -Global: ~/.claude/agent-memory/supervisor)
'@ | Write-Host
  return
}

function Log($m)  { Write-Host "  $m" }
function Ok($m)   { Write-Host -NoNewline -ForegroundColor Green '✔ '; Write-Host $m }
function Warn($m) { Write-Host -NoNewline -ForegroundColor Yellow '! '; Write-Host $m }
function Die($m)  { throw "✘ $m" }

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
function Get-Sha256($path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLower() }
function Remove-IfEmpty($d) {
  if ((Test-Path -LiteralPath $d -PathType Container) -and -not (Get-ChildItem -LiteralPath $d -Force)) {
    Remove-Item -LiteralPath $d -Force; return $true
  }
  return $false
}
# manifest field → mảng string (thiếu key ở manifest cũ → rỗng)
function Get-List($obj, $name) {
  $p = $obj.PSObject.Properties[$name]
  if ($null -eq $p -or $null -eq $p.Value) { return @() }
  return @($p.Value | ForEach-Object { [string]$_ })
}

# ---- resolve target ------------------------------------------------------------
if ($Mode -eq 'global') {
  $Root = $HOME; $ClaudeDir = Join-Path $HOME '.claude'
} else {
  $t = if ($Dir) { $Dir } else { (Get-Location).Path }
  if (-not (Test-Path -LiteralPath $t -PathType Container)) { Die "không vào được $t" }
  $Root = (Resolve-Path -LiteralPath $t).Path; $ClaudeDir = Join-Path $Root '.claude'
}
$AgentsDir = Join-Path $ClaudeDir 'agents'
$SkillsDir = Join-Path $ClaudeDir 'skills'
$Settings  = Join-Path $ClaudeDir 'settings.json'
$Manifest  = Join-Path $ClaudeDir 'slp-manifest.json'

Write-Host "`nSLP uninstall ← $ClaudeDir ($Mode)`n"

# ---- không có manifest -----------------------------------------------------------
if (-not (Test-Path -LiteralPath $Manifest)) {
  if (-not $Force) {
    Warn "không thấy $Manifest — không biết SLP đã cài gì ở đây."
    Log  "Dùng -Force để gỡ agents/{lead,peer,supervisor}.md + skills/{$($Skills -join ',')} (không đụng settings.json, CLAUDE.md)."
    return
  }
  foreach ($name in $Agents) {
    $f = Join-Path $AgentsDir "$name.md"
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force; Ok "xóa agents/$name.md" }
  }
  if (Remove-IfEmpty $AgentsDir) { Ok "xóa thư mục agents/ (rỗng)" }
  foreach ($name in $Skills) {
    $d = Join-Path $SkillsDir $name
    if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force; Ok "xóa skills/$name" }
  }
  if (Remove-IfEmpty $SkillsDir) { Ok "xóa thư mục skills/ (rỗng)" }
  $sup = Join-Path $ClaudeDir 'slp-supervisor.settings.json'
  if (Test-Path -LiteralPath $sup) { Remove-Item -LiteralPath $sup -Force; Ok "xóa slp-supervisor.settings.json" }
  Log "settings.json và CLAUDE.md giữ nguyên (không có manifest để biết SLP đã thêm gì)."
  return
}

$man = [System.IO.File]::ReadAllText($Manifest) | ConvertFrom-Json

# ---- 1. agents ------------------------------------------------------------------
foreach ($rel in (Get-List $man 'agents')) {
  if ($rel -notmatch '^agents/[A-Za-z0-9._-]+\.md$' -or $rel -match '\.\.') { Warn "manifest có path lạ '$rel' → bỏ qua"; continue }
  $f = Join-Path $ClaudeDir $rel
  if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force; Ok "xóa $rel" } else { Log "$rel đã không còn" }
}
if (Remove-IfEmpty $AgentsDir) { Ok "xóa thư mục agents/ (rỗng)" }

# ---- 1a. file lẻ — chỉ nhận tên đã biết ------------------------------------------
foreach ($rel in (Get-List $man 'files')) {
  if ($rel -ne 'slp-supervisor.settings.json') { Warn "manifest có path lạ '$rel' → bỏ qua"; continue }
  $f = Join-Path $ClaudeDir $rel
  if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force; Ok "xóa $rel" } else { Log "$rel đã không còn" }
}

# ---- 1b. skills -----------------------------------------------------------------
foreach ($rel in (Get-List $man 'skills')) {
  if ($rel -notmatch '^skills/[A-Za-z0-9_-][A-Za-z0-9._-]*$' -or $rel -match '\.\.') { Warn "manifest có path lạ '$rel' → bỏ qua"; continue }
  $d = Join-Path $ClaudeDir $rel
  if (Test-Path -LiteralPath $d -PathType Container) { Remove-Item -LiteralPath $d -Recurse -Force; Ok "xóa $rel" } else { Log "$rel đã không còn" }
}
if (Remove-IfEmpty $SkillsDir) { Ok "xóa thư mục skills/ (rỗng)" }

# agent memory — dữ liệu của seat, chỉ xóa khi -Force
if ($Mode -eq 'global') {
  $m = Join-Path $HOME '.claude/agent-memory/supervisor'
  if (Test-Path -LiteralPath $m) {
    if ($Force) { Remove-Item -LiteralPath $m -Recurse -Force; Ok "xóa agent-memory/supervisor" }
    else { Warn "giữ $m (memory của Supervisor, mọi workspace; -Force để xóa)" }
  }
}
foreach ($name in @('lead','supervisor')) {
  $m = Join-Path $ClaudeDir "agent-memory-local/$name"
  if (-not (Test-Path -LiteralPath $m)) { continue }
  if ($Force) { Remove-Item -LiteralPath $m -Recurse -Force; Ok "xóa agent-memory-local/$name" }
  else { Warn "giữ $m (memory của seat $name; -Force để xóa)" }
}
Remove-IfEmpty (Join-Path $ClaudeDir 'agent-memory-local') | Out-Null

# ---- 2. settings.json -------------------------------------------------------------
$settingsCreated = $false
$keys = @()
if ($man.PSObject.Properties['settings']) {
  $settingsCreated = [bool]$man.settings.created
  $keys = @(Get-List $man.settings 'keys')
}
if ($keys.Count -gt 0 -or $settingsCreated) {
  if (-not (Test-Path -LiteralPath $Settings)) {
    Log "settings.json đã không còn"
  } else {
    $raw = ([System.IO.File]::ReadAllText($Settings)).Trim()
    $d = if ($raw) { $raw | ConvertFrom-Json } else { New-Object PSObject }
    foreach ($k in $keys) {
      if ($k.StartsWith('env.')) {
        if ($d.PSObject.Properties['env'] -and $d.env) { $d.env.PSObject.Properties.Remove($k.Substring(4)) }
      } else { $d.PSObject.Properties.Remove($k) }
    }
    if ($d.PSObject.Properties['env'] -and $d.env -is [System.Management.Automation.PSCustomObject] -and @($d.env.PSObject.Properties).Count -eq 0) {
      $d.PSObject.Properties.Remove('env')
    }
    if ($settingsCreated -and @($d.PSObject.Properties).Count -eq 0) {
      Remove-Item -LiteralPath $Settings -Force; Ok "settings.json: SLP tạo và giờ rỗng → xóa"
    } else {
      $json = if (@($d.PSObject.Properties).Count -eq 0) { '{}' } else { $d | ConvertTo-Json -Depth 100 }
      [System.IO.File]::WriteAllText($Settings, $json + "`n", $Utf8NoBom)
      $shown = if ($keys.Count -gt 0) { $keys -join ' ' } else { '<không có key>' }
      Ok "settings.json: gỡ $shown; key khác giữ nguyên"
    }
  }
} else {
  Log "settings.json: SLP không thêm gì → giữ nguyên"
}

# ---- 3. CLAUDE.md -----------------------------------------------------------------
if ($Mode -eq 'project') {
  $claudeMd = Join-Path $Root 'CLAUDE.md'
  $created = $man.PSObject.Properties['claudeMd'] -and [bool]$man.claudeMd.created
  if ($created -and (Test-Path -LiteralPath $claudeMd)) {
    $now = Get-Sha256 $claudeMd
    $same = $now -eq [string]$man.claudeMd.sha256
    if ($same -or $Force) {
      Remove-Item -LiteralPath $claudeMd -Force
      Ok "xóa CLAUDE.md ($(if ($same) { 'chưa sửa so với template' } else { '-Force' }))"
    } else {
      Warn "CLAUDE.md do SLP tạo nhưng đã được sửa → giữ lại (dùng -Force để xóa)"
    }
  } else {
    Log "CLAUDE.md: không do SLP tạo → giữ nguyên"
  }
}

# ---- 4. manifest + dọn thư mục -----------------------------------------------------
Remove-Item -LiteralPath $Manifest -Force; Ok "xóa manifest"
if (Remove-IfEmpty $ClaudeDir) { Ok "xóa .claude/ (rỗng)" }

Write-Host "`nXong. Session 'claude --agent lead' đang chạy (nếu có) vẫn giữ definition cũ tới khi thoát."
