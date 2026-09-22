# Setup SLP trên Claude Code Agent Teams

Bộ này chuyển hai instruction SLP `LEAD.md` / `PEER.md` sang Claude Code Agent Teams native.
Không cần Paseo. Cài bằng `install.sh` (xem README) hoặc làm tay theo mục 1–3 dưới đây.

## Kiến trúc

```text
Human
  ↓
Claude Code main session chạy --agent lead
  ↓  named Agent(subagent_type=peer)
Peer teammate(s)
```

Lab đầu chỉ dùng **1 writer Peer**. Read-only Peer có thể chạy song song. Không dùng Supervisor ở
bước đầu.

## 0. Yêu cầu runtime

```bash
claude --version      # ≥ 2.1
claude doctor
claude update         # nếu native install chưa mới
```

Agent Teams là experimental và disabled mặc định. Bật bằng env trong settings hoặc shell.
Khuyến nghị project-local setting để không làm thay đổi mọi repo.

## 1. Agent definitions

`install.sh` copy `agents/lead.md`, `agents/peer.md` → `.claude/agents/`. Làm tay:

```bash
mkdir -p .claude/agents
cp agents/lead.md agents/peer.md .claude/agents/
claude plugin validate .claude/agents
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
claude --agent lead
```

Header phải hiện `@lead`. `--agent` làm main thread dùng system prompt, tool restriction và model
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
2. `docs/LABS.md` — Lab 2 → 5 trên repo thật, tăng dần: tầng BLOCKED/REOPEN → lane mù +
   messaging → Reviewer đúng SHA → Supervisor cross-session.

Không thêm Supervisor trước khi Lab 1–2 ổn; nếu không sẽ khó biết lỗi nằm ở policy hay runtime.

## Official references

- Agent Teams: https://code.claude.com/docs/en/agent-teams
- Custom subagents / `--agent`: https://code.claude.com/docs/en/sub-agents
- Claude Code setup/update: https://code.claude.com/docs/en/setup
- Cross-session messaging: https://code.claude.com/docs/en/cross-session-messaging
