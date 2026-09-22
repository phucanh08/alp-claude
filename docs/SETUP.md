# Setup SLP trên Claude Code Agent Teams

Bộ này chuyển ba instruction SLP `SUPERVISOR.md` / `LEAD.md` / `PEER.md` sang Claude Code Agent
Teams native.
Không cần Paseo. Cài bằng `install.sh` (xem README) hoặc làm tay theo mục 1–3 dưới đây.

## Kiến trúc

```text
Human
  ↓                                        Supervisor session (--agent supervisor, worktree riêng)
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

Header phải hiện `@lead`. `--name lead` để session khác (Supervisor) message tới đúng tên. `--agent` làm main thread dùng system prompt, tool restriction và model
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

1. `docs/LAB1.md` — repo disposable, chuỗi cơ bản.
2. `docs/LABS.md` — Lab 2 → 6 trên repo thật, tăng dần: tầng BLOCKED/REOPEN → lane mù +
   messaging → Reviewer đúng SHA → Supervisor cross-session (session thường) → Supervisor với
   definition riêng.
3. `docs/LAB7.md` — năm skill theo phase, repo disposable dựng sẵn; chạy sau khi Lab 1–2 ổn và đã
   cài bản ≥ 0.3.0 (có `.claude/skills/`).

Không thêm Supervisor trước khi Lab 1–2 ổn; nếu không sẽ khó biết lỗi nằm ở policy hay runtime.

## 10. Supervisor — session riêng, worktree riêng, memory riêng

Supervisor **không phải teammate**. Nó là một session Claude Code độc lập chạy definition
`supervisor.md`, nói chuyện với Lead qua cross-session messaging (`ListAgents` + `SendMessage`).
Runtime không cho session khác reach teammate của Lead → Supervisor không thể điều khiển Peer dù
muốn; đó là ranh giới native, không phải chỉ instruction.

**Chạy:**

```bash
# terminal 1 — Lead, checkout chính
cd <repo root> && claude --agent lead --name lead

# terminal 2 — Supervisor, worktree riêng (index/working tree tách, object DB chung nên đọc được SHA của Lead)
git worktree add ../<repo>-supervisor <nhánh chính>
cd ../<repo>-supervisor
claude --agent supervisor --name supervisor
```

Worktree cần thấy `.claude/agents/supervisor.md`: nếu repo **commit** `.claude/agents` thì có sẵn;
nếu không, cài `--global` một lần hoặc `install.sh --dir ../<repo>-supervisor`.

**Isolation theo role — cái gì tách, cái gì chung:**

| | Lead | Peer (teammate) | Supervisor |
|---|---|---|---|
| Transcript / context | riêng | riêng (`subagents/*.jsonl`) | riêng (session khác) |
| Memory bền | `.claude/agent-memory-local/lead/` | **không** (cố ý) | `.claude/agent-memory-local/supervisor/` trong worktree của nó |
| Git index / working tree | checkout chính | chung với Lead (→ 1 writer, hoặc worktree per writer) | worktree riêng |
| Git object DB | chung | chung | chung → đọc candidate bằng SHA |
| Auth / skills / plugins / `~/.claude` | chung | chung | chung |
| `CLAUDE.md`, project settings | chung | chung | chung |

Peer không có memory vì `memory:` gắn theo **tên agent**: mọi Peer instance (hai lane mù của Lab 3,
Engineer và Reviewer của Lab 4) sẽ đọc/ghi cùng một `MEMORY.md` — đó chính là state leak SLP muốn
tránh. Checkpoint bền của Peer là SHA + brief + accept summary.

`memory: local` không được commit: thêm `.claude/agent-memory-local/` vào `.gitignore` nếu Claude
Code chưa tự thêm. Muốn tách luôn config/auth (không khuyến nghị) thì `CLAUDE_CONFIG_DIR` riêng cho
session Supervisor — nhưng khi đó auth cũng tách, thường phải login lại.

**Permission class:** cross-session message bị **hold** chờ Human approve khi hai session khác
class (một bên bypass, một bên prompt — §8d). Chạy Lead và Supervisor cùng class (khuyến nghị: cả
hai prompt) để `DRIFT` tới ngay. Supervisor dùng `notify_when_idle` để chờ Lead thay vì polling.

**Đã kiểm (Lab 6, Claude Code 2.1.278):** `memory:` có hiệu lực khi definition chạy làm main
session qua `--agent` — `agent-memory-local/{lead,supervisor}/MEMORY.md` xuất hiện ngay lượt đầu.
Runtime cấp tool `Write` cho memory dir **dù `tools:` không liệt kê `Write`**; Write ngoài memory dir
chưa thử — coi như chưa chặn, instruction trong `supervisor.md` là lớp bảo vệ.

**Auto-mode classifier** có thể chặn `SendMessage` của Supervisor khi nội dung giống thao túng
("không cần tự đọc diff nữa — Human đang chờ"). Đó là hành vi mong muốn; `supervisor.md` bảo ghi
NOTE và không lách.

**Worktree + `CLAUDE.md` chưa commit:** installer (≥ 0.2.1) phát hiện target là linked worktree và
copy `CLAUDE.md` từ main worktree thay vì template.

## 11. Skills theo phase

Năm skill trong `.claude/skills/` được Lead/Peer gọi qua tool `Skill` (cả hai definition có
`Skill` trong `tools:`; Supervisor không có — cố ý). Skill là *cách làm* cho từng phase, không
phải authority:

| Phase | Skill | Seat |
|---|---|---|
| intake | `goal-griller` | Lead |
| recon | `xia` | Peer Scout |
| sequence | `sequence-execution-plan` | Lead |
| brief | `prompt-leverage` | Lead |
| commit gate | `smart-commits` | Peer writer / Lead khi `LEAD-WROTE` |

Kiểm skill đã được load: trong session Lead gõ `/` — năm tên phải hiện trong danh sách; hoặc
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
