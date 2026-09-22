# alp-claude — SLP trên Claude Code Agent Teams

Bộ cài **SLP** (Lead / Peer separation-of-judgment) cho Claude Code Agent Teams native.
Không cần Paseo. Một `install.sh`, một `uninstall.sh`, hai agent definition, một template
`CLAUDE.md`, và 5 lab đã chạy thật để kiểm chứng.

```text
Human
  ↓
Claude Code main session   claude --agent lead
  ↓  Agent(subagent_type=peer, name=...)
Peer teammate(s)           Engineer | Architect | Reviewer | Scout
```

Nguyên tắc lõi: **ai chấm** mới là ranh giới. Peer viết → Lead accept bằng cách đọc diff từ Git
object của đúng SHA. Lead viết → Human accept. Capability không phải authority.

## Cài

Project-level (khuyến nghị — chạy tại repo root, không đổi config toàn máy):

```bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash
```

Global (`~/.claude/agents`, dùng chung mọi repo):

```bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash -s -- --global
```

Pin version / cài vào repo khác:

```bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | SLP_REF=v0.1.0 bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash -s -- --dir /path/to/repo
```

Installer làm đúng 4 việc và ghi lại trong `.claude/slp-manifest.json`:

| Việc | Hành vi |
|---|---|
| `.claude/agents/lead.md`, `peer.md` | copy; file cũ khác nội dung → backup `.bak-<timestamp>` (`--force` để bỏ backup) |
| `.claude/settings.json` | **merge**: thêm `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` và `teammateMode=in-process` nếu chưa có; key khác giữ nguyên |
| `CLAUDE.md` | chỉ tạo từ template nếu **chưa có**; có rồi thì không đụng |
| validate | `claude plugin validate .claude/agents` nếu có lệnh `claude` |

Yêu cầu: `curl`, `tar`, `python3` **hoặc** `node`. Claude Code ≥ 2.1 (Agent Teams experimental).

## Gỡ

```bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.sh | bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.sh | bash -s -- --global
```

Uninstaller đọc manifest và gỡ **đúng những gì đã cài**: agent files; chỉ các key trong
`settings.json` do SLP thêm (xóa file nếu SLP tạo và giờ rỗng); `CLAUDE.md` chỉ khi SLP tạo **và**
chưa ai sửa (so sha256). Không có manifest → từ chối, trừ `--force` (khi đó chỉ gỡ 2 agent file).

## Dùng

```bash
cd <repo root>
# 1. Điền CLAUDE.md: contract boundaries, lệnh test, path cấm sửa, external side-effect policy.
# 2.
claude --agent lead          # header phải hiện @lead
```

Lead nhận task từ Human, chẻ việc, spawn Peer bằng `Agent` với `subagent_type: peer` **và một
`name`** (named call = teammate; có `isolation` = rơi về ordinary subagent). Peer commit local,
handoff 6 ô + SHA; Lead `git diff sha^ sha` rồi accept hoặc trả finding.

Không dùng `claude -p` (teammate cần interactive session). Không dùng
`--dangerously-skip-permissions` cho lab đầu.

## Cấu trúc repo

```text
agents/lead.md              Lead — framing, delegation, review, acceptance
agents/peer.md              Peer — bounded co-worker; disposition trong brief
templates/CLAUDE.template.md  khung repo-specific contract
templates/settings.json     env + teammateMode
docs/SETUP.md               setup chi tiết + cơ chế runtime cần biết
docs/LAB1.md                Lab 1 trên repo disposable (Python stdlib)
docs/LABS.md                Lab 2–5: prompt + PASS/FAIL + ghi chú từ lần chạy tham chiếu
install.sh / uninstall.sh
VERSION
```

## Lab

| Lab | Đo | Trạng thái |
|---|---|---|
| 1 | Human → Lead → 1 Peer writer → commit → Lead đọc SHA → accept | PASS |
| 2 | Contract mơ hồ / sai tiền đề / thiếu authority → `BLOCKED` / `REOPEN_REQUEST` đúng tầng | PASS |
| 3 | 2 lane read-only mù + messaging evidence-only + 1 writer | PASS |
| 4 | Engineer commit → Reviewer độc lập đọc đúng SHA → Lead accept | PASS (sinh 1 sửa `lead.md`) |
| 5 | Supervisor = session độc lập qua cross-session messaging; 2 mồi authority / evidence | PASS |

Chi tiết và prompt trong `docs/LABS.md`.

## Tuning đã đưa vào `lead.md` từ lab

- Bỏ `TaskCreate/TaskGet/TaskList/TaskUpdate` khỏi `tools:` — runtime 2.1.x không có; task
  identity + owner đi trong brief.
- Brief trung lập về *cách làm* nhưng phải chứa **ruling hướng đi** cho boundary trong
  `CLAUDE.md` trước khi Peer viết (Lab 4: Lead từng giao Peer "tự quyết cho nhất quán" ở Dockerfile
  allowlist — kết quả đúng nhưng ruling muộn).

## Tham chiếu

- Agent Teams: https://code.claude.com/docs/en/agent-teams
- Custom subagents / `--agent`: https://code.claude.com/docs/en/sub-agents
- Cross-session messaging: https://code.claude.com/docs/en/cross-session-messaging
