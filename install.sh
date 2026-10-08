#!/usr/bin/env bash
# SLP cho Claude Code Agent Teams — installer (layout alp-paseo).
#
# One-line (project-level, chạy tại repo root):
#   curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash
# Global (~/.alp + ~/.claude):
#   curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash -s -- --global
# Pin version:
#   curl -fsSL .../install.sh | SLP_REF=v0.1.0 bash
#
# Script này chỉ tải bundle rồi giao cho adapters/claude/alp.py (cần python3). Cài gì:
#   <root>/ALP.md                               (contract của repo — tạo từ templates/ALP.md nếu chưa có)
#   <root>/CLAUDE.md                            (tạo nếu chưa có: một dòng `@ALP.md`)
#   <root>/.alp/settings.json                   (defaultAgent, workflow.mode, workflow.maxPeers)
#   <root>/.alp/WORKFLOW.md                     (luồng phase, ghế, bảng cấm)
#   <root>/.alp/agents/<ghế>/{AGENT.md, skills/, hooks/, .mcp.json}
#                                               (main, lead, peer, supervisor, oracle, reviewer; skill theo templates/role-skills.json)
#   <root>/.claude/agents/<ghế>.md, .claude/skills/<skill>/   (SINH từ .alp/ — sửa ở .alp/, đừng sửa ở đây)
#   <root>/.claude/settings.json                (merge: env Agent Teams, teammateMode, agent=main, hook dispatcher → .claude/slp/alp.py)
#   <root>/.claude/slp/alp.py                   (adapter: sync .alp → .claude, chặn skill ngoài bộ của ghế, chạy .alp/agents/<ghế>/hooks/)
#   <root>/.claude/slp-supervisor.settings.json, slp-mail/slp_mail.py, slp-mail.settings.json
#   <root>/.claude/slp-manifest.json            (ghi lại đúng những gì đã cài, để uninstall gỡ chính xác)
# File .alp/ đã sửa được giữ khi cài lại (bản mới để ở .claude/backups/); --force để ghi đè (có backup).
# Nâng cấp từ layout cũ (.claude/agents/*.md cài thẳng): bản cũ backup vào .claude/backups/slp-<ts>/.
set -euo pipefail

SLP_REPO="${SLP_REPO:-phucanh08/alp-claude}"
SLP_REF="${SLP_REF:-main}"
export SLP_REF
ARGS=()
GLOBAL=0

usage() {
  cat <<'USAGE'
Usage: install.sh [--global] [--dir <path>] [--force]
  --global      cài vào ~/.alp + ~/.claude (agents dùng chung mọi repo, không tạo ALP.md/CLAUDE.md)
  --dir <path>  repo root cần cài (mặc định: thư mục hiện tại)
  --force       ghi đè file .alp/ đã sửa (backup vào .claude/backups/)
Env: SLP_REPO (mặc định phucanh08/alp-claude), SLP_REF (branch/tag, mặc định main)
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --global) GLOBAL=1; ARGS+=(--global) ;;
    --dir) ARGS+=(--dir "${2:-}"); shift ;;
    --force) ARGS+=(--force) ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: tham số lạ: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

log() { printf '  %s\n' "$*"; }
die() { printf '\033[31m✘\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
have python3 || die "cần python3 (adapter + hook của SLP chạy bằng python3)"

# ---- resolve source: local clone hay tarball ---------------------------------
SRC=""
TMP=""
cleanup() { [ -z "$TMP" ] || rm -rf "$TMP"; }
trap cleanup EXIT

script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$script_dir" ] && [ -f "$script_dir/adapters/claude/alp.py" ] && [ -f "$script_dir/templates/role-skills.json" ]; then
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
[ -f "$SRC/adapters/claude/alp.py" ] || die "bundle thiếu adapters/claude/alp.py"

python3 "$SRC/adapters/claude/alp.py" install --src "$SRC" "${ARGS[@]+"${ARGS[@]}"}"

cat <<EOF

Xong. Bước tiếp theo:
  1. $( [ "$GLOBAL" -eq 0 ] && echo "Điền ALP.md (contract boundary, lệnh test, path cấm sửa, external side-effect policy). CLAUDE.md chỉ import nó." || echo "Mỗi repo vẫn cần ALP.md + CLAUDE.md (@ALP.md) riêng — template: templates/ALP.md" )
  2. Smart (mặc định): mở 'claude' như thường — session chạy ghế main (.claude/settings.json → agent: main).
     Supervised: cd <repo root> && claude --agent lead --name lead      # workspace nhiều repo: --name lead-<repo>
  3. (tuỳ chọn) Supervisor — thư mục trung lập, đọc mọi file, sandbox chặn ghi:
       mkdir -p ~/slp-supervisor && cd ~/slp-supervisor
       claude --agent supervisor --name supervisor --settings <root>/.claude/slp-supervisor.settings.json   # docs/SETUP.md §10
  4. Tuỳ biến ghế ở .alp/agents/<ghế>/ (AGENT.md, skills/, hooks/<Event>.sh|.py, .mcp.json); hook SessionStart tự sinh lại .claude/.
     Quy trình: .alp/WORKFLOW.md. Lab: docs/labs/README.md.

Gỡ: curl -fsSL https://raw.githubusercontent.com/${SLP_REPO}/${SLP_REF}/uninstall.sh | bash$( [ "$GLOBAL" -eq 1 ] && echo " -s -- --global" )
EOF
