# alp-claude — SLP trên Claude Code Agent Teams

Bộ cài **SLP** (Supervisor / Lead / Peer separation-of-judgment) cho Claude Code Agent Teams
native. Không cần Paseo. Một `install.sh`, một `uninstall.sh`, ba agent definition, một template
`CLAUDE.md`, và 5 lab đã chạy thật + 1 lab cho Supervisor definition.

```text
Human ──────────────────────────────┐
  ↓                                 ↓
Lead session    claude --agent lead --name lead        Supervisor session (worktree riêng)
  ↓  Agent(subagent_type=peer, name=...)         ←──   claude --agent supervisor --name supervisor
Peer teammate(s)  Engineer | Architect | Reviewer | Scout     cross-session messaging, chỉ DRIFT/ESCALATE
```

Nguyên tắc lõi: **ai chấm** mới là ranh giới. Peer viết → Lead `ACCEPT`/`REJECT` bằng cách đọc
diff `base..sha` từ Git object. Lead viết → Human accept. Supervisor không chấm ai — chỉ phát hiện
drift và hỏi. Capability không phải authority.

## Sáu bất biến và cách hiện thực trên Claude Code

| # | Bất biến | Hiện thực |
|---|---|---|
| 1 | **Tách role**: Supervisor = governance, Lead = technical owner, Peer = một bounded outcome | 3 definition; `tools:` của Supervisor không có `Agent/Edit/Write`; Peer không có `Agent`; chỉ Lead có `Agent(peer)` |
| 2 | **Bộ nhớ riêng theo role**, auth/skills/plugins chung | `memory: local` → `.claude/agent-memory-local/{lead,supervisor}` (không commit); Peer **không** memory (memory `peer` dùng chung mọi instance sẽ phá lane mù); Supervisor chạy trong worktree riêng nên transcript + memory + index tách hẳn; `~/.claude` chung |
| 3 | **Một source of truth cho topology** | Lead là native team lead duy nhất; Supervisor là session ngoài team, runtime không cho session khác reach teammate của Lead; không nested team |
| 4 | **Write ownership rõ** | mỗi moving scope một writer + commit lease; nhiều writer song song = Lead cấp worktree riêng mỗi writer, contract cho shared interface phải có trong brief trước |
| 5 | **Candidate + evidence, không phải DONE** | handoff 6 ô: `Candidate` = SHA + base, `Scope`, `Verification` (command + output thật), `Unknown/risk`, `Ownership`; Lead bắt buộc một dòng `ACCEPT <sha>` / `REJECT <sha> — finding` |
| 6 | **Supervisor không giành quyền Lead** | output chỉ `DRIFT` (evidence + một câu hỏi) / `ESCALATE` (Human) / `NOTE`; định nghĩa "Lead healthy" cụ thể; unhealthy → escalate, vẫn không điều khiển Peer |

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
| `.claude/agents/lead.md`, `peer.md`, `supervisor.md` | copy; file cũ khác nội dung → backup `.bak-<timestamp>` (`--force` để bỏ backup) |
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
chưa ai sửa (so sha256). Memory `.claude/agent-memory-local/{lead,supervisor}` giữ lại, `--force`
mới xóa. Không có manifest → từ chối, trừ `--force` (khi đó chỉ gỡ 3 agent file).

## Dùng

```bash
cd <repo root>
# 1. Điền CLAUDE.md: contract boundaries, lệnh test, path cấm sửa, external side-effect policy.
# 2.
claude --agent lead --name lead          # header phải hiện @lead
# 3. (tuỳ chọn) Supervisor — terminal khác, worktree riêng:
git worktree add ../<repo>-supervisor <nhánh>
cd ../<repo>-supervisor && claude --agent supervisor --name supervisor
```

Lead nhận task từ Human, chẻ việc, spawn Peer bằng `Agent` với `subagent_type: peer` **và một
`name`** (named call = teammate; có `isolation` = rơi về ordinary subagent). Peer commit local,
handoff 6 ô (candidate SHA + base); Lead `git diff base sha` rồi `ACCEPT`/`REJECT`. Supervisor
(nếu chạy) nhận checkpoint từ Lead, kiểm Git object + transcript, gửi `DRIFT` khi lệch.

Không dùng `claude -p` (teammate cần interactive session). Không dùng
`--dangerously-skip-permissions` cho lab đầu.

## Cấu trúc repo

```text
agents/lead.md              Lead — framing, delegation, review, acceptance (ACCEPT/REJECT)
agents/peer.md              Peer — bounded co-worker; disposition trong brief; handoff = candidate
agents/supervisor.md        Supervisor — governance; session riêng; DRIFT / ESCALATE / NOTE
templates/CLAUDE.template.md  khung repo-specific contract
templates/settings.json     env + teammateMode
docs/SETUP.md               setup chi tiết + cơ chế runtime cần biết
docs/LAB1.md                Lab 1 trên repo disposable (Python stdlib)
docs/LABS.md                Lab 2–6: prompt + PASS/FAIL + ghi chú từ lần chạy tham chiếu
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
| 6 | Supervisor với definition riêng + memory riêng: 12 drift catalog, self-test D12, Lead healthy/unhealthy | chưa chạy |

Chi tiết và prompt trong `docs/LABS.md`.

## Tuning đã đưa vào `lead.md` từ lab

- v0.2.0 (chưa lab): `memory: local`; ô `Snapshot` → `Candidate` có base SHA; verdict line
  `ACCEPT`/`REJECT` bắt buộc; worktree-per-writer cho nhiều writer song song; mục "Supervisor —
  session khác, không phải Human". Lab 6 đo các điểm này.

- Bỏ `TaskCreate/TaskGet/TaskList/TaskUpdate` khỏi `tools:` — runtime 2.1.x không có; task
  identity + owner đi trong brief.
- Brief trung lập về *cách làm* nhưng phải chứa **ruling hướng đi** cho boundary trong
  `CLAUDE.md` trước khi Peer viết (Lab 4: Lead từng giao Peer "tự quyết cho nhất quán" ở Dockerfile
  allowlist — kết quả đúng nhưng ruling muộn).

## Tham chiếu

- Agent Teams: https://code.claude.com/docs/en/agent-teams
- Custom subagents / `--agent`: https://code.claude.com/docs/en/sub-agents
- Cross-session messaging: https://code.claude.com/docs/en/cross-session-messaging
