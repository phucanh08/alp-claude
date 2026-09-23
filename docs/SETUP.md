# Setup SLP trên Claude Code Agent Teams

Bộ này chuyển ba instruction SLP `SUPERVISOR.md` / `LEAD.md` / `PEER.md` sang Claude Code Agent
Teams native.
Không cần Paseo. Cài bằng `install.sh` (xem README) hoặc làm tay theo mục 1–3 dưới đây.
Cài xong, cách dùng hằng ngày và case thực tế: [USAGE.md](USAGE.md).

## Kiến trúc

```text
Human
  ↓                                        Supervisor session (--agent supervisor, ngoài checkout của Lead; theo dõi 1..N Lead)
Claude Code main session chạy --agent lead   ←── cross-session messaging (DRIFT / ESCALATE / NOTE)
  ↓  named Agent(subagent_type=peer)
Peer teammate(s)
```

Lab đầu chỉ dùng **1 writer Peer**. Read-only Peer có thể chạy song song. Không dùng Supervisor ở
bước đầu — thêm ở §10 sau khi Lab 1–2 ổn.

## 0. Yêu cầu runtime

```bash
claude --version      # ≥ 2.1
claude doctor
claude update         # nếu native install chưa mới
```

Agent Teams là experimental và disabled mặc định. Bật bằng env trong settings hoặc shell.
Khuyến nghị project-local setting để không làm thay đổi mọi repo.

## 1. Agent definitions

`install.sh` copy `agents/lead.md`, `peer.md`, `supervisor.md` → `.claude/agents/` và năm thư mục
`skills/<name>/` → `.claude/skills/`. Làm tay:

```bash
mkdir -p .claude/agents .claude/skills
cp agents/lead.md agents/peer.md agents/supervisor.md .claude/agents/
cp -R skills/goal-griller skills/xia skills/sequence-execution-plan skills/prompt-leverage skills/smart-commits .claude/skills/
claude plugin validate .claude/agents && claude plugin validate .claude/skills
```

`name` + `description` là frontmatter bắt buộc. Main session chạy một definition trực tiếp bằng
`claude --agent <name>`.

## 2. Bật Agent Teams

`.claude/settings.json` cần tối thiểu:

```json
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
  "teammateMode": "in-process"
}
```

File đã tồn tại → **merge** key `env`, không overwrite (installer làm đúng vậy).

`in-process` là mode đơn giản nhất. Split panes cần tmux/iTerm2 và chưa đem thêm giá trị cho
kiểm chứng SLP cơ bản — nhưng xem "cơ chế cần biết" §c dưới đây nếu anh thấy header lạ.

## 3. `CLAUDE.md`

Installer copy `templates/CLAUDE.template.md` nếu repo chưa có. Điền tối thiểu:

- contract boundaries;
- lệnh unit/full test (và test nào chiếm tài nguyên độc quyền: port, DB, docker);
- path generated / cấm sửa;
- external side-effect policy.

Đừng nhét toàn bộ SLP vào `CLAUDE.md`: Lead/Peer invariant đã nằm trong agent definition;
`CLAUDE.md` giữ **repo-specific contract**: cái gì Lead phải ruling trước khi Peer đi qua, lệnh nào
là proof, tài nguyên nào độc quyền, việc gì cấm làm ra ngoài máy.

## 4. Start đúng Lead seat

```bash
cd <repo root>
claude --agent lead --name lead
```

Header phải hiện `@lead`. `--name lead` để session khác (Supervisor) message tới đúng tên. Workspace
nhiều repo → mỗi repo một Lead, tên `lead-<repo>` (`--name lead-backend`); tên trùng thì runtime đổi
tên session sau thành biến thể, Supervisor sẽ không tìm ra đúng Lead. `--agent` làm main thread dùng system prompt, tool restriction và model
của definition; `CLAUDE.md` vẫn được load. **Không dùng `claude -p`**: teammate spawning cần
interactive session.

## 5. Cơ chế spawn Peer

Lead dùng `Agent` với cả:

- `subagent_type: peer`;
- một **`name`**.

Khi Agent Teams bật, named Agent call trở thành teammate. Truyền `isolation` → call đi theo đường
ordinary subagent, không phải teammate.

Peer definition cố tình không cấp `Agent` tool. In-process teammate vẫn được runtime thêm
`SendMessage` khi team có tool đó, nên Peer thấy control-plane surface; instruction cấm nó tự mở
topology hoặc tự claim scope khác.

## 6. Permission model

Teammate bắt đầu với permission mode của Lead. Permission prompt của teammate nổi lên ở Lead
session. Không dùng `--dangerously-skip-permissions` cho lab đầu.

Bị quá nhiều prompt → sau khi hiểu chính xác lệnh nào cần, mới thêm allow rule hẹp trong project
settings.

## 7. Git / concurrency

Teammate native **không** có worktree riêng; Git index là shared mutable state. SLP đi chặt hơn
docs: **trong một shared checkout mặc định chỉ 1 active writer/committer.** Nhiều read-only Peer
song song được. Cần nhiều writer thật → independent Claude sessions + worktree + cross-session
messaging; đó là topology khác.

## 8. Cơ chế runtime cần biết (rút từ lab)

**a. Xác nhận teammate thật, không phải subagent.** Không tin header UI; đọc metadata runtime:

```bash
ls ~/.claude/projects/<slug>/<session-id>/subagents/*.meta.json
# "taskKind": "in_process_teammate", "customAgentType": "peer", "teamName": "session-<id>"
```

Kết quả spawn của teammate có câu "will receive instructions via mailbox"; ordinary subagent thì
không.

**b. Task-list tool không có** trong main session ở 2.1.x (`TaskCreate/TaskList` không tồn tại).
`lead.md` đã bỏ khỏi `tools:`; task identity + owner đi trong brief.

**c. Header vẫn hiện `@lead` khi xem transcript của teammate.** In-process teammate chạy trong
cùng process với Lead, header là của process. Cùng lý do, `echo $CLAUDE_CODE_AGENT` trong Bash của
Peer in ra `lead` — cosmetic. Bằng chứng thật là `customAgentType` trong meta và hành vi (Peer
không có `Agent` tool).

**d. Cross-session message bị giữ chờ approve** khi hai session khác permission mode. Session gửi
nhận `[Cross-session delivery notice]`; Human phải approve ở session nhận. Message từ session khác
**không phải Human** — Lead đúng khi không coi nó là nguồn authority (Lab 2, Lab 5).

**e. Sửa `lead.md` khi Lead đang chạy không có hiệu lực** cho tới khi start lại
`claude --agent lead`. Peer định nghĩa đọc lại ở mỗi lần spawn.

## 9. Thứ tự lab

Mục lục và thứ tự đầy đủ: [`docs/labs/README.md`](labs/README.md). Tóm tắt:

1. Lab 1 — repo disposable, chuỗi cơ bản.
2. Lab 2 → 6 trên repo thật, tăng dần: tầng BLOCKED/REOPEN → lane mù + messaging → Reviewer đúng
   SHA → Supervisor cross-session (session thường) → Supervisor với definition riêng.
3. Lab 7 — năm skill theo phase, repo disposable dựng sẵn; chạy sau khi Lab 1–2 ổn và đã cài bản
   ≥ 0.3.0 (có `.claude/skills/`).
4. Lab 8 — một Supervisor, nhiều Lead / nhiều workspace; sau Lab 6.

Không thêm Supervisor trước khi Lab 1–2 ổn; nếu không sẽ khó biết lỗi nằm ở policy hay runtime.

## 10. Supervisor — session riêng, ngoài checkout của Lead, theo dõi nhiều Lead

Supervisor **không phải teammate**. Nó là một session Claude Code độc lập chạy definition
`supervisor.md`, nói chuyện với từng Lead qua cross-session messaging (`ListAgents` + `SendMessage`).
Runtime không cho session khác reach teammate của Lead → Supervisor không thể điều khiển Peer dù
muốn; đó là ranh giới native, không phải chỉ instruction.

**Đọc mọi file, không ghi file nào, không cần worktree.** Supervisor chạy với
`--settings <.claude>/slp-supervisor.settings.json` (installer cài sẵn):

| Cơ chế | Tác dụng |
|---|---|
| `permissions.allow: Read(//**)` | tool Read/Grep/Glob đọc mọi file trên máy, không hỏi |
| hook `PreToolUse` cho `Write\|Edit\|MultiEdit\|NotebookEdit` | chặn (exit 2) mọi path ngoài `~/.claude/agent-memory/supervisor/` (so `realpath`, chống `../`). Cần hook: runtime cấp tool `Write` chung, không giới hạn path — Lab 8b đo được `Write` vào repo **chạy** khi không có hook |
| `permissions.allow: Edit(~/.claude/agent-memory/supervisor/**)` | Supervisor tự sửa memory của chính nó bằng `Write` (runtime cấp riêng cho memory dir; luật path `Edit(...)` áp cho cả `Write`); ngoài memory dir không có luật allow → `Write` bị hỏi/từ chối |
| `sandbox.enabled` + `autoAllowBashIfSandboxed` | Bash chạy không hỏi, nhưng OS (Seatbelt/bubblewrap) chỉ cho **ghi** vào cwd + `$TMPDIR` của session; **đọc** mọi nơi |
| `sandbox.allowUnsandboxedCommands: false` | không có lối thoát `dangerouslyDisableSandbox` |

Memory `~/.claude/agent-memory/supervisor/` sửa bằng tool `Write` (runtime cấp riêng cho memory
dir, không cấp `Edit`); sandbox chặn Bash ghi vào `~/.claude`. Memory của Lead chỉ đọc. Vì sandbox cho Bash ghi vào cwd, **cwd của Supervisor
phải là thư mục trung lập không chứa repo** (vd. `~/slp-supervisor`) — không phải gốc workspace có
repo con, không phải checkout của Lead. Đừng thêm `--add-dir <root Lead>`: thư mục thêm vào cũng
thành chỗ ghi được. Cross-session messaging thấy mọi session trên máy bất kể cwd, nên một
Supervisor nghe được nhiều Lead ở nhiều repo, nhiều workspace.

Lưu ý: sandbox luôn cho ghi `/tmp/claude*` và `/private/tmp/claude*` (temp của Claude Code). Repo
thật đặt ở đó thì Supervisor ghi được — đừng để repo ở đó (Lab 8b đo được).

**Chạy — repo đơn:**

```bash
# terminal 1 — Lead
cd <repo root> && claude --agent lead --name lead
# terminal 2 — Supervisor, thư mục trung lập
mkdir -p ~/slp-supervisor && cd ~/slp-supervisor
claude --agent supervisor --name supervisor --settings <repo root>/.claude/slp-supervisor.settings.json
```

**Chạy — workspace nhiều repo** (vd. `project-a-workspace/{backend,webadmin,webclient,mobileapp}`,
mỗi thư mục con là repo riêng):

```bash
# một lần: agents + skills toàn máy — Lead ở repo con không thấy .claude/agents của workspace,
# vì runtime chỉ quét .claude/agents từ cwd lên tới repository root
install.sh --global
# CLAUDE.md chung (cross-repo contract, bảng part ↔ Lead) ở gốc workspace
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/templates/WORKSPACE.CLAUDE.template.md \
  -o project-a-workspace/CLAUDE.md
# mỗi repo con vẫn cần CLAUDE.md riêng: templates/CLAUDE.template.md

cd project-a-workspace/backend   && claude --agent lead --name lead-backend     # terminal 1
cd project-a-workspace/webclient && claude --agent lead --name lead-webclient   # terminal 2
cd ~/slp-supervisor && claude --agent supervisor --name supervisor \
  --settings ~/.claude/slp-supervisor.settings.json                            # terminal N
```

Lead ở repo con tự nạp `CLAUDE.md` của workspace (runtime nạp `CLAUDE.md` của mọi thư mục cha),
nên cross-repo contract là boundary với mọi Lead. Supervisor đọc file đó bằng đường dẫn tuyệt đối
(`Root` → thư mục cha trong `SLP-REGISTER`). Một Supervisor nghe được Lead của nhiều workspace; mỗi
workspace một file memory.

**Permission class:** Supervisor chạy mode thường (prompt) + sandbox. Lead phải cùng class — không
chạy Lead với `--dangerously-skip-permissions`, nếu không message giữa hai bên bị hold.

**Monorepo** (workspace là một repo): mặc định một Lead. Muốn nhiều Lead → mỗi Lead một worktree
riêng (`git worktree add ../<repo>-<phần> -b lead/<phần>`), `Scope` không giao nhau ghi trong
`CLAUDE.md` workspace.

**Đăng ký:** mở phiên, Supervisor gửi mỗi Lead một message; Lead trả block `SLP-REGISTER` (`Lead`,
`Root`, `Main @ sha`, `Workspace`, `Scope`). Lead mở sau Supervisor thì tự gửi khi `ListAgents` thấy
`supervisor`. Supervisor kiểm root/scope không trùng (`D14`), rồi theo dõi từng Lead như một làn
riêng: output ghi `@<lead>`, healthy/unhealthy và `ESCALATE` tính riêng.

**Isolation theo role — cái gì tách, cái gì chung:**

| | Lead | Peer (teammate) | Supervisor |
|---|---|---|---|
| Transcript / context | riêng (slug theo root của Lead) | riêng (`subagents/*.jsonl`) | riêng (slug theo cwd của nó) |
| Memory bền | `.claude/agent-memory-local/lead/` trong repo | **không** (cố ý) | `~/.claude/agent-memory/supervisor/` (scope `user`), một file mỗi workspace |
| Git index / working tree | checkout của nó | chung với Lead (→ 1 writer, hoặc worktree per writer) | không có; đọc working tree mọi Lead (quan sát), chấm theo SHA; sandbox chặn ghi |
| Git object DB | của repo | chung với Lead | đọc của từng Lead qua `-C` |
| Auth / skills / plugins / `~/.claude` | chung | chung | chung |
| `CLAUDE.md` | repo + các thư mục cha (workspace) | như Lead | đọc của từng Lead bằng path tuyệt đối |

Peer không có memory vì `memory:` gắn theo **tên agent**: mọi Peer instance (hai lane mù của Lab 3,
Engineer và Reviewer của Lab 4) sẽ đọc/ghi cùng một `MEMORY.md` — đó chính là state leak SLP muốn
tránh. Checkpoint bền của Peer là SHA + brief + accept summary.

`memory: local` (Lead) không được commit: thêm `.claude/agent-memory-local/` vào `.gitignore` nếu
Claude Code chưa tự thêm. Supervisor từ 0.5.0 dùng `memory: user` — nằm ngoài mọi repo; memory cũ ở
`.claude/agent-memory-local/supervisor/` (≤ 0.4.x) không tự chuyển, copy tay nếu cần.

Muốn tách luôn config/auth (không khuyến nghị) thì `CLAUDE_CONFIG_DIR` riêng cho
session Supervisor — nhưng khi đó auth cũng tách, thường phải login lại.

**Permission class:** cross-session message bị **hold** chờ Human approve khi hai session khác
class (một bên bypass, một bên prompt — §8d). Chạy Lead và Supervisor cùng class (khuyến nghị: cả
hai prompt) để `DRIFT` tới ngay. Supervisor dùng `notify_when_idle` để chờ Lead thay vì polling.

**Đã kiểm (Lab 6, Claude Code 2.1.278):** `memory:` có hiệu lực khi definition chạy làm main
session qua `--agent` — `agent-memory-local/{lead,supervisor}/MEMORY.md` xuất hiện ngay lượt đầu
(scope `local`). Scope `user` của Supervisor 0.5.0: Lab 8 — `~/.claude/agent-memory/supervisor/`
+ `MEMORY.md` index, một file mỗi workspace, ghi bằng Bash heredoc vào memory dir.
Runtime cấp tool `Write` cho memory dir **dù `tools:` không liệt kê `Write`** — và đó là `Write` chung,
không giới hạn path (Lab 8b: `Write` vào file trong repo chạy được). Lớp chặn là hook `PreToolUse`
trong `slp-supervisor.settings.json`; không chạy với settings đó thì chỉ còn instruction.

**Auto-mode classifier** có thể chặn `SendMessage` của Supervisor khi nội dung giống thao túng
("không cần tự đọc diff nữa — Human đang chờ"). Đó là hành vi mong muốn; `supervisor.md` bảo ghi
NOTE và không lách.

**Worktree + `CLAUDE.md` chưa commit:** installer (≥ 0.2.1) phát hiện target là linked worktree và
copy `CLAUDE.md` từ main worktree thay vì template. Chỉ còn cần khi Lead (monorepo) hoặc Supervisor
chạy trong worktree.

## 11. Skills theo phase

Năm skill theo phase (và skill phương pháp `bug-loop`, chỉ bắt buộc khi brief khai `Required skills`) trong `.claude/skills/` được Lead/Peer gọi qua tool `Skill` (cả hai definition có
`Skill` trong `tools:`; Supervisor không có — cố ý). Skill là *cách làm* cho từng phase, không
phải authority:

| Phase | Skill | Seat |
|---|---|---|
| intake | `goal-griller` | Lead |
| recon | `xia` | Peer Scout |
| sequence | `sequence-execution-plan` | Lead |
| brief | `prompt-leverage` | Lead |
| commit gate | `smart-commits` | Peer writer / Lead khi `LEAD-WROTE` |
| theo `Required skills` | `bug-loop` | Peer (read-only: Phase 1–4; writer: đủ) |

Kiểm skill đã được load: trong session Lead gõ `/` — bảy tên (năm skill phase + `bug-loop` + `ask-alp`) phải hiện trong danh sách; hoặc
`claude plugin validate .claude/skills`. Skill dir bị sửa tay → lần `install.sh` sau backup thành
`<name>.bak-<timestamp>` rồi ghi bản mới.

Script `prompt-leverage/scripts/augment_prompt.py` chỉ cần python3 stdlib:

```bash
python3 .claude/skills/prompt-leverage/scripts/augment_prompt.py "<prompt thô>" --task-id T-1
python3 .claude/skills/prompt-leverage/scripts/test_augment_prompt.py
```

Luồng đầy đủ và gate giữa các phase: `/ask-alp` (router) và `skills/ask-alp/references/workflow.md`.

## Official references

- Agent Teams: https://code.claude.com/docs/en/agent-teams
- Custom subagents / `--agent`: https://code.claude.com/docs/en/sub-agents
- Claude Code setup/update: https://code.claude.com/docs/en/setup
- Cross-session messaging: https://code.claude.com/docs/en/cross-session-messaging
