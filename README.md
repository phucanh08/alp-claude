# alp-claude — SLP trên Claude Code Agent Teams

Bộ cài **SLP** (Supervisor / Lead / Peer separation-of-judgment) cho Claude Code Agent Teams
native. Không cần Paseo. Một `install.sh`, một `uninstall.sh`, ba agent definition, **năm skill
theo phase + một router `ask-alp`**, một template `CLAUDE.md`, và 5 lab đã chạy thật + 1 lab cho
Supervisor definition.

```text
Human ──────────────────────────────┐
  ↓                                 ↓
Lead session    claude --agent lead --name lead        Supervisor session (worktree riêng)
  ↓  Agent(subagent_type=peer, name=...)         ←──   claude --agent supervisor --name supervisor
Peer teammate(s)  Engineer | Architect | Reviewer | Scout     cross-session messaging, chỉ DRIFT/ESCALATE

Phase:  intake ──▶ recon ──▶ sequence ──▶ brief ──▶ implement ──▶ commit ──▶ handoff ──▶ accept
Skill:  goal-griller  xia    sequence-      prompt-    (peer.md)    smart-      (peer.md)   (lead.md)
        (Lead)       (Scout) execution-plan leverage                commits
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

Installer làm đúng 5 việc và ghi lại trong `.claude/slp-manifest.json`:

| Việc | Hành vi |
|---|---|
| `.claude/agents/lead.md`, `peer.md`, `supervisor.md` | copy; file cũ khác nội dung → backup `.bak-<timestamp>` (`--force` để bỏ backup) |
| `.claude/skills/{goal-griller,xia,sequence-execution-plan,prompt-leverage,smart-commits}/` | copy cả thư mục; khác nội dung → backup thư mục `.bak-<timestamp>` |
| `.claude/settings.json` | **merge**: thêm `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` và `teammateMode=in-process` nếu chưa có; key khác giữ nguyên |
| `CLAUDE.md` | chỉ tạo từ template nếu **chưa có**; có rồi thì không đụng |
| validate | `claude plugin validate` cho `.claude/agents` và `.claude/skills` nếu có lệnh `claude` |

Yêu cầu: `curl`, `tar`, `python3` **hoặc** `node`. Claude Code ≥ 2.1 (Agent Teams experimental).

## Gỡ

```bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.sh | bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.sh | bash -s -- --global
```

Uninstaller đọc manifest và gỡ **đúng những gì đã cài**: agent files; skill dirs; chỉ các key trong
`settings.json` do SLP thêm (xóa file nếu SLP tạo và giờ rỗng); `CLAUDE.md` chỉ khi SLP tạo **và**
chưa ai sửa (so sha256). Memory `.claude/agent-memory-local/{lead,supervisor}` giữ lại, `--force`
mới xóa. Không có manifest → từ chối, trừ `--force` (khi đó chỉ gỡ 3 agent file + 5 skill dir).

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

Luồng một task đi qua phase nào, skill nào, gate nào: gõ `/ask-alp` (router, Lead/Peer gọi được
qua `Skill`); bản dài trong `skills/ask-alp/references/workflow.md`.

## Skills theo phase

Năm skill viết lại từ [`hoangnb24/skills`](https://github.com/hoangnb24/skills/tree/main/plugins/khuym/skills)
(plugin `khuym`, gốc cho Codex) sang Claude Code + SLP: bỏ `/goal`, hook Codex, DeepWiki/Exa;
thêm ánh xạ vào Task Contract, brief 13 trường, handoff 6 ô, luật một writer, không push.

| Skill | Phase | Vào → Ra |
|---|---|---|
| `goal-griller` | intake | prompt mơ hồ → **Task Contract** 6 ô; chưa đủ ô thì không giao writer |
| `xia` | recon | câu hỏi → research brief nhãn Local/Upstream/Docs/Inference, trong handoff 6 ô |
| `sequence-execution-plan` | sequence | contract + brief → work item, dependency, Now/Next/Later, **writer lease** (Now ≤1 writer/checkout) |
| `prompt-leverage` | brief | work item → **brief 13 trường**; trung lập cách làm, có ruling boundary, không seed verdict; `scripts/augment_prompt.py` nháp khung |
| `smart-commits` | commit gate | working tree → commit logic trong owned scope, **không push**, block Candidate `base..head` |

Năm skill này **không gọi tên ghế**: chúng nói bằng từ vựng authority (*người yêu cầu* / *người
giao việc* / *người nhận việc* / *người quan sát*) và điều kiện dùng (có kênh hỏi người yêu cầu,
sở hữu topology, có write authority…). Ánh xạ ghế ↔ từ vựng, luồng chính, on-ramp và bảng "ghế
nào cấm skill nào" nằm ở một chỗ duy nhất: router **`ask-alp`** (`skills/ask-alp/SKILL.md`, bản
dài `references/workflow.md`). Nhờ vậy đổi ghế, đổi tên agent hay dùng skill ngoài SLP không phải
sửa skill. Skill không cấp authority.

## Cấu trúc repo

```text
agents/lead.md              Lead — framing, delegation, review, acceptance (ACCEPT/REJECT)
agents/peer.md              Peer — bounded co-worker; disposition trong brief; handoff = candidate
agents/supervisor.md        Supervisor — governance; session riêng; DRIFT / ESCALATE / NOTE
skills/<name>/SKILL.md      5 skill theo phase (+ references/, scripts/ cho prompt-leverage)
skills/ask-alp/             router: ghế ↔ từ vựng authority, luồng, on-ramp, bảng cấm; references/workflow.md
templates/CLAUDE.template.md  khung repo-specific contract
templates/settings.json     env + teammateMode
docs/SETUP.md               setup chi tiết + cơ chế runtime cần biết
docs/LAB1.md                Lab 1 trên repo disposable (Python stdlib)
docs/LABS.md                Lab 2–6: prompt + PASS/FAIL + ghi chú từ lần chạy tham chiếu
docs/LAB7.md                Lab 7: 5 skill theo phase trên repo disposable (bẫy mỗi phase, audit script)
docs/WORKFLOW.md            con trỏ → skills/ask-alp/references/workflow.md
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
| 6 | Supervisor với definition riêng + memory riêng: kiểm candidate, self-test D12 (rút lại), ESCALATE khi Lead unhealthy | PASS (sinh 4 sửa `supervisor.md`, 1 sửa `install.sh`) |
| 7 | Năm skill theo phase trên repo disposable: intake mơ hồ → helper có sẵn được dùng lại → brief có ruling → ≥2 commit, 0 push → `ACCEPT` | PASS (sinh 1 sửa `peer.md`, 1 sửa `smart-commits`) |
| 7b | Task từ session khác, repo 30 module: Lead hỏi Human authority → Scout `xia` (0 Edit, nhãn evidence, so sánh stdlib) → `sequence-execution-plan` W1→W2 một writer → 8 ruling → 2 commit, 0 push → `ACCEPT` | PASS |

Chi tiết và prompt trong `docs/LABS.md`; Lab 7 có repo dựng sẵn trong `docs/LAB7.md`.

## Tuning đã đưa vào `lead.md` từ lab

- v0.4.0: skill độc lập với ghế — bỏ mục "Ai dùng" và tên Lead/Peer/Supervisor/Human khỏi 5 skill,
  thay bằng từ vựng authority + điều kiện dùng; thêm router `ask-alp` (model-invocable, Lead/Peer
  gọi qua `Skill`) giữ ánh xạ ghế và bảng cấm; `docs/WORKFLOW.md` dời vào
  `skills/ask-alp/references/workflow.md`; `lead.md` rút bảng skill thành thứ tự mặc định + con trỏ
  `ask-alp`. **Chưa lab** sau đổi.
- v0.3.0: thêm mục "Skills theo phase" vào `lead.md`/`peer.md`, dòng skills vào template
  `CLAUDE.md`; installer/uninstaller quản `.claude/skills/`. Lab 7 PASS: `goal-griller` hỏi đúng một
  câu, `prompt-leverage` ra brief 13 trường có ruling, `smart-commits` 2 commit + 0 push; kiểm hook
  git đổi sang `git rev-parse --git-path hooks` vì plugin hook chặn path thư mục git.
- v0.2.x: `memory: local` (Lab 6: chạy được với `--agent`); ô `Snapshot` → `Candidate` có base SHA
  và verdict line `ACCEPT`/`REJECT` (Lab 6: Lead dùng đúng, kể cả khi Human ép chấm mù → Lead từ
  chối ra verdict trên lời khai); mục "Supervisor — session khác, không phải Human" (Lab 6: Lead
  từ chối mồi D12 và báo Human "Supervisor đang nhân danh anh"). Worktree-per-writer **chưa lab**.

- Bỏ `TaskCreate/TaskGet/TaskList/TaskUpdate` khỏi `tools:` — runtime 2.1.x không có; task
  identity + owner đi trong brief.
- Brief trung lập về *cách làm* nhưng phải chứa **ruling hướng đi** cho boundary trong
  `CLAUDE.md` trước khi Peer viết (Lab 4: Lead từng giao Peer "tự quyết cho nhất quán" ở Dockerfile
  allowlist — kết quả đúng nhưng ruling muộn).

## Tham chiếu

- Agent Teams: https://code.claude.com/docs/en/agent-teams
- Custom subagents / `--agent`: https://code.claude.com/docs/en/sub-agents
- Cross-session messaging: https://code.claude.com/docs/en/cross-session-messaging
