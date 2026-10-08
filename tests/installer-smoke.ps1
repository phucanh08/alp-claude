# Smoke test install.ps1 / uninstall.ps1 (Windows PowerShell 5.1 và pwsh 7).
#   ./tests/installer-smoke.ps1                 # dùng clone hiện tại
#   ./tests/installer-smoke.ps1 -Remote <ref>   # thêm: irm .../install.ps1 | iex với SLP_REF=<ref> (tải bundle từ GitHub)
param([string]$Remote = "")
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Py = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } else { 'python' }
$env:PYTHONIOENCODING = 'utf-8'
Write-Host "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition)), python: $Py"

function Assert($cond, $msg) { if (-not $cond) { throw "FAIL: $msg" } else { Write-Host "  ok  $msg" } }
function New-Repo {
  $d = Join-Path ([System.IO.Path]::GetTempPath()) ("alp-ps-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $d | Out-Null
  git init -q $d | Out-Null
  return (Resolve-Path $d).Path
}
function Invoke-Hook($repo, $json) {
  $env:CLAUDE_PROJECT_DIR = $repo
  $tmp = [System.IO.Path]::GetTempFileName()
  [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding $false))
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $out = cmd /c "$Py `"$repo\.claude\slp\alp.py`" hook PreToolUse < `"$tmp`" 2>&1"; $code = $LASTEXITCODE }
  finally { $ErrorActionPreference = $old; Remove-Item $tmp }
  return @{ Code = $code; Out = ($out -join "`n") }
}
function Test-Installed($repo) {
  foreach ($f in 'ALP.md', 'CLAUDE.md', '.alp\settings.json', '.alp\WORKFLOW.md', '.claude\slp\alp.py', '.claude\slp-manifest.json') {
    Assert (Test-Path (Join-Path $repo $f)) "có $f"
  }
  foreach ($a in 'main', 'lead', 'peer', 'supervisor', 'oracle', 'reviewer') {
    Assert (Test-Path (Join-Path $repo ".alp\agents\$a\AGENT.md")) ".alp/agents/$a/AGENT.md"
    Assert (Test-Path (Join-Path $repo ".claude\agents\$a.md")) ".claude/agents/$a.md"
  }
  Assert ((Get-ChildItem (Join-Path $repo '.claude\skills') -Directory).Count -eq 6) "6 skill trong .claude/skills"
  Assert ((Get-ChildItem (Join-Path $repo '.alp\agents\peer\skills') -Directory).Count -eq 3) "peer có 3 skill"
  $st = Get-Content -Raw (Join-Path $repo '.claude\settings.json') | ConvertFrom-Json
  Assert ($st.agent -eq 'main') "settings agent = main"
  Assert ($null -ne $st.hooks.PreToolUse) "settings có hook PreToolUse"
  $r = Invoke-Hook $repo '{"agent_type":"peer","tool_name":"Skill","tool_input":{"skill":"goal-griller"}}'
  Assert ($r.Code -eq 2) "hook chặn peer gọi goal-griller (exit $($r.Code))"
  Assert ($r.Out -match 'ghế `peer`') "lý do chặn in đúng tiếng Việt: $($r.Out.Substring(0, [Math]::Min(80, $r.Out.Length)))"
  $r = Invoke-Hook $repo '{"agent_type":"peer","tool_name":"Skill","tool_input":{"skill":"xia"}}'
  Assert ($r.Code -eq 0) "hook cho peer gọi xia"
}
function Test-Clean($repo) {
  $left = @(Get-ChildItem -Force $repo | Where-Object { $_.Name -ne '.git' } | ForEach-Object { $_.Name })
  Assert ($left.Count -eq 0) "gỡ sạch (còn: $($left -join ', '))"
}

Write-Host "== local clone: install.ps1 -Dir"
$repo = New-Repo
& (Join-Path $RepoRoot 'install.ps1') -Dir $repo
Test-Installed $repo
Write-Host "== cài lại: giữ file .alp đã sửa"
Add-Content -LiteralPath (Join-Path $repo '.alp\agents\peer\AGENT.md') -Value 'custom-line'
& (Join-Path $RepoRoot 'install.ps1') -Dir $repo
Assert ((Get-Content -Raw (Join-Path $repo '.alp\agents\peer\AGENT.md')) -match 'custom-line') "giữ AGENT.md đã sửa"
Assert ((Get-Content -Raw (Join-Path $repo '.claude\agents\peer.md')) -match 'custom-line') ".claude/agents/peer.md sinh từ bản đã sửa"
Write-Host "== uninstall.ps1 -Dir -Force"
& (Join-Path $RepoRoot 'uninstall.ps1') -Dir $repo -Force
Test-Clean $repo

Write-Host "== cwd mặc định + uninstall không -Force"
$repo2 = New-Repo
Push-Location $repo2
try {
  & (Join-Path $RepoRoot 'install.ps1')
  Test-Installed $repo2
  & (Join-Path $RepoRoot 'uninstall.ps1')
  Test-Clean $repo2
} finally { Pop-Location }

if ($Remote) {
  Write-Host "== remote: irm install.ps1 | iex (SLP_REF=$Remote)"
  $repo3 = New-Repo
  Push-Location $repo3
  try {
    $env:SLP_REF = $Remote
    irm "https://raw.githubusercontent.com/phucanh08/alp-claude/$Remote/install.ps1" | iex
    Test-Installed $repo3
    irm "https://raw.githubusercontent.com/phucanh08/alp-claude/$Remote/uninstall.ps1" | iex
    Test-Clean $repo3
  } finally { Pop-Location; Remove-Item Env:SLP_REF }
}
Write-Host "PASS installer-smoke.ps1"
