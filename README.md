# alp-claude — SLP trên Claude Code Agent Teams

Bộ cài **SLP** (Supervisor / Lead / Peer separation-of-judgment) cho Claude Code Agent Teams
native. Không cần Paseo. Một `install.sh`, một `uninstall.sh`, ba agent definition, **năm skill
theo phase + một skill phương pháp `bug-loop` + một router `ask-alp`**, template `CLAUDE.md` cho repo và cho workspace nhiều repo, và
5 lab đã chạy thật + 1 lab cho Supervisor definition.

```text
Human ────────────────────────────────────────────────────────┐
  ↓                                                           ↓
Lead session(s)  claude --agent lead --name lead[-<repo>]     Supervisor session (ngoài checkout mọi Lead)
  ↓  Agent(subagent_type=peer, name=...)               ←──    claude --agent supervisor --name supervisor
Peer teammate(s)  Engineer | Architect | Reviewer | Scout      1 Supervisor : N Lead; chỉ DRIFT/ESCALATE/NOTE

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
| 2 | **Bộ nhớ riêng theo role**, auth/skills/plugins chung | Lead `memory: local` → `.claude/agent-memory-local/lead` (không commit); Supervisor `memory: user` → `~/.claude/agent-memory/supervisor`, một file mỗi workspace; Peer **không** memory (memory `peer` dùng chung mọi instance sẽ phá lane mù); Supervisor chạy ngoài checkout của mọi Lead nên transcript tách, không đụng index; `~/.claude` chung |
| 3 | **Một source of truth cho topology** | Mỗi root một Lead, Lead là native team lead duy nhất của team mình; Supervisor là session ngoài mọi team, runtime không cho session khác reach teammate của Lead; không nested team; Lead không ghi ra ngoài root đã `SLP-REGISTER` (`D14`) |
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

Installer làm đúng 6 việc và ghi lại trong `.claude/slp-manifest.json`:

| Việc | Hành vi |
|---|---|
| `.claude/agents/lead.md`, `peer.md`, `supervisor.md` | copy; file cũ khác nội dung → backup `.bak-<timestamp>` (`--force` để bỏ backup) |
| `.claude/skills/{goal-griller,xia,sequence-execution-plan,prompt-leverage,smart-commits}/` | copy cả thư mục; khác nội dung → backup thư mục `.bak-<timestamp>` |
| `.claude/settings.json` | **merge**: thêm `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` và `teammateMode=in-process` nếu chưa có; key khác giữ nguyên |
| `.claude/slp-supervisor.settings.json` | copy; dùng qua `--settings` cho Supervisor: `Read(//**)` + sandbox Bash (chỉ ghi cwd/`$TMPDIR`) + hook chặn `Write`/`Edit` ngoài memory của chính nó → đọc mọi file, chỉ sửa memory mình |
| `CLAUDE.md` | chỉ tạo từ template nếu **chưa có**; có rồi thì không đụng |
| validate | `claude plugin validate` cho `.claude/agents` và `.claude/skills` nếu có lệnh `claude` |

Yêu cầu: `curl`, `tar`, `python3` **hoặc** `node`. Claude Code ≥ 2.1 (Agent Teams experimental).

## Cập nhật

Chạy lại installer đúng kiểu đã cài (xem kiểu và bản đang dùng: `grep '"version"'
.claude/slp-manifest.json`, hoặc `~/.claude/slp-manifest.json` nếu cài `--global`):

```bash
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash                 # project
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash -s -- --global  # global
```

Agent/skill bị ghi đè; file anh đã tự sửa được backup `*.bak-<timestamp>` để chép lại phần riêng.
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

**Hướng dẫn dùng hằng ngày + 6 case thực tế** (prompt mẫu, cách đọc `ACCEPT`/`REJECT`/`BLOCKED`,
Supervisor, lỗi hay gặp): [`docs/USAGE.md`](docs/USAGE.md).

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

Mười lab đã chạy thật, tất cả PASS — mỗi lab đo một cơ chế bằng Git object + transcript:

| Nhóm | Lab | Đo |
|---|---|---|
| Nền | 1–4 | chuỗi Lead → Peer → commit → accept; `BLOCKED`/`REOPEN_REQUEST` đúng tầng; lane mù; Reviewer đọc đúng SHA |
| Supervisor | 5–6 | session khác không có authority của Human; `supervisor.md` bắt drift, self-test, ESCALATE |
| Skill theo phase | 7 (7a → 7e) | năm skill, mỗi phase một bẫy; gate bắt buộc, `xia` có điều kiện |
| Nhiều Lead | 8, 8b | một Supervisor nghe nhiều Lead / nhiều workspace; đọc mọi file, chỉ sửa memory của chính nó |

Mục lục, thứ tự chạy, lab đã đổi gì trong instruction: [`docs/labs/`](docs/labs/README.md).

## Tuning đã đưa vào `lead.md` từ lab

- v0.6.0: **skill phương pháp `bug-loop`** + trường brief tuỳ chọn `Required skills` (thứ 14).
  `peer.md` thêm luật test: oracle độc lập với implementation, lát dọc, mock chỉ ở rìa hệ thống,
  danh sách "làm xanh bằng mọi giá" là BLOCKING, ô `Verification` ghi proof level L1–L3.
  `lead.md` checklist accept đòi proof ≥ L2 cho claim hành vi; `D13` kiểm skill phương pháp chỉ
  khi brief khai; `ask-alp` thêm bảng theo loại việc. Không tạo ghế `Special`. Lab 9 + 9b **PASS**
  (writer và Scout mang `bug-loop`, L3, bác giả thuyết của người báo bằng evidence; 9b có
  `REJECT` vì test sống sót mutant và Supervisor chỉ kiểm `bug-loop` ở brief đã khai); sau lab `lead.md` thêm:
  không ghi skill gate vào `Required skills`, việc đụng tiền ghi thẳng L3.
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
  câu, `prompt-leverage` ra brief 13 trường có ruling, `smart-commits` 2 commit + 0 push; kiểm hook
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
