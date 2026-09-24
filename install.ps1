# SLP cho Claude Code Agent Teams — installer (Windows PowerShell 5.1+ / pwsh 7).
#
# One-line (project-level, chạy tại repo root):
#   irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1 | iex
# Global (~/.claude):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1))) -Global
# Pin version:
#   $env:SLP_REF='v0.1.0'; irm .../install.ps1 | iex
#
# Cài đúng như install.sh (agents, skills, settings.json merge, slp-supervisor.settings.json,
# CLAUDE.md nếu chưa có, .claude/slp-manifest.json). Không cần python3/node — JSON xử lý bằng PowerShell.
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
$Mode    = if ($Global) { 'global' } else { 'project' }
$Skills  = @('ask-alp','goal-griller','xia','sequence-execution-plan','prompt-leverage','smart-commits','bug-loop')
$Agents  = @('lead','peer','supervisor')

if ($Help) {
  @'
Usage: install.ps1 [-Global] [-Dir <path>] [-Force]
  -Global      cài vào ~/.claude (agents dùng chung mọi repo, không tạo CLAUDE.md)
  -Dir <path>  repo root cần cài (mặc định: thư mục hiện tại)
  -Force       ghi đè agent file / skill dir đã có mà không backup
Env: SLP_REPO (mặc định phucanh08/alp-claude), SLP_REF (branch/tag, mặc định main)
'@ | Write-Host
  return
}

function Log($m)  { Write-Host "  $m" }
function Ok($m)   { Write-Host -NoNewline -ForegroundColor Green '✔ '; Write-Host $m }
function Warn($m) { Write-Host -NoNewline -ForegroundColor Yellow '! '; Write-Host $m }
function Die($m)  { throw "✘ $m" }

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
function Write-Utf8($path, $text) { [System.IO.File]::WriteAllText($path, $text, $Utf8NoBom) }
function Get-Sha256($path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLower() }
function Test-SameFile($a, $b) { (Get-Sha256 $a) -eq (Get-Sha256 $b) }

# So sánh hai thư mục theo danh sách file + hash, bỏ __pycache__ (tương đương diff -rq -x __pycache__)
function Get-DirSig($d) {
  $base = (Resolve-Path -LiteralPath $d).Path
  Get-ChildItem -LiteralPath $base -Recurse -File -Force |
    Where-Object { $_.FullName -notmatch '[\\/]__pycache__[\\/]' } |
    ForEach-Object { $_.FullName.Substring($base.Length).Replace('\','/') + '=' + (Get-Sha256 $_.FullName) } |
    Sort-Object
}
function Test-SameDir($a, $b) { ((Get-DirSig $a) -join "`n") -eq ((Get-DirSig $b) -join "`n") }

function Has-Prop($obj, $name) { $null -ne $obj.PSObject.Properties[$name] }

# Gọi lệnh native, nuốt stderr. PS 5.1 + ErrorActionPreference=Stop biến stderr native thành lỗi → hạ tạm về Continue.
function Invoke-Native([scriptblock]$sb) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { & $sb 2>$null } finally { $ErrorActionPreference = $old }
}

# merge_settings: thêm env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS + teammateMode nếu chưa có; trả về list key đã thêm
function Merge-Settings($p) {
  $created = -not (Test-Path -LiteralPath $p)
  $data = New-Object PSObject
  if (-not $created) {
    $raw = ([System.IO.File]::ReadAllText($p)).Trim()
    if ($raw) { $data = $raw | ConvertFrom-Json }
    if ($data -isnot [System.Management.Automation.PSCustomObject]) { Die "settings.json không phải object JSON" }
  }
  $added = @()
  if (-not (Has-Prop $data 'env')) { $data | Add-Member -NotePropertyName env -NotePropertyValue (New-Object PSObject) }
  if ($data.env -isnot [System.Management.Automation.PSCustomObject]) { Die "settings.json: 'env' không phải object" }
  if (-not (Has-Prop $data.env 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS')) {
    $data.env | Add-Member -NotePropertyName CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS -NotePropertyValue '1'
    $added += 'env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
  }
  if (-not (Has-Prop $data 'teammateMode')) {
    $data | Add-Member -NotePropertyName teammateMode -NotePropertyValue 'in-process'
    $added += 'teammateMode'
  }
  if ($created -or $added.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
    Write-Utf8 $p (($data | ConvertTo-Json -Depth 100) + "`n")
  }
  [pscustomobject]@{ Created = $created; Keys = $added }
}

# ---- resolve source: local clone hay zip ---------------------------------------
# PS 5.1 mặc định có thể chưa bật TLS 1.2 → GitHub từ chối
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$Src = $null
$Tmp = $null
try {
  $scriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $null }
  if ($scriptDir -and @($Agents | Where-Object { -not (Test-Path (Join-Path $scriptDir "agents/$_.md")) }).Count -eq 0) {
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
  foreach ($a in $Agents) { if (-not (Test-Path (Join-Path $Src "agents/$a.md"))) { Die "bundle thiếu agents/$a.md" } }
  foreach ($s in $Skills) { if (-not (Test-Path (Join-Path $Src "skills/$s/SKILL.md"))) { Die "bundle thiếu skills/$s/SKILL.md" } }
  if (-not (Test-Path (Join-Path $Src 'templates/supervisor.settings.json'))) { Die "bundle thiếu templates/supervisor.settings.json" }
  $Version = if (Test-Path (Join-Path $Src 'VERSION')) { (Get-Content -Raw (Join-Path $Src 'VERSION')).Trim() } else { 'unknown' }
  # Nhánh beta (SLP trên Paseo) bắt buộc VERSION dạng x.y.z-beta.N; bản chính không mang hậu tố này.
  if ($SlpRef -eq 'beta' -or $SlpRef -like 'beta/*') {
    if ($Version -notmatch '-beta\.\d+') { Die "ref '$SlpRef' là dòng beta nhưng VERSION='$Version' thiếu hậu tố -beta.N" }
  }
  if ($Version -match '-beta\.') { Warn "bản BETA $Version (ref $SlpRef) — dòng thử nghiệm SLP trên Paseo, không phải bản chính." }

  # ---- resolve target ----------------------------------------------------------
  $haveGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
  if ($Mode -eq 'global') {
    $Root = $HOME
    $ClaudeDir = Join-Path $HOME '.claude'
  } else {
    $t = if ($Dir) { $Dir } else { (Get-Location).Path }
    if (-not (Test-Path -LiteralPath $t -PathType Container)) { Die "không vào được $t" }
    $Root = (Resolve-Path -LiteralPath $t).Path
    $ClaudeDir = Join-Path $Root '.claude'
    $isRepo = Test-Path (Join-Path $Root '.git')
    if (-not $isRepo -and $haveGit) { Invoke-Native { git -C $Root rev-parse --show-toplevel } | Out-Null; $isRepo = ($LASTEXITCODE -eq 0) }
    if (-not $isRepo) {
      Warn "$Root không phải git repo — Lead cần Git để Peer commit/handoff SHA (bình thường nếu đây là gốc workspace chỉ cho Supervisor). Vẫn cài."
    }
  }
  $AgentsDir = Join-Path $ClaudeDir 'agents'
  $SkillsDir = Join-Path $ClaudeDir 'skills'
  $Settings  = Join-Path $ClaudeDir 'settings.json'
  $Manifest  = Join-Path $ClaudeDir 'slp-manifest.json'
  # Backup nằm ngoài agents/ và skills/: thư mục skill backup còn SKILL.md cùng name → runtime nạp thành skill trùng.
  $Stamp     = Get-Date -Format 'yyyyMMddHHmmss'
  $BackupDir = Join-Path $ClaudeDir "backups/slp-$Stamp"

  Write-Host "`nSLP $Version → $ClaudeDir ($Mode)`n"
  if (Test-Path -LiteralPath $Manifest) { Warn "đã có $Manifest — đang cài đè lên bản cũ (uninstall trước nếu muốn sạch)." }

  # ---- 1. agents ---------------------------------------------------------------
  New-Item -ItemType Directory -Force -Path $AgentsDir | Out-Null
  $installedAgents = @()
  foreach ($name in $Agents) {
    $from = Join-Path $Src "agents/$name.md"; $dst = Join-Path $AgentsDir "$name.md"
    if ((Test-Path -LiteralPath $dst) -and -not (Test-SameFile $from $dst)) {
      if ($Force) { Warn "ghi đè $dst (-Force)" } else {
        New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir 'agents') | Out-Null
        $bak = Join-Path $BackupDir "agents/$name.md"; Copy-Item -LiteralPath $dst -Destination $bak
        Warn "$dst đã tồn tại và khác bản mới → backup $bak"
      }
    }
    Copy-Item -LiteralPath $from -Destination $dst -Force
    $installedAgents += "agents/$name.md"
    Ok "agents/$name.md"
  }

  # ---- 1b. skills --------------------------------------------------------------
  New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
  $installedSkills = @()
  foreach ($name in $Skills) {
    $from = Join-Path $Src "skills/$name"; $dst = Join-Path $SkillsDir $name
    if ((Test-Path -LiteralPath $dst -PathType Container) -and -not (Test-SameDir $from $dst)) {
      if ($Force) { Warn "ghi đè $dst (-Force)" } else {
        New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir 'skills') | Out-Null
        $bak = Join-Path $BackupDir "skills/$name"; Copy-Item -LiteralPath $dst -Destination $bak -Recurse
        Warn "$dst đã tồn tại và khác bản mới → backup $bak"
      }
    }
    if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
    Copy-Item -LiteralPath $from -Destination $dst -Recurse
    Get-ChildItem -LiteralPath $dst -Recurse -Directory -Filter __pycache__ -Force -ErrorAction SilentlyContinue |
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $installedSkills += "skills/$name"
    Ok "skills/$name"
  }

  # ---- 1c. supervisor settings (dùng qua --settings, không merge vào settings.json) ----
  $supSrc = Join-Path $Src 'templates/supervisor.settings.json'
  $SupSettings = Join-Path $ClaudeDir 'slp-supervisor.settings.json'
  if ((Test-Path -LiteralPath $SupSettings) -and -not (Test-SameFile $supSrc $SupSettings) -and -not $Force) {
    $bak = "$SupSettings.bak-$Stamp"; Copy-Item -LiteralPath $SupSettings -Destination $bak
    Warn "$SupSettings đã tồn tại và khác bản mới → backup $bak"
  }
  Copy-Item -LiteralPath $supSrc -Destination $SupSettings -Force
  Ok "slp-supervisor.settings.json"

  # ---- 2. settings.json --------------------------------------------------------
  $merge = Merge-Settings $Settings
  if ($merge.Keys.Count -gt 0) { Ok "settings.json: thêm $($merge.Keys -join ' ')" } else { Ok "settings.json: đã có đủ key, không đổi" }

  # ---- 3. CLAUDE.md (project only) ---------------------------------------------
  $claudeMdCreated = $false
  $claudeMdSha = ''
  if ($Mode -eq 'project') {
    $claudeMd = Join-Path $Root 'CLAUDE.md'
    if (Test-Path -LiteralPath $claudeMd) {
      Log "CLAUDE.md đã có — giữ nguyên. Kiểm nó có đủ 4 mục: contract boundaries, verification, generated/cấm sửa, external side effects."
    } else {
      # linked worktree mà repo chưa commit CLAUDE.md → lấy bản thật từ main worktree
      $mainRoot = $null
      if ($haveGit) {
        $common = Invoke-Native { git -C $Root rev-parse --path-format=absolute --git-common-dir }
        if ($LASTEXITCODE -eq 0 -and $common) {
          $common = [System.IO.Path]::GetFullPath($common)
          if ($common -ne [System.IO.Path]::GetFullPath((Join-Path $Root '.git'))) { $mainRoot = Split-Path -Parent $common }
        }
      }
      if ($mainRoot -and (Test-Path (Join-Path $mainRoot 'CLAUDE.md'))) {
        Copy-Item -LiteralPath (Join-Path $mainRoot 'CLAUDE.md') -Destination $claudeMd
        Ok "CLAUDE.md copy từ main worktree $mainRoot (linked worktree, file chưa commit)"
      } else {
        Copy-Item -LiteralPath (Join-Path $Src 'templates/CLAUDE.template.md') -Destination $claudeMd
        Ok "CLAUDE.md tạo từ template — ĐIỀN repo-specific contract trước khi chạy Lead"
      }
      $claudeMdCreated = $true
      $claudeMdSha = Get-Sha256 $claudeMd
    }
  }

  # ---- 4. manifest -------------------------------------------------------------
  $m = [ordered]@{
    schemaVersion = 1
    app           = 'alp-claude-slp'
    version       = $Version
    ref           = $SlpRef
    mode          = $Mode
    installedAt   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    agents        = [string[]]$installedAgents
    skills        = [string[]]$installedSkills
    files         = [string[]]@('slp-supervisor.settings.json')
    settings      = [ordered]@{ created = $merge.Created; keys = [string[]]$merge.Keys }
    claudeMd      = [ordered]@{ created = $claudeMdCreated; sha256 = $claudeMdSha }
  }
  Write-Utf8 $Manifest (($m | ConvertTo-Json -Depth 10) + "`n")
  Ok "manifest: $Manifest"

  # ---- 5. validate -------------------------------------------------------------
  if (Get-Command claude -ErrorAction SilentlyContinue) {
    foreach ($d in @($AgentsDir, $SkillsDir)) {
      Invoke-Native { claude plugin validate $d } | Out-Null
      if ($LASTEXITCODE -eq 0) { Ok "claude plugin validate $(Split-Path -Leaf $d): passed" }
      else { Warn "claude plugin validate báo lỗi — chạy: claude plugin validate $d" }
    }
  } else {
    Warn "không thấy lệnh 'claude' trong PATH — bỏ qua validate"
  }

  $step1 = if ($Mode -eq 'project') { "Điền CLAUDE.md (contract boundary, lệnh test, path cấm sửa, external side-effect policy)." }
           else { "Mỗi repo vẫn cần CLAUDE.md riêng — template: templates/CLAUDE.template.md trong repo $SlpRepo" }
  $uninstall = "https://raw.githubusercontent.com/$SlpRepo/$SlpRef/uninstall.ps1"
  $uninstallCmd = if ($Mode -eq 'global') { "& ([scriptblock]::Create((irm $uninstall))) -Global" } else { "irm $uninstall | iex" }
  @"

Xong. Bước tiếp theo:
  1. $step1
  2. cd <repo root>; claude --agent lead --name lead      # workspace nhiều repo: --name lead-<repo>
  3. (tuỳ chọn) Supervisor — thư mục trung lập không chứa repo, không cần worktree; đọc mọi file, sandbox chặn ghi:
       mkdir ~/slp-supervisor -Force; cd ~/slp-supervisor
       claude --agent supervisor --name supervisor --settings $SupSettings   # docs/SETUP.md §10
     Workspace nhiều repo: agents cần thấy từ mọi repo → cài -Global; CLAUDE.md chung: templates/WORKSPACE.CLAUDE.template.md
  4. Quy trình theo phase + skill: gõ /ask-alp (router; bản dài ở .claude/skills/ask-alp/references/workflow.md). Lab: docs/labs/README.md (mục lục, bắt đầu từ Lab 1).

Gỡ: $uninstallCmd
"@ | Write-Host
} finally {
  if ($Tmp -and (Test-Path -LiteralPath $Tmp)) { Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
