#!/usr/bin/env bash
# SLP cho Claude Code Agent Teams — installer.
#
# One-line (project-level, chạy tại repo root):
#   curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash
# Global (~/.claude):
#   curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash -s -- --global
# Pin version:
#   curl -fsSL .../install.sh | SLP_REF=v0.1.0 bash
#
# Cài gì:
#   <root>/.claude/agents/lead.md, peer.md, supervisor.md   (copy)
#   <root>/.claude/skills/<name>/                (copy: ask-alp, goal-griller, xia, sequence-execution-plan, prompt-leverage, smart-commits, bug-loop)
#   <root>/.claude/settings.json                (merge: env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS, teammateMode)
#   <root>/.claude/slp-supervisor.settings.json (copy: Read mọi file + sandbox Bash; dùng qua --settings)
#   <root>/CLAUDE.md                            (chỉ tạo từ template nếu chưa có; project mode)
#   <root>/.claude/slp-manifest.json            (ghi lại đúng những gì đã cài, để uninstall gỡ chính xác)
set -euo pipefail

SLP_REPO="${SLP_REPO:-phucanh08/alp-claude}"
SLP_REF="${SLP_REF:-main}"
MODE="project"
TARGET=""
FORCE=0
SKILLS="ask-alp goal-griller xia sequence-execution-plan prompt-leverage smart-commits bug-loop"

usage() {
  cat <<'EOF'
Usage: install.sh [--global] [--dir <path>] [--force]
  --global      cài vào ~/.claude (agents dùng chung mọi repo, không tạo CLAUDE.md)
  --dir <path>  repo root cần cài (mặc định: thư mục hiện tại)
  --force       ghi đè agent file / skill dir đã có mà không backup
Env: SLP_REPO (mặc định phucanh08/alp-claude), SLP_REF (branch/tag, mặc định main)
     SLP_REF=beta → dòng SLP trên Paseo (VERSION x.y.z-beta.N): cài cùng agents/skills, nhưng chạy ghế bằng
     Paseo + plugin slp-paseo thay cho `claude --agent`; bước tiếp theo in ra cuối là bước Paseo (docs/PASEO.md)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --global) MODE="global" ;;
    --dir) TARGET="${2:-}"; shift ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: tham số lạ: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

log()  { printf '  %s\n' "$*"; }
ok()   { printf '\033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m✘\033[0m %s\n' "$*" >&2; exit 1; }

# ---- JSON helper: python3 ưu tiên, fallback node -----------------------------
have() { command -v "$1" >/dev/null 2>&1; }
if have python3; then JSON_RT="python3"; elif have node; then JSON_RT="node"; else
  die "cần python3 hoặc node để merge settings.json"
fi

# merge_settings <file>  → in ra danh sách key đã thêm (mỗi dòng một key), tạo file nếu chưa có
merge_settings() {
  local f="$1"
  if [ "$JSON_RT" = "python3" ]; then
    python3 - "$f" <<'PY'
import json, os, sys
p = sys.argv[1]
created = not os.path.exists(p)
data = {}
if not created:
    with open(p, encoding="utf-8") as fh:
        raw = fh.read().strip()
    data = json.loads(raw) if raw else {}
    if not isinstance(data, dict):
        sys.exit("settings.json không phải object JSON")
added = []
env = data.setdefault("env", {})
if not isinstance(env, dict):
    sys.exit("settings.json: 'env' không phải object")
if "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" not in env:
    env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
    added.append("env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS")
if "teammateMode" not in data:
    data["teammateMode"] = "in-process"
    added.append("teammateMode")
if created:
    added.append("__file__")
os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
with open(p, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
print("\n".join(added))
PY
  else
    node - "$f" <<'JS'
const fs = require("fs"), path = require("path");
const p = process.argv[2];
const created = !fs.existsSync(p);
let data = {};
if (!created) { const raw = fs.readFileSync(p, "utf8").trim(); data = raw ? JSON.parse(raw) : {}; }
if (typeof data !== "object" || Array.isArray(data)) { console.error("settings.json không phải object JSON"); process.exit(1); }
const added = [];
data.env = data.env || {};
if (!("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" in data.env)) { data.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"; added.push("env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"); }
if (!("teammateMode" in data)) { data.teammateMode = "in-process"; added.push("teammateMode"); }
if (created) added.push("__file__");
fs.mkdirSync(path.dirname(p), { recursive: true });
fs.writeFileSync(p, JSON.stringify(data, null, 2) + "\n");
console.log(added.join("\n"));
JS
  fi
}

sha256() {
  if have shasum; then shasum -a 256 "$1" | awk '{print $1}'
  elif have sha256sum; then sha256sum "$1" | awk '{print $1}'
  else echo "unknown"; fi
}

# ---- resolve source: local clone hay tarball ---------------------------------
SRC=""
TMP=""
cleanup() { [ -z "$TMP" ] || rm -rf "$TMP"; }
trap cleanup EXIT

script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$script_dir" ] && [ -f "$script_dir/agents/lead.md" ] && [ -f "$script_dir/agents/peer.md" ] && [ -f "$script_dir/agents/supervisor.md" ]; then
  SRC="$script_dir"
  log "nguồn: local clone $SRC"
else
  have curl || die "cần curl để tải bundle"
  have tar  || die "cần tar để giải nén bundle"
  TMP="$(mktemp -d)"
  url="https://github.com/${SLP_REPO}/archive/${SLP_REF}.tar.gz"
  log "tải $url"
  curl -fsSL "$url" | tar -xz -C "$TMP" --strip-components=1 \
    || die "không tải/giải nén được $url (repo/ref đúng chưa?)"
  SRC="$TMP"
fi
for a in lead peer supervisor; do [ -f "$SRC/agents/$a.md" ] || die "bundle thiếu agents/$a.md"; done
for s in $SKILLS; do [ -f "$SRC/skills/$s/SKILL.md" ] || die "bundle thiếu skills/$s/SKILL.md"; done
[ -f "$SRC/templates/supervisor.settings.json" ] || die "bundle thiếu templates/supervisor.settings.json"
VERSION="$(cat "$SRC/VERSION" 2>/dev/null || echo unknown)"
# Nhánh beta (SLP trên Paseo) bắt buộc VERSION dạng x.y.z-beta.N; bản chính không mang hậu tố này.
case "$SLP_REF" in
  beta|beta/*) case "$VERSION" in
    *-beta.[0-9]*) ;;
    *) die "ref '$SLP_REF' là dòng beta nhưng VERSION='$VERSION' thiếu hậu tố -beta.N" ;;
  esac ;;
esac
case "$VERSION" in *-beta.*) warn "bản BETA $VERSION (ref $SLP_REF) — dòng thử nghiệm SLP trên Paseo, không phải bản chính." ;; esac

# ---- resolve target ------------------------------------------------------------
if [ "$MODE" = "global" ]; then
  ROOT="$HOME"
  CLAUDE_DIR="$HOME/.claude"
else
  ROOT="${TARGET:-$PWD}"
  ROOT="$(cd "$ROOT" && pwd)" || die "không vào được $TARGET"
  CLAUDE_DIR="$ROOT/.claude"
  if [ ! -d "$ROOT/.git" ] && ! git -C "$ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
    warn "$ROOT không phải git repo — Lead cần Git để Peer commit/handoff SHA (bình thường nếu đây là gốc workspace chỉ cho Supervisor). Vẫn cài."
  fi
fi
AGENTS_DIR="$CLAUDE_DIR/agents"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS="$CLAUDE_DIR/settings.json"
MANIFEST="$CLAUDE_DIR/slp-manifest.json"
# Backup nằm ngoài agents/ và skills/: thư mục skill backup còn SKILL.md cùng name → runtime nạp thành skill trùng.
BACKUP_DIR="$CLAUDE_DIR/backups/slp-$(date +%Y%m%d%H%M%S)"

printf '\nSLP %s → %s (%s)\n\n' "$VERSION" "$CLAUDE_DIR" "$MODE"

if [ -f "$MANIFEST" ]; then
  warn "đã có $MANIFEST — đang cài đè lên bản cũ (uninstall trước nếu muốn sạch)."
fi

# ---- 1. agents ------------------------------------------------------------------
mkdir -p "$AGENTS_DIR"
installed_agents=()
for name in lead peer supervisor; do
  dst="$AGENTS_DIR/$name.md"
  if [ -f "$dst" ] && ! cmp -s "$SRC/agents/$name.md" "$dst"; then
    if [ "$FORCE" -eq 1 ]; then
      warn "ghi đè $dst (--force)"
    else
      bak="$BACKUP_DIR/agents/$name.md"
      mkdir -p "$BACKUP_DIR/agents"; cp "$dst" "$bak"
      warn "$dst đã tồn tại và khác bản mới → backup $bak"
    fi
  fi
  cp "$SRC/agents/$name.md" "$dst"
  installed_agents+=("agents/$name.md")
  ok "agents/$name.md"
done

# ---- 1b. skills -----------------------------------------------------------------
# Mỗi skill là một thư mục (SKILL.md + references/ + scripts/). Khác nội dung → backup cả thư mục.
mkdir -p "$SKILLS_DIR"
installed_skills=()
for name in $SKILLS; do
  src="$SRC/skills/$name"; dst="$SKILLS_DIR/$name"
  if [ -d "$dst" ] && ! diff -rq -x __pycache__ "$src" "$dst" >/dev/null 2>&1; then
    if [ "$FORCE" -eq 1 ]; then
      warn "ghi đè $dst (--force)"
    else
      bak="$BACKUP_DIR/skills/$name"
      mkdir -p "$BACKUP_DIR/skills"; cp -R "$dst" "$bak"
      warn "$dst đã tồn tại và khác bản mới → backup $bak"
    fi
  fi
  rm -rf "$dst"
  cp -R "$src" "$dst"
  find "$dst" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
  installed_skills+=("skills/$name")
  ok "skills/$name"
done

# ---- 1c. supervisor settings (dùng qua --settings, không merge vào settings.json) --------
SUP_SETTINGS="$CLAUDE_DIR/slp-supervisor.settings.json"
if [ -f "$SUP_SETTINGS" ] && ! cmp -s "$SRC/templates/supervisor.settings.json" "$SUP_SETTINGS" && [ "$FORCE" -ne 1 ]; then
  bak="$SUP_SETTINGS.bak-$(date +%Y%m%d%H%M%S)"; cp "$SUP_SETTINGS" "$bak"
  warn "$SUP_SETTINGS đã tồn tại và khác bản mới → backup $bak"
fi
cp "$SRC/templates/supervisor.settings.json" "$SUP_SETTINGS"
ok "slp-supervisor.settings.json"

# ---- 2. settings.json -------------------------------------------------------------
added_keys="$(merge_settings "$SETTINGS")"
settings_created=false
settings_keys=()
while IFS= read -r k; do
  [ -z "$k" ] && continue
  if [ "$k" = "__file__" ]; then settings_created=true; else settings_keys+=("$k"); fi
done <<<"$added_keys"
if [ "${#settings_keys[@]}" -gt 0 ]; then
  ok "settings.json: thêm ${settings_keys[*]}"
else
  ok "settings.json: đã có đủ key, không đổi"
fi

# ---- 3. CLAUDE.md (project only) -------------------------------------------------
claude_md_created=false
claude_md_sha=""
if [ "$MODE" = "project" ]; then
  if [ -f "$ROOT/CLAUDE.md" ]; then
    log "CLAUDE.md đã có — giữ nguyên. Kiểm nó có đủ 4 mục: contract boundaries, verification, generated/cấm sửa, external side effects."
  else
    # linked worktree (worktree của writer/Lead monorepo, hoặc Supervisor chạy trong worktree) mà repo chưa commit CLAUDE.md → lấy bản thật từ main worktree
    common="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    main_root=""
    [ -n "$common" ] && [ "$common" != "$ROOT/.git" ] && main_root="$(dirname "$common")"
    if [ -n "$main_root" ] && [ -f "$main_root/CLAUDE.md" ]; then
      cp "$main_root/CLAUDE.md" "$ROOT/CLAUDE.md"
      claude_md_created=true
      claude_md_sha="$(sha256 "$ROOT/CLAUDE.md")"
      ok "CLAUDE.md copy từ main worktree $main_root (linked worktree, file chưa commit)"
    else
      cp "$SRC/templates/CLAUDE.template.md" "$ROOT/CLAUDE.md"
      claude_md_created=true
      claude_md_sha="$(sha256 "$ROOT/CLAUDE.md")"
      ok "CLAUDE.md tạo từ template — ĐIỀN repo-specific contract trước khi chạy Lead"
    fi
  fi
fi

# ---- 4. manifest ------------------------------------------------------------------
{
  printf '{\n'
  printf '  "schemaVersion": 1,\n'
  printf '  "app": "alp-claude-slp",\n'
  printf '  "version": "%s",\n' "$VERSION"
  printf '  "ref": "%s",\n' "$SLP_REF"
  printf '  "mode": "%s",\n' "$MODE"
  printf '  "installedAt": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "agents": ['
  first=1; for a in "${installed_agents[@]}"; do [ $first -eq 1 ] || printf ', '; printf '"%s"' "$a"; first=0; done
  printf '],\n'
  printf '  "skills": ['
  first=1; for k in "${installed_skills[@]}"; do [ $first -eq 1 ] || printf ', '; printf '"%s"' "$k"; first=0; done
  printf '],\n'
  printf '  "files": ["slp-supervisor.settings.json"],\n'
  printf '  "settings": { "created": %s, "keys": [' "$settings_created"
  first=1; for k in "${settings_keys[@]+"${settings_keys[@]}"}"; do [ $first -eq 1 ] || printf ', '; printf '"%s"' "$k"; first=0; done
  printf '] },\n'
  printf '  "claudeMd": { "created": %s, "sha256": "%s" }\n' "$claude_md_created" "$claude_md_sha"
  printf '}\n'
} > "$MANIFEST"
ok "manifest: $MANIFEST"

# ---- 5. validate ------------------------------------------------------------------
if have claude; then
  for d in "$AGENTS_DIR" "$SKILLS_DIR"; do
    if claude plugin validate "$d" >/dev/null 2>&1; then
      ok "claude plugin validate $(basename "$d"): passed"
    else
      warn "claude plugin validate báo lỗi — chạy: claude plugin validate $d"
    fi
  done
else
  warn "không thấy lệnh 'claude' trong PATH — bỏ qua validate"
fi

STEP1="$( [ "$MODE" = "project" ] && echo "Điền CLAUDE.md (contract boundary, lệnh test, path cấm sửa, external side-effect policy)." || echo "Mỗi repo vẫn cần CLAUDE.md riêng — template: $SRC/templates/CLAUDE.template.md" )"
UNINSTALL="curl -fsSL https://raw.githubusercontent.com/${SLP_REPO}/${SLP_REF}/uninstall.sh | bash"
if [ "$MODE" = "global" ]; then UNINSTALL="$UNINSTALL -s -- --global"; fi   # không dùng $( [ ] && ... ): set -e sẽ thoát khi [ ] sai

case "$VERSION" in
*-beta.*)
# Dòng beta: ghế chạy trên Paseo (docs/PASEO.md), không dùng `claude --agent`. Plugin không nằm trong
# bản cài này (chạy trên máy daemon, ngoài sandbox) — clone repo và cài bằng `paseo plugin install`.
PLUGIN_SRC="$( [ -d "$SRC/plugins/slp-paseo" ] && [ "$SRC" != "$TMP" ] && echo "$SRC/plugins/slp-paseo" || echo "" )"
cat <<EOF

Xong. Bản BETA — ghế SLP chạy trên Paseo (>= 0.9.2, Desktop hoặc CLI). Bước tiếp theo (docs/PASEO.md §1–§4):
  1. $STEP1
  2. ~/.paseo/config.json trên máy chạy daemon (giữ key khác), rồi: paseo reload
       "pluginsEnabled": true;  "daemon": { "mcp": { "enabled": true, "injectIntoAgents": true } }
       "agents": { "providers": { "claude-lead" / "claude-peer" / "claude-supervisor" — mẫu §2; ghế Codex: "codex-lead" / "codex-peer" / "codex-supervisor" } }
  3. Plugin slp-paseo (nạp definition + SLP-RUNTIME theo ghế, Lead ↔ Supervisor tự thấy nhau; cần node/npm):
$( if [ -n "$PLUGIN_SRC" ]; then
     echo "       cd $PLUGIN_SRC && npm install && npm test && paseo plugin install \"\$PWD\""
   else
     echo "       git clone -b ${SLP_REF} https://github.com/${SLP_REPO} ~/alp-claude"
     echo "       cd ~/alp-claude/plugins/slp-paseo && npm install && npm test && paseo plugin install \"\$PWD\""
   fi )
       paseo plugin ls    # slp-paseo running; sửa source → paseo plugin reload slp-paseo
  4. Lead: Paseo Desktop → workspace = repo root → New agent → provider "SLP Lead" (hoặc "SLP Lead (Codex)"), tin đầu = đề bài.
       CLI: cd <repo root> && paseo run --provider claude-lead/<model> --mode acceptEdits "<đề bài>"
     Lead tự create_agent peer (provider claude-peer/<model>), duyệt permission của peer bằng respond_to_permission.
  5. (tuỳ chọn) Supervisor — agent thứ ba ở workspace trung lập, không cần id Lead (plugin liệt kê Lead đang sống, Lead mới tự SLP-REGISTER):
       mkdir -p ~/slp-supervisor/.claude/agents ~/slp-supervisor/memory
       cp $SUP_SETTINGS ~/slp-supervisor/.claude/settings.json      # sandbox Bash: chỉ ghi được cwd
$( [ "$MODE" = "project" ] && echo "       cp $CLAUDE_DIR/agents/supervisor.md ~/slp-supervisor/.claude/agents/   # cài --global thì plugin tự lấy ~/.claude/agents/supervisor.md" || echo "       (definition lấy từ ~/.claude/agents/supervisor.md — đã cài --global)" )
       Desktop: workspace ~/slp-supervisor → New agent → provider "SLP Supervisor", tin đầu: "Làm bootstrap theo definition. Chỉ báo DRIFT / ESCALATE / NOTE."
  6. Quy trình theo phase + skill: gõ /ask-alp. Khác gì bản native: docs/PASEO.md §6. Lab Paseo: docs/labs/lab-12-paseo-runtime.md, lab-13-paseo-supervisor.md.

Gỡ: $UNINSTALL   (plugin: paseo plugin remove slp-paseo)
EOF
;;
*)
cat <<EOF

Xong. Bước tiếp theo:
  1. $STEP1
  2. cd <repo root> && claude --agent lead --name lead      # workspace nhiều repo: --name lead-<repo>
  3. (tuỳ chọn) Supervisor — thư mục trung lập không chứa repo, không cần worktree; đọc mọi file, sandbox chặn ghi:
       mkdir -p ~/slp-supervisor && cd ~/slp-supervisor
       claude --agent supervisor --name supervisor --settings $SUP_SETTINGS   # docs/SETUP.md §10
     Workspace nhiều repo: agents cần thấy từ mọi repo → cài --global; CLAUDE.md chung: templates/WORKSPACE.CLAUDE.template.md
  4. Quy trình theo phase + skill: gõ /ask-alp (router; bản dài ở .claude/skills/ask-alp/references/workflow.md). Lab: docs/labs/README.md (mục lục, bắt đầu từ Lab 1).

Gỡ: $UNINSTALL
EOF
;;
esac
