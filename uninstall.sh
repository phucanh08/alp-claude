#!/usr/bin/env bash
# SLP cho Claude Code Agent Teams — uninstaller.
#
# One-line (project-level, chạy tại repo root):
#   curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.sh | bash
# Global:
#   curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.sh | bash -s -- --global
#
# Giao cho adapter đã cài (.claude/slp/alp.py; không có thì tải bản trên GitHub). Gỡ đúng những gì
# .claude/slp-manifest.json ghi (manifest layout cũ cũng đọc được):
#   - .claude/agents/*.md, .claude/skills/<s>/ do adapter sinh (hoặc bản cũ installer cài thẳng)
#   - file adapter, key + hook trong settings.json do SLP thêm (không đụng key khác)
#   - .alp/: file SLP ship mà chưa ai sửa; file đã sửa / anh tự thêm → giữ (--force để xóa)
#   - ALP.md / CLAUDE.md chỉ khi SLP tạo VÀ chưa ai sửa (sha256 khớp)
set -euo pipefail

SLP_REPO="${SLP_REPO:-phucanh08/alp-claude}"
SLP_REF="${SLP_REF:-main}"
ARGS=()
ROOT="$PWD"
GLOBAL=0

usage() {
  cat <<'USAGE'
Usage: uninstall.sh [--global] [--dir <path>] [--force]
  --global      gỡ khỏi ~/.alp + ~/.claude
  --dir <path>  repo root (mặc định: thư mục hiện tại)
  --force       không có manifest vẫn gỡ theo tên SLP; xóa .alp/, ALP.md/CLAUDE.md kể cả đã sửa;
                xóa luôn agent memory (.claude/agent-memory-local/{lead,supervisor}; --global: ~/.claude/agent-memory/supervisor)
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --global) GLOBAL=1; ARGS+=(--global) ;;
    --dir) ROOT="${2:-}"; ARGS+=(--dir "${2:-}"); shift ;;
    --force) ARGS+=(--force) ;;
    -h|--help) usage; exit 0 ;;
    *) echo "uninstall.sh: tham số lạ: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

die() { printf '\033[31m✘\033[0m %s\n' "$*" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || die "cần python3"
[ "$GLOBAL" -eq 1 ] && ROOT="$HOME"

ADAPTER="$ROOT/.claude/slp/alp.py"
TMP=""
trap '[ -z "$TMP" ] || rm -rf "$TMP"' EXIT
if [ ! -f "$ADAPTER" ]; then
  # layout cũ (< 0.10.0) chưa có adapter → dùng bản trên GitHub, nó đọc được manifest cũ
  command -v curl >/dev/null 2>&1 || die "không có $ADAPTER và không có curl để tải adapter"
  TMP="$(mktemp -d)"; ADAPTER="$TMP/alp.py"
  curl -fsSL "https://raw.githubusercontent.com/${SLP_REPO}/${SLP_REF}/adapters/claude/alp.py" -o "$ADAPTER" \
    || die "không tải được adapters/claude/alp.py ($SLP_REPO@$SLP_REF)"
else
  # chạy bản copy: uninstall xóa chính .claude/slp/alp.py
  TMP="$(mktemp -d)"; cp "$ADAPTER" "$TMP/alp.py"; ADAPTER="$TMP/alp.py"
fi
python3 "$ADAPTER" uninstall "${ARGS[@]+"${ARGS[@]}"}"
