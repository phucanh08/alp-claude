#!/usr/bin/env bash
# SLP cho Claude Code Agent Teams — uninstaller.
#
# One-line (project-level, chạy tại repo root):
#   curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.sh | bash
# Global:
#   curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.sh | bash -s -- --global
#
# Gỡ đúng những gì install.sh đã ghi trong .claude/slp-manifest.json:
#   - agent files đã cài
#   - skill dirs đã cài (.claude/skills/<name>)
#   - key trong settings.json do SLP thêm (không đụng key khác); xóa file nếu SLP tạo và giờ rỗng
#   - CLAUDE.md chỉ khi SLP tạo từ template VÀ chưa ai sửa (sha256 khớp)
set -euo pipefail

MODE="project"
TARGET=""
FORCE=0
SKILLS="ask-alp goal-griller xia sequence-execution-plan prompt-leverage smart-commits bug-loop"

usage() {
  cat <<'EOF'
Usage: uninstall.sh [--global] [--dir <path>] [--force]
  --global      gỡ khỏi ~/.claude
  --dir <path>  repo root (mặc định: thư mục hiện tại)
  --force       không có manifest vẫn gỡ agents/{lead,peer,supervisor}.md + 7 skill dir; xóa CLAUDE.md kể cả đã sửa;
                xóa luôn agent memory (.claude/agent-memory-local/{lead,supervisor}; --global: ~/.claude/agent-memory/supervisor)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --global) MODE="global" ;;
    --dir) TARGET="${2:-}"; shift ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "uninstall.sh: tham số lạ: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

log()  { printf '  %s\n' "$*"; }
ok()   { printf '\033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m✘\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

if have python3; then JSON_RT="python3"; elif have node; then JSON_RT="node"; else
  die "cần python3 hoặc node để đọc manifest / sửa settings.json"
fi

sha256() {
  if have shasum; then shasum -a 256 "$1" | awk '{print $1}'
  elif have sha256sum; then sha256sum "$1" | awk '{print $1}'
  else echo "unknown"; fi
}

# manifest_get <file> <expr> — in giá trị; list → mỗi phần tử một dòng; bool → true/false
manifest_get() {
  local f="$1" q="$2"
  if [ "$JSON_RT" = "python3" ]; then
    python3 - "$f" "$q" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
v = d
for part in sys.argv[2].split("."):
    v = v.get(part) if isinstance(v, dict) else None
if isinstance(v, list): print("\n".join(str(x) for x in v))
elif isinstance(v, bool): print("true" if v else "false")
elif v is None: print("")
else: print(v)
PY
  else
    node - "$f" "$q" <<'JS'
const fs = require("fs");
let v = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
for (const p of process.argv[3].split(".")) v = (v && typeof v === "object") ? v[p] : undefined;
if (Array.isArray(v)) console.log(v.join("\n"));
else if (typeof v === "boolean") console.log(v ? "true" : "false");
else if (v == null) console.log("");
else console.log(String(v));
JS
  fi
}

# unmerge_settings <file> <created:true|false> <key>... — gỡ key; in "deleted" nếu đã xóa file
unmerge_settings() {
  local f="$1"; local created="$2"; shift 2
  if [ "$JSON_RT" = "python3" ]; then
    python3 - "$f" "$created" "$@" <<'PY'
import json, os, sys
p, created, keys = sys.argv[1], sys.argv[2] == "true", sys.argv[3:]
if not os.path.exists(p): print("missing"); sys.exit(0)
raw = open(p, encoding="utf-8").read().strip()
d = json.loads(raw) if raw else {}
for k in keys:
    if k.startswith("env."):
        d.get("env", {}).pop(k[4:], None)
    else:
        d.pop(k, None)
if isinstance(d.get("env"), dict) and not d["env"]:
    d.pop("env")
if created and not d:
    os.remove(p); print("deleted")
else:
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(d, fh, indent=2, ensure_ascii=False); fh.write("\n")
    print("updated")
PY
  else
    node - "$f" "$created" "$@" <<'JS'
const fs = require("fs");
const [p, createdS, ...keys] = process.argv.slice(2);
const created = createdS === "true";
if (!fs.existsSync(p)) { console.log("missing"); process.exit(0); }
const raw = fs.readFileSync(p, "utf8").trim();
const d = raw ? JSON.parse(raw) : {};
for (const k of keys) { if (k.startsWith("env.")) { if (d.env) delete d.env[k.slice(4)]; } else delete d[k]; }
if (d.env && typeof d.env === "object" && Object.keys(d.env).length === 0) delete d.env;
if (created && Object.keys(d).length === 0) { fs.unlinkSync(p); console.log("deleted"); }
else { fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n"); console.log("updated"); }
JS
  fi
}

# ---- resolve target ------------------------------------------------------------
if [ "$MODE" = "global" ]; then
  ROOT="$HOME"; CLAUDE_DIR="$HOME/.claude"
else
  ROOT="${TARGET:-$PWD}"; ROOT="$(cd "$ROOT" && pwd)" || die "không vào được $TARGET"
  CLAUDE_DIR="$ROOT/.claude"
fi
AGENTS_DIR="$CLAUDE_DIR/agents"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS="$CLAUDE_DIR/settings.json"
MANIFEST="$CLAUDE_DIR/slp-manifest.json"

printf '\nSLP uninstall ← %s (%s)\n\n' "$CLAUDE_DIR" "$MODE"

# ---- không có manifest -----------------------------------------------------------
if [ ! -f "$MANIFEST" ]; then
  if [ "$FORCE" -ne 1 ]; then
    warn "không thấy $MANIFEST — không biết SLP đã cài gì ở đây."
    log  "Dùng --force để gỡ agents/{lead,peer,supervisor}.md + skills/{$(echo $SKILLS | tr ' ' ',')} (không đụng settings.json, CLAUDE.md)."
    exit 1
  fi
  for name in lead peer supervisor; do
    if [ -f "$AGENTS_DIR/$name.md" ]; then rm -f "$AGENTS_DIR/$name.md"; ok "xóa agents/$name.md"; fi
  done
  rmdir "$AGENTS_DIR" 2>/dev/null && ok "xóa thư mục agents/ (rỗng)" || true
  for name in $SKILLS; do
    if [ -d "$SKILLS_DIR/$name" ]; then rm -rf "$SKILLS_DIR/$name"; ok "xóa skills/$name"; fi
  done
  rmdir "$SKILLS_DIR" 2>/dev/null && ok "xóa thư mục skills/ (rỗng)" || true
  if [ -f "$CLAUDE_DIR/slp-supervisor.settings.json" ]; then rm -f "$CLAUDE_DIR/slp-supervisor.settings.json"; ok "xóa slp-supervisor.settings.json"; fi
  log "settings.json và CLAUDE.md giữ nguyên (không có manifest để biết SLP đã thêm gì)."
  exit 0
fi

# ---- 1. agents ------------------------------------------------------------------
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  f="$CLAUDE_DIR/$rel"
  if [ -f "$f" ]; then rm -f "$f"; ok "xóa $rel"; else log "$rel đã không còn"; fi
done <<<"$(manifest_get "$MANIFEST" agents)"
rmdir "$AGENTS_DIR" 2>/dev/null && ok "xóa thư mục agents/ (rỗng)" || true

# ---- 1a. file lẻ (manifest ≥ 0.5.0) — chỉ nhận tên đã biết ----------------------------
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  case "$rel" in slp-supervisor.settings.json) ;; *) warn "manifest có path lạ '$rel' → bỏ qua"; continue ;; esac
  f="$CLAUDE_DIR/$rel"
  if [ -f "$f" ]; then rm -f "$f"; ok "xóa $rel"; else log "$rel đã không còn"; fi
done <<<"$(manifest_get "$MANIFEST" files)"

# ---- 1b. skills (manifest ≥ 0.3.0; manifest cũ không có key → bỏ qua) ------------
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  case "$rel" in
    skills/*/*|skills/|skills/..*) warn "manifest có path lạ '$rel' → bỏ qua"; continue ;;
    skills/*) ;;
    *) warn "manifest có path lạ '$rel' → bỏ qua"; continue ;;
  esac
  d="$CLAUDE_DIR/$rel"
  if [ -d "$d" ]; then rm -rf "$d"; ok "xóa $rel"; else log "$rel đã không còn"; fi
done <<<"$(manifest_get "$MANIFEST" skills)"
rmdir "$SKILLS_DIR" 2>/dev/null && ok "xóa thư mục skills/ (rỗng)" || true

# agent memory — dữ liệu của seat, chỉ xóa khi --force
# supervisor ≥ 0.5.0 dùng memory: user (~/.claude/agent-memory/supervisor) → chỉ đụng khi gỡ --global
if [ "$MODE" = "global" ]; then
  m="$HOME/.claude/agent-memory/supervisor"
  if [ -d "$m" ]; then
    if [ "$FORCE" -eq 1 ]; then rm -rf "$m"; ok "xóa agent-memory/supervisor"
    else warn "giữ $m (memory của Supervisor, mọi workspace; --force để xóa)"; fi
  fi
fi
# memory: local (lead; supervisor < 0.5.0)
for name in lead supervisor; do
  m="$CLAUDE_DIR/agent-memory-local/$name"
  [ -d "$m" ] || continue
  if [ "$FORCE" -eq 1 ]; then rm -rf "$m"; ok "xóa agent-memory-local/$name"
  else warn "giữ $m (memory của seat $name; --force để xóa)"; fi
done
rmdir "$CLAUDE_DIR/agent-memory-local" 2>/dev/null || true

# ---- 2. settings.json -------------------------------------------------------------
settings_created="$(manifest_get "$MANIFEST" settings.created)"
keys=()
while IFS= read -r k; do [ -n "$k" ] && keys+=("$k"); done <<<"$(manifest_get "$MANIFEST" settings.keys)"
if [ "${#keys[@]}" -gt 0 ] || [ "$settings_created" = "true" ]; then
  r="$(unmerge_settings "$SETTINGS" "$settings_created" "${keys[@]+"${keys[@]}"}")"
  case "$r" in
    deleted) ok "settings.json: SLP tạo và giờ rỗng → xóa" ;;
    updated) ok "settings.json: gỡ ${keys[*]:-<không có key>}; key khác giữ nguyên" ;;
    missing) log "settings.json đã không còn" ;;
  esac
else
  log "settings.json: SLP không thêm gì → giữ nguyên"
fi

# ---- 3. CLAUDE.md -----------------------------------------------------------------
if [ "$MODE" = "project" ]; then
  created="$(manifest_get "$MANIFEST" claudeMd.created)"
  want="$(manifest_get "$MANIFEST" claudeMd.sha256)"
  if [ "$created" = "true" ] && [ -f "$ROOT/CLAUDE.md" ]; then
    now="$(sha256 "$ROOT/CLAUDE.md")"
    if [ "$now" = "$want" ] || [ "$FORCE" -eq 1 ]; then
      rm -f "$ROOT/CLAUDE.md"; ok "xóa CLAUDE.md ($( [ "$now" = "$want" ] && echo "chưa sửa so với template" || echo "--force" ))"
    else
      warn "CLAUDE.md do SLP tạo nhưng đã được sửa → giữ lại (dùng --force để xóa)"
    fi
  else
    log "CLAUDE.md: không do SLP tạo → giữ nguyên"
  fi
fi

# ---- 4. manifest + dọn thư mục -----------------------------------------------------
rm -f "$MANIFEST"; ok "xóa manifest"
rmdir "$CLAUDE_DIR" 2>/dev/null && ok "xóa .claude/ (rỗng)" || true

echo
echo "Xong. Session 'claude --agent lead' đang chạy (nếu có) vẫn giữ definition cũ tới khi thoát."
