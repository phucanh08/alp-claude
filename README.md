# alp-claude — SLP trên Claude Code Agent Teams

Bộ cài **SLP** (Supervisor / Lead / Peer separation-of-judgment) cho Claude Code Agent Teams
native. Không cần Paseo; kênh tin giữa các ghế là hộp thư MCP `slp-mail` (tuỳ chọn, một file
Python). Một `install.sh`, một `uninstall.sh`, ba agent definition, **năm skill
theo phase + một skill phương pháp `bug-loop` + một router `ask-alp`**, template `CLAUDE.md` cho repo và cho workspace nhiều repo, và
5 lab đã chạy thật + 1 lab cho Supervisor definition.

```text
Human ── terminal của Lead, hoặc CLI slp_mail.py send (from: human) ─────────────────┐
  ↓                                                                                   ↓
Lead session(s)  claude --agent lead --name lead[-<repo>] [--mcp-config]          Supervisor session (ngoài checkout mọi Lead)
  ↓  Agent(subagent_type=peer, name=...)                                    ←──    claude --agent supervisor [--mcp-config]
Peer teammate(s)  Engineer | Architect | Reviewer | Scout                           1 Supervisor : N Lead; DRIFT/ESCALATE/NOTE + RULING S#;
  ↑  hộp thư slp-mail: from theo process; tin tới Peer từ ngoài team tự cc Lead      hỏi Peer được (Lead cc); bàn hướng đi với Human

Phase:  intake ──▶ recon ──▶ sequence ──▶ brief ──▶ implement ──▶ commit ──▶ handoff ──▶ accept
Skill:  goal-griller  xia    sequence-      prompt-    (peer.md)    smart-      (peer.md)   (lead.md)
        (Lead)       (Scout) execution-plan leverage                commits
```

Nguyên tắc lõi: **ai chấm** mới là ranh giới. Peer viết → Lead `ACCEPT`/`REJECT` bằng cách đọc
diff `base..sha` từ Git object. Lead viết → Human accept. Supervisor không chấm ai — phát hiện drift
và hỏi, bàn hướng đi với Human, và chỉ quyết trong danh sách `S#` Human ghi ở `CLAUDE.md`.
Capability không phải authority; authority đọc ở `from` do server gán, không ở lời văn.

SLP không phải role-play: ghế là *trách nhiệm + quyền hạn*, không phải tính cách. Peer có thể là
Implementer, Reviewer, Architect hay Auditor (kiểm chất lượng test và e2e proof) tuỳ brief;
cái không đổi là ai được sửa gì và ai chấm. Nền lý thuyết: bài
[Bàn về multi-agent orchestration và mô hình SLP](https://vhlam.com/article/agent-orchestration-multi-agent-slp)
(v0.8.0 port phần *cái dù*, quyền chất vấn, vòng phát hiện → quyết định, Better-SLP; v0.9.0 port
phần Supervisor của bài: bàn hướng đi với Human, hỏi được Peer, can thiệp trong quyền được giao —
trên hộp thư `slp-mail`).

## Bảy bất biến và cách hiện thực trên Claude Code

| # | Bất biến | Hiện thực |
|---|---|---|
| 1 | **Tách role**: Supervisor = governance, Lead = technical owner, Peer = một bounded outcome | 3 definition; `tools:` của Supervisor không có `Agent/Edit/Write`; Peer không có `Agent`; chỉ Lead có `Agent(peer)` |
| 2 | **Bộ nhớ riêng theo role**, auth/skills/plugins chung | Lead `memory: local` → `.claude/agent-memory-local/lead` (không commit); Supervisor `memory: user` → `~/.claude/agent-memory/supervisor`, một file mỗi workspace; Peer **không** memory (memory `peer` dùng chung mọi instance sẽ phá lane mù); Supervisor chạy ngoài checkout của mọi Lead nên transcript tách, không đụng index; `~/.claude` chung |
| 3 | **Một source of truth cho topology; can thiệp quay về trạng thái chung của Lead** | Mỗi root một Lead, Lead là native team lead duy nhất của team mình; Supervisor là session ngoài mọi team; tin từ ngoài team tới Peer chỉ đi qua hộp thư `slp-mail` và server **tự cc Lead**, Peer chỉ trả lời, đổi hướng do Lead gửi (`D19`); không nested team; Lead không ghi ra ngoài root đã `SLP-REGISTER` (`D14`) |
| 4 | **Write ownership rõ** | mỗi moving scope một writer + commit lease; nhiều writer song song = Lead cấp worktree riêng mỗi writer, contract cho shared interface phải có trong brief trước |
| 5 | **Candidate + evidence, không phải DONE** | handoff 6 ô: `Candidate` = SHA + base, `Scope`, `Verification` (command + output thật), `Unknown/risk`, `Ownership`; Lead bắt buộc một dòng `ACCEPT <sha>` / `REJECT <sha> — finding` |
| 6 | **Supervisor không giành quyền Lead; quyền được giao phải có nguồn** | output `DRIFT` / `ESCALATE` / `NOTE`, và `RULING S#` chỉ khi `CLAUDE.md` workspace § *Supervisor được quyết* có mã đó — Lead từ chối ruling không mã (Lab 12); `from` do server `slp-mail` gán theo process nên authority đọc ở `from`, hook chặn Bash giả `from`; định nghĩa "Lead healthy" cụ thể; unhealthy → escalate, vẫn không điều khiển Peer |
| 7 | **Quyền chất vấn tách khỏi quyền sửa; phản biện là quyền, không phải nghĩa vụ** | brief có `Premise`: ràng buộc `bắt buộc` phải có nguồn (Human / `CLAUDE.md`), lựa chọn `đang dùng` Peer được hỏi lại (`D17` soi nguồn); Peer đọc được scope người khác, sửa thì không → `DEPENDENCY_REQUEST`; Lead xếp mỗi `REOPEN` vào một trong ba ô, không thưởng tranh biện; đổi quyết định phải lan tới plan + owner bị ảnh hưởng + Human (`Premise đổi` / `Bất đồng còn mở` dưới verdict) |

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

Windows (PowerShell 5.1+ hoặc pwsh 7, không cần `python3`/`node`):

```powershell
irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1 | iex                                               # project
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1))) -Global                # global
$env:SLP_REF='v0.1.0'; irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1 | iex                        # pin version
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1))) -Dir C:\path\to\repo    # repo khác
```

Installer làm đúng 6 việc và ghi lại trong `.claude/slp-manifest.json`:

| Việc | Hành vi |
|---|---|
| `.claude/agents/lead.md`, `peer.md`, `supervisor.md` | copy; file cũ khác nội dung → backup vào `.claude/backups/slp-<timestamp>/agents/` (`--force` để bỏ backup) |
| `.claude/skills/{goal-griller,xia,sequence-execution-plan,prompt-leverage,smart-commits}/` | copy cả thư mục; khác nội dung → backup vào `.claude/backups/slp-<timestamp>/skills/` |
| `.claude/settings.json` | **merge**: thêm `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` và `teammateMode=in-process` nếu chưa có; key khác giữ nguyên |
| `.claude/slp-supervisor.settings.json` | copy; dùng qua `--settings` cho Supervisor: `Read(//**)` + sandbox Bash (chỉ ghi cwd/`$TMPDIR`) + hook chặn `Write`/`Edit` ngoài memory của chính nó → đọc mọi file, chỉ sửa memory mình |
| `CLAUDE.md` | chỉ tạo từ template nếu **chưa có**; có rồi thì không đụng |
| validate | `claude plugin validate` cho `.claude/agents` và `.claude/skills` nếu có lệnh `claude` |

Yêu cầu: `curl`, `tar`, `python3` **hoặc** `node` (Windows `install.ps1`: chỉ cần PowerShell). Claude Code ≥ 2.1 (Agent Teams experimental).

## Cập nhật

Chạy lại installer đúng kiểu đã cài (xem kiểu và bản đang dùng: `grep '"version"'
.claude/slp-manifest.json`, hoặc `~/.claude/slp-manifest.json` nếu cài `--global`):

```bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash                 # project
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash -s -- --global  # global
```

```powershell
irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1 | iex                                  # project
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.ps1))) -Global   # global
```

Agent/skill bị ghi đè; file anh đã tự sửa được backup vào `.claude/backups/slp-<timestamp>/` để chép lại phần riêng.
`settings.json` chỉ thêm key còn thiếu, `CLAUDE.md` giữ nguyên. Session `claude --agent …` đang mở
dùng bản cũ tới khi thoát — mở lại sau khi cập nhật.

**Từ ≤ 0.4.x lên 0.5.0** — Supervisor không còn chạy trong worktree:

```bash
# 1. (tuỳ chọn) giữ memory cũ — làm TRƯỚC khi gỡ worktree
mkdir -p ~/.claude/agent-memory/supervisor
cp ../<repo>-supervisor/.claude/agent-memory-local/supervisor/MEMORY.md ~/.claude/agent-memory/supervisor/<repo>.md
# 2. gỡ worktree cũ của Supervisor
git worktree remove ../<repo>-supervisor
# 3. chạy lại ở thư mục trung lập, với settings mới (đọc mọi file, chỉ sửa memory của chính nó)
mkdir -p ~/slp-supervisor && cd ~/slp-supervisor
claude --agent supervisor --name supervisor --settings <repo>/.claude/slp-supervisor.settings.json
```

Lead chạy cùng permission mode với Supervisor (không `--dangerously-skip-permissions`), nếu không
message giữa hai bên bị hold. Chuyển sang workspace nhiều repo: cài `--global`, đặt
`templates/WORKSPACE.CLAUDE.template.md` thành `<workspace>/CLAUDE.md`, mỗi repo một Lead
`--name lead-<repo>` — chi tiết `docs/SETUP.md` §10.

## Gỡ

```bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.sh | bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.sh | bash -s -- --global
```

```powershell
irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.ps1 | iex
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/phucanh08/alp-claude/main/uninstall.ps1))) -Global
```

Uninstaller đọc manifest và gỡ **đúng những gì đã cài**: agent files; skill dirs; chỉ các key trong
`settings.json` do SLP thêm (xóa file nếu SLP tạo và giờ rỗng); `CLAUDE.md` chỉ khi SLP tạo **và**
chưa ai sửa (so sha256). Memory `.claude/agent-memory-local/{lead,supervisor}` (và `~/.claude/agent-memory/supervisor`
khi gỡ `--global`) giữ lại, `--force` mới xóa. Không có manifest → từ chối, trừ `--force` (khi đó chỉ gỡ 3 agent file + 7 skill dir).

## Dùng

```bash
cd <repo root>
# 1. Điền CLAUDE.md: contract boundaries, lệnh test, path cấm sửa, external side-effect policy.
# 2.
claude --agent lead --name lead          # header phải hiện @lead
# 3. (tuỳ chọn) Supervisor — terminal khác, thư mục trung lập, đọc mọi file, sandbox chặn ghi:
mkdir -p ~/slp-supervisor && cd ~/slp-supervisor
claude --agent supervisor --name supervisor --settings <repo root>/.claude/slp-supervisor.settings.json
# 4. (tuỳ chọn) Hộp thư slp-mail — Supervisor hỏi được Peer, anh nhắn từ CLI, from theo process:
python3 <repo root>/.claude/slp-mail/slp_mail.py mcp-config lead > ~/.slp-lead.mcp.json      # tương tự cho supervisor
claude --agent lead --name lead --mcp-config ~/.slp-lead.mcp.json --settings <repo root>/.claude/slp-mail.settings.json
python3 <repo root>/.claude/slp-mail/slp_mail.py send --to lead "…"                           # anh: from human
```

Workspace nhiều repo (`project-a-workspace/{backend,webadmin,webclient,mobileapp,service-a…}`):
cài `--global`, đặt `templates/WORKSPACE.CLAUDE.template.md` thành `project-a-workspace/CLAUDE.md`
(bảng part ↔ Lead + cross-repo contract), mỗi repo một Lead `--name lead-<repo>`, một Supervisor ở
thư mục trung lập nghe tất cả (kể cả Lead của workspace khác). Chi tiết và monorepo: `docs/SETUP.md` §10.

Lead nhận task từ Human, chẻ việc, spawn Peer bằng `Agent` với `subagent_type: peer` **và một
`name`** (named call = teammate; có `isolation` = rơi về ordinary subagent). Peer commit local,
handoff 6 ô (candidate SHA + base); Lead `git diff base sha` rồi `ACCEPT`/`REJECT`. Supervisor
(nếu chạy) nhận `SLP-REGISTER` + checkpoint từ từng Lead, kiểm Git object (`git -C <root>`) +
transcript, gửi `DRIFT @<lead>` khi lệch.

Không dùng `claude -p` (teammate cần interactive session). Không dùng
`--dangerously-skip-permissions` cho lab đầu.

**Hướng dẫn dùng hằng ngày + 7 case thực tế** (prompt mẫu, cách đọc `ACCEPT`/`REJECT`/`BLOCKED`,
Supervisor, lỗi hay gặp): [`docs/USAGE.md`](docs/USAGE.md).

Luồng một task đi qua phase nào, skill nào, gate nào: gõ `/ask-alp` (router, Lead/Peer gọi được
qua `Skill`); bản dài trong `skills/ask-alp/references/workflow.md`.

## Skills theo phase

Năm skill viết lại từ [`hoangnb24/skills`](https://github.com/hoangnb24/skills/tree/main/plugins/khuym/skills)
(plugin `khuym`, gốc cho Codex) sang Claude Code + SLP: bỏ `/goal`, hook Codex, DeepWiki/Exa;
thêm ánh xạ vào Task Contract, brief 14 trường, handoff 6 ô, luật một writer, không push.

| Skill | Phase | Vào → Ra |
|---|---|---|
| `goal-griller` | intake | prompt mơ hồ → **Task Contract** 6 ô; chưa đủ ô thì không giao writer |
| `xia` | recon | câu hỏi → research brief nhãn Local/Upstream/Docs/Inference, trong handoff 6 ô |
| `sequence-execution-plan` | sequence | contract + brief → work item, dependency, Now/Next/Later, **writer lease** (Now ≤1 writer/checkout) |
| `prompt-leverage` | brief | work item → **brief 14 trường**; trung lập cách làm, có ruling boundary, `Premise` tách ràng buộc có nguồn khỏi lựa chọn đang dùng, không seed verdict; `scripts/augment_prompt.py` nháp khung |
| `smart-commits` | commit gate | working tree → commit logic trong owned scope, **không push**, block Candidate `base..head` |

Một skill **phương pháp**, không gắn phase hay disposition — chỉ bắt buộc khi brief khai
`Required skills`:

| Skill | Loại việc | Vào → Ra |
|---|---|---|
| `bug-loop` | bug, test đỏ không rõ lý do, chậm đi | loop đỏ được → repro tối giản → 3–5 giả thuyết falsifiable → instrument → fix + regression test có **proof level** (L2 RED → GREEN, L3 thêm mutation). Read-only dừng ở Phase 4. Adapt từ [`mattpocock/skills`](https://github.com/mattpocock/skills/tree/main/skills/engineering/diagnosing-bugs) `diagnosing-bugs` (MIT) + [`alp-code`](https://github.com/phucanh08/alp-code/tree/main/skills/test-quality-guard) `test-quality-guard` |

Không có ghế `Special`: specialist là skill của Peer, không phải ghế mới — authority, lifecycle,
memory, acceptance của nó y hệt Peer. Luật test chung (oracle độc lập, lát dọc, mock ở rìa hệ
thống, không làm xanh bằng mọi giá, proof level) nằm trong `peer.md`, không cần skill.

Năm skill này **không gọi tên ghế**: chúng nói bằng từ vựng authority (*người yêu cầu* / *người
giao việc* / *người nhận việc* / *người quan sát*) và điều kiện dùng (có kênh hỏi người yêu cầu,
sở hữu topology, có write authority…). Ánh xạ ghế ↔ từ vựng, luồng chính, on-ramp và bảng "ghế
nào cấm skill nào" nằm ở một chỗ duy nhất: router **`ask-alp`** (`skills/ask-alp/SKILL.md`, bản
dài `references/workflow.md`). Nhờ vậy đổi ghế, đổi tên agent hay dùng skill ngoài SLP không phải
sửa skill. Skill không cấp authority.

## Khi nào không dùng SLP

- Sửa nhỏ, seam rõ, một người đọc diff là đủ → một session thường; SLP là chi phí, không phải
  đức tính. Lead vẫn được tự viết (`LEAD-WROTE`), nhưng mở Lead + Supervisor cho một dòng sửa là
  ceremony.
- Việc cần feedback Human liên tục (cảm giác game, UI/UX, chỉnh tay theo mắt) → không giao bounded
  outcome; Peer không có kênh hỏi Human giữa lượt, và tin gửi Peer đang chạy chỉ tới khi nó idle
  (Lab 11).
- Cần tách khi: nhiều owner viết song song, có thứ phải bảo vệ (tiền, auth, schema, contract giữa
  repo), hoặc Human không đọc được hết diff trong ngày.

## Better-SLP — sửa chính SLP bằng gì

Đánh giá một task không bằng số lần Peer phản biện hay số `DRIFT`, mà bằng **chuỗi thay đổi**:
Lead biết gì lúc giao → can thiệp kịp không → Peer phát hiện thêm gì → evidence có đủ đổi nhận
định không → quyết định mới tới owner nào → kết quả cuối đổi gì. Lead ghi một dòng chuỗi này mỗi
task vào memory; Supervisor ghi `patterns.md` theo outcome (`REOPEN` nào đổi được quyết định,
Reviewer nào ra finding đổi verdict, `DRIFT` nào tới muộn, nghi thức nào chỉ đốt token). Sửa
instruction từ đó — kể cả **bỏ** cơ chế — và đừng tối ưu chỉ số hoạt động: "ba lần Peer bắt lỗi"
không suy ra "tăng phản biện gấp đôi".

## Cấu trúc repo

```text
agents/lead.md              Lead — framing, delegation, review, acceptance (ACCEPT/REJECT)
agents/peer.md              Peer — bounded co-worker; disposition trong brief; handoff = candidate
agents/supervisor.md        Supervisor — governance; session riêng; 1..N Lead; DRIFT / ESCALATE / NOTE
skills/<name>/SKILL.md      5 skill theo phase + bug-loop (+ references/, scripts/)
skills/ask-alp/             router: ghế ↔ từ vựng authority, luồng, on-ramp, bảng cấm; references/workflow.md
templates/CLAUDE.template.md  khung repo-specific contract
templates/WORKSPACE.CLAUDE.template.md  khung workspace nhiều repo: part ↔ Lead, cross-repo contract
templates/settings.json     env + teammateMode
templates/slp-mail.settings.json  hook PreToolUse chặn Bash giả `from` (Lead dùng qua --settings khi bật hộp thư)
mcp/slp-mail/slp_mail.py    hộp thư MCP + CLI, một file Python stdlib: from theo process, tự cc Lead, log chung; selftest
mcp/slp-mail/README.md      cách chạy, tool, ba luật server, giới hạn
docs/SETUP.md               setup chi tiết + cơ chế runtime cần biết
docs/labs/README.md         mục lục lab (tầng 1): đo gì, trạng thái, lab đã đổi gì
docs/labs/common.md         quy ước chung: ràng buộc cứng, đọc transcript, chạy headless
docs/labs/lab-NN-*.md       mỗi lab một file: kết luận nhanh → quy trình → ghi chú lần chạy
docs/USAGE.md               hướng dẫn dùng hằng ngày + case thực tế
docs/WORKFLOW.md            con trỏ → skills/ask-alp/references/workflow.md
install.sh / uninstall.sh
VERSION
```

## Lab

Mọi lab dưới đây đã chạy thật, tất cả PASS — mỗi lab đo một cơ chế bằng Git object + transcript:

| Nhóm | Lab | Đo |
|---|---|---|
| Nền | 1–4 | chuỗi Lead → Peer → commit → accept; `BLOCKED`/`REOPEN_REQUEST` đúng tầng; lane mù; Reviewer đọc đúng SHA |
| Supervisor | 5–6 | session khác không có authority của Human; `supervisor.md` bắt drift, self-test, ESCALATE |
| Skill theo phase | 7 (7a → 7e) | năm skill, mỗi phase một bẫy; gate bắt buộc, `xia` có điều kiện |
| Nhiều Lead | 8, 8b | một Supervisor nghe nhiều Lead / nhiều workspace; đọc mọi file, chỉ sửa memory của chính nó |
| Phương pháp | 9, 9b | `bug-loop`: chẩn đoán read-only, proof L2/L3, `Required skills` + `D13` |
| Thiết kế | 10 | hai Architect mù thiết kế trước khi code; `LEAD-WROTE` cho contract; L3 tiền + state machine |

Mục lục, thứ tự chạy, lab đã đổi gì trong instruction: [`docs/labs/`](docs/labs/README.md).

## Tuning đã đưa vào `lead.md` từ lab

- v0.9.0 (theo bài gốc, Lab 12): **Supervisor của bài — bàn hướng đi với Human, hỏi được Peer,
  can thiệp trong quyền được giao — trên hộp thư `slp-mail`.** `mcp/slp-mail`: MCP server + CLI
  một file Python stdlib; `from` gán theo `SLP_SEAT` của process; tin tới `<lead>/<peer>` từ seat
  khác tự cc Lead; log chung theo `kind`; selftest 18/18; installer cài vào `.claude/slp-mail/`.
  `supervisor.md`: ba việc (nói với Human về kiến trúc bằng evidence xuyên phạm vi; drift; `RULING
  S#` chỉ trong danh sách *Supervisor được quyết* của `CLAUDE.md` workspace), hỏi Peer một câu qua
  hộp thư, không chuyển lời Human, `D19`; `D12`/`D16` đọc `log`. `lead.md`: § Hộp thư (authority
  đọc ở `from`; `Monitor` trên log thay poll; cc từ ngoài team → contract/plan trước; checkpoint
  theo `kind`), ruling `S#` thành `Premise: bắt buộc` có nguồn, ruling không mã → hỏi lại;
  `tools:` thêm `Monitor, mcp__slp-mail__*` (frontmatter loại MCP tool nếu không ghi — Lab 12).
  `peer.md`: hộp thư `<seat>/<tên>`, `Monitor` sau `inbox` đầu (tin tới trong một tool call, Lab 12:
  2–15 s thay 7 phút), heartbeat qua `send(agent:)`, **không đổi việc theo tin `supervisor`/`human`
  gửi thẳng**. Template: `slp-mail.settings.json` (hook chặn Bash giả `from`, cũng thêm vào
  supervisor settings), `WORKSPACE.CLAUDE` § *Supervisor được quyết*. README: bất biến 3 và 6 viết
  lại. Lab 12 bước 1–3 PASS; bước 4 probe headless PASS (Supervisor thật dưới sandbox gửi/đọc được;
  mode thường cần `permissions.allow: mcp__slp-mail` — đã có trong template); **chưa chạy team thật**.
- v0.8.1 (yêu cầu Human, chưa có lab): **im lặng có hạn — quá 10 phút thì nhắn xuống**.
  `lead.md`: mỗi peer đang chạy một mốc 10 phút (`Bash` `sleep` chạy nền, arm lại sau mỗi tin từ
  peer); mốc nổ mà peer chưa nói gì → kiểm evidence rồi gửi `PING` định dạng cố định, arm lại
  5 phút; mốc thứ hai vẫn im → luật treo > 15 phút của v0.7.0; anti-pattern **chờ không hẹn giờ**.
  `peer.md`: nhận `PING` trong inbox → trả đúng một `HEARTBEAT`, rút nhịp. `supervisor.md`: cùng
  cơ chế với Lead — mốc 10 phút sau tin mở phiên/`DRIFT`, `PING` kèm evidence transcript/git,
  hai mốc im + transcript đứng → `ESCALATE`; `D16` kiểm thêm `PING` của Lead ở mốc 10 phút.
  Lệnh nền đánh thức session idle **chưa đo** (`docs/labs/README.md` § Chưa đo).
- v0.8.0 (bài [SLP trên vhlam.com](https://vhlam.com/article/agent-orchestration-multi-agent-slp),
  không phải lab): **tách ràng buộc khỏi lựa chọn, tách quyền chất vấn khỏi quyền sửa**.
  `lead.md`: brief thêm trường `Premise` — `bắt buộc:` phải có nguồn (Human / dòng `CLAUDE.md`),
  `đang dùng:` là lựa chọn của Lead hoặc lát trước mà Peer được hỏi lại (anti-pattern **cái dù
  thành luật**); mỗi `REOPEN_REQUEST` xếp vào một trong ba ô (đổi quyết định / phương án khác
  cũng đúng / không đáng gián đoạn) và Lead phải chất vấn ngược "cần redesign"; vòng phát hiện →
  quyết định → `Premise` brief kế + plan + owner bị ảnh hưởng + evidence trên SHA sẽ accept; Human
  sửa hướng giữa chừng → contract/plan trước, tin tới Peer chỉ khi idle; dưới verdict thêm
  `Premise đổi` / `Bất đồng còn mở`; checklist accept đòi điều kiện đo cho claim benchmark;
  Auditor = Reviewer với `Objective` là proof; memory ghi một dòng chuỗi thay đổi mỗi task.
  `peer.md`: đọc `Premise` (bắt buộc → giữ hoặc `BLOCKED`, đang dùng → chất vấn được); đọc
  scope người khác được, sửa thì không; phản biện là quyền không phải nghĩa vụ (tự xếp trước khi
  gửi `REOPEN`); dấu hiệu **đường vòng** (thêm cơ chế thứ hai bù cùng một mâu thuẫn → mở lại);
  điều kiện đo benchmark. `supervisor.md`: `D17` (`bắt buộc` không nguồn), `D18` (benchmark
  không ghi điều kiện / trùng tải lane khác), `patterns.md` là telemetry theo outcome.
  `goal-griller`: hàng `Constraint` + câu hỏi 3 tách yêu cầu thật khỏi cách đang làm;
  `prompt-leverage` 14 trường (`Required skills` thành thứ 15), `augment_prompt.py` sinh dòng
  `Premise`; `ask-alp`/workflow, `sequence-execution-plan`, template `CLAUDE.md`, `docs/USAGE.md`
  cập nhật theo. README: bất biến thứ 7, "Khi nào không dùng SLP", "Better-SLP". **Chưa có lab**
  cho v0.8.0 — xem `docs/labs/README.md` § Chưa đo.
- v0.7.0 (sự cố facepod, [issue #7](https://github.com/phucanh08/alp-claude/issues/7)): **Peer
  phải sống có tiếng** — `peer.md` thêm mục Heartbeat (định dạng cố định, mục tiêu mỗi 10 phút,
  không tool call nào > ~90s, số liệu ghi file ngay, vòng poll tự đọc inbox của mình).
  `lead.md`: trường `Model` **bắt buộc** kèm lý do một dòng và Agent call truyền `model:`
  (`inherit` chỉ là fallback khi quên); effort là của Human (`/effort`), Lead không đặt được;
  bảng chọn model theo loại việc; trigger **phải** chạy song song (gấp + ≥ 2 item độc lập →
  worktree mỗi writer; bước chờ Human/thiết bị tách riêng; brief ≤ 2 nhóm hành vi); Lead đếm chéo
  file evidence mỗi heartbeat, peer im lặng > 15 phút = treo. `sequence-execution-plan`: dấu hiệu
  chẻ thứ tư. `supervisor.md`: `D15` (thiếu model/lý do), `D16` (peer im lặng, Lead không kiểm).
  Lab 11 **PASS** (headless + interactive PTY): mọi luật ăn lần đầu, 0 nhắc; hai phát hiện
  runtime — **tin gửi peer đang chạy chỉ giao khi peer idle** (nằm inbox 7 phút) nên `peer.md`
  đổi sang "đọc inbox của mình mỗi vòng poll"; **headless `-p` không có teammate** (subagent
  thường, không heartbeat).
- v0.6.0: **skill phương pháp `bug-loop`** + trường brief tuỳ chọn `Required skills` (thứ 14, từ v0.8.0 là thứ 15).
  `peer.md` thêm luật test: oracle độc lập với implementation, lát dọc, mock chỉ ở rìa hệ thống,
  danh sách "làm xanh bằng mọi giá" là BLOCKING, ô `Verification` ghi proof level L1–L3.
  `lead.md` checklist accept đòi proof ≥ L2 cho claim hành vi; `D13` kiểm skill phương pháp chỉ
  khi brief khai; `ask-alp` thêm bảng theo loại việc. Không tạo ghế `Special`. Lab 9 + 9b **PASS**
  (writer và Scout mang `bug-loop`, L3, bác giả thuyết của người báo bằng evidence; 9b có
  `REJECT` vì test sống sót mutant và Supervisor chỉ kiểm `bug-loop` ở brief đã khai); sau lab `lead.md` thêm:
  không ghi skill gate vào `Required skills`, việc đụng tiền ghi thẳng L3. Lab 10 **PASS** (hai
  Architect mù → một đề xuất → `ACCEPT` sau 4 `REJECT` có repro); sau lab `lead.md` thêm: giữ
  ngôn ngữ của Human suốt phiên, anti-pattern **luật tự thêm** (luật chấp nhận/từ chối hành vi
  không có trong brief/ruling → hỏi Human trước khi REJECT theo nó).
- v0.5.0: **một Supervisor, nhiều Lead; không cần worktree** — Supervisor chạy ở cwd ngoài checkout
  của mọi Lead (gốc workspace hoặc thư mục trung lập), đọc bằng `git --no-optional-locks -C <root>`;
  `memory: user`, một file mỗi workspace; Lead đăng ký bằng `SLP-REGISTER`; output ghi `@<lead>`,
  healthy/`ESCALATE` tính riêng từng Lead; thêm `D14` (ghi ra ngoài root/scope đã đăng ký). `lead.md`
  có mục workspace nhiều repo: mỗi root một Lead `lead-<repo>`, cross-repo contract trong `CLAUDE.md`
  workspace là quyết định của Human, message giữa Lead chỉ mang fact có SHA. Lab 8 PASS.
- Lab 7e chạy lại trên v0.4.5: PASS. Lead tự quyết là cần recon rồi giao Scout `xia` — lần đầu
  gate recon kích hoạt mà không phải do luật ép.
- v0.4.5: **`xia` là gate có điều kiện**, không bắt buộc mọi lượt Lead — Lead tự quyết việc có cần
  recon hay không (vùng lạ, không đếm được call site, boundary chưa rõ chủ); đã quyết là cần thì
  mới bắt buộc qua `xia` hoặc Scout. `D13` không fire chỉ vì Lead đọc file. Nới lại v0.4.4 theo
  ruling của Human; bốn gate còn lại vẫn bắt buộc vô điều kiện.
- v0.4.4: tách **bootstrap** khỏi **recon** trong `lead.md` — đọc `CLAUDE.md`/`git log`/cây file
  không cần skill, nhưng đọc code để trả lời câu hỏi mở của task là recon và phải `xia` hoặc giao
  Scout; `D13` kiểm đúng chỗ đó. Lộ ra ở Lab 7e: Lead đọc `lib/` 36 file, ra 5 phát hiện + 4
  ruling, 0 `Skill xia`, Supervisor vẫn ghi no drift. **Siết quá tay — nới lại ở v0.4.5.**
- v0.4.3: đóng hai gap Lab 7d — bảng gate của `lead.md` + `peer.md` nói rõ bốn disposition
  (`Scout`/`Architect` → `xia`; write → `smart-commits`; **Reviewer miễn skill**, thay bằng ràng
  buộc đọc theo SHA), `D13` không fire nhầm vào Reviewer; `D5` kiểm cả Bash ghi file chứ không
  chỉ tên tool `Edit`/`Write`.
- v0.4.2: **gọi skill ở gate là bắt buộc** (đảo quyết định #2 của v0.4.1, theo yêu cầu Human):
  `lead.md` có bảng gate → skill với điều kiện bắt buộc, `prompt-leverage` bắt buộc cho *mọi*
  brief; `peer.md` bắt buộc `xia` trước khi đọc và `smart-commits` trước commit đầu; skill không
  load được → nói với Human / `BLOCKED`, không làm bằng trí nhớ; `supervisor.md` thêm `D13` để
  kiểm bằng transcript. Lab 7d PASS: Lead 3 skill call đúng gate (7c: 0), writer
  `smart-commits`, Supervisor kiểm `D13` bằng số dòng transcript.
- v0.4.1: chốt ba câu hỏi mở sau Lab 7c — `lead.md`: Reviewer trigger không có ngoại lệ (ruling
  chốt hình dạng, Reviewer kiểm diff); gọi `Skill` là tuỳ chọn, hành vi ở gate mới được chấm;
  tính từ mơ hồ → hỏi Human ở intake, không giao Scout đo thay. `goal-griller`: cùng dòng đó ở
  bước 3 + anti-pattern.
- v0.4.0: skill độc lập với ghế — bỏ mục "Ai dùng" và tên Lead/Peer/Supervisor/Human khỏi 5 skill,
  thay bằng từ vựng authority + điều kiện dùng; thêm router `ask-alp` (model-invocable, Lead/Peer
  gọi qua `Skill`) giữ ánh xạ ghế và bảng cấm; `docs/WORKFLOW.md` dời vào
  `skills/ask-alp/references/workflow.md`; `lead.md` rút bảng skill thành thứ tự mặc định + con trỏ
  `ask-alp`. Lab 7c PASS: Lead không gọi skill nào qua `Skill` nhưng intake/brief/accept vẫn đúng; Scout gọi `xia`, writer gọi `smart-commits`; Supervisor bắt `DRIFT D9` (Reviewer trigger #2) — câu hỏi mở ghi ở `docs/labs/lab-07-runs.md`.
- v0.3.0: thêm mục "Skills theo phase" vào `lead.md`/`peer.md`, dòng skills vào template
  `CLAUDE.md`; installer/uninstaller quản `.claude/skills/`. Lab 7 PASS: `goal-griller` hỏi đúng một
  câu, `prompt-leverage` ra brief 13 trường (nay 14) có ruling, `smart-commits` 2 commit + 0 push; kiểm hook
  git đổi sang `git rev-parse --git-path hooks` vì plugin hook chặn path thư mục git.
- v0.2.x: `memory: local` (Lab 6: chạy được với `--agent`); ô `Snapshot` → `Candidate` có base SHA
  và verdict line `ACCEPT`/`REJECT` (Lab 6: Lead dùng đúng, kể cả khi Human ép chấm mù → Lead từ
  chối ra verdict trên lời khai); mục "Supervisor — session khác, không phải Human" (Lab 6: Lead
  từ chối mồi D12 và báo Human "Supervisor đang nhân danh anh"). Worktree-per-writer: Lab 7c PASS (`.worktrees/lab7-01`, checkout chính đứng yên).

- Bỏ `TaskCreate/TaskGet/TaskList/TaskUpdate` khỏi `tools:` — runtime 2.1.x không có; task
  identity + owner đi trong brief.
- Brief trung lập về *cách làm* nhưng phải chứa **ruling hướng đi** cho boundary trong
  `CLAUDE.md` trước khi Peer viết (Lab 4: Lead từng giao Peer "tự quyết cho nhất quán" ở Dockerfile
  allowlist — kết quả đúng nhưng ruling muộn).

## Tham chiếu

- Agent Teams: https://code.claude.com/docs/en/agent-teams
- Custom subagents / `--agent`: https://code.claude.com/docs/en/sub-agents
- Cross-session messaging: https://code.claude.com/docs/en/cross-session-messaging
