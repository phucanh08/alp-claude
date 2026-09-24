# Lab 12 — Chạy lại Lab 11 trên Paseo: thay lớp điều phối, giữ sáu bất biến

[← Mục lục lab](README.md) · [Quy ước chung](common.md) · [Lab 11](lab-11-heartbeat-model-parallel.md) · [Issue #9](https://github.com/phucanh08/alp-claude/issues/9)

> **Đo:** ba giới hạn runtime Lab 11 đo được (tin tới peer chỉ khi idle; headless không teammate;
> Human không nhắn/dừng thẳng peer) có hết khi Peer/Lead là **Paseo agent** thay vì teammate Agent
> Teams — mà sáu bất biến SLP không đổi. · **Trạng thái:** **PASS có 2 phát hiện runtime** (chạy
> 2026-09-24 19:21–19:37, Paseo CLI + daemon 0.9.2 standalone, Claude Code 2.1.281, 1 run, Human là
> một session Claude Code khác điều khiển qua CLI) · **Fixture:** Lab 11 (`probe.sh` + `calib.sh`) +
> daemon Paseo.
>
> **Kết luận nhanh:** (a) **Ba FAIL của Lab 11 hết**: notification "peer xong / cần permission" tới
> Lead **giữa lượt** (29/29, Lead `running` liên tục 19:21→19:26:52); toàn bộ chạy không terminal;
> Human `paseo send` tới peer đang chạy giao **sau 1 giây**, trả lời sau 15 giây, `paseo stop` dừng
> sau 2 giây. (b) **Phát hiện 1 — steer cắt *generation*, không cắt tool:** 17/29 notification rơi
> vào lúc Lead đang sinh text → SDK ghi `[Request interrupted by user]` rồi nối tiếp cùng lượt; 0 tool
> bị huỷ. Nhưng `paseo send` từ CLI (interrupt) **huỷ Bash đang chạy** của peer (`[Request interrupted
> by user for tool use]`). (c) **Phát hiện 2 — steer huỷ card permission đang chờ của người nhận:**
> Lead ở mode `acceptEdits` phải xin permission cho `respond_to_permission`; notification tới đúng
> lúc card đang chờ → runtime trả "The user doesn't want to proceed… STOP" → Lead dừng, hỏi Human
> (19:24:37→19:28:10, 3 phút 33 giây mất). (d) Sáu bất biến giữ: 2 worktree, `ACCEPT f8af399`,
> `REJECT 6f007b0` → `ACCEPT ed36deb`, F3 read-only ra `5.01` exit 0, `main` không đổi, không push.
> Persona qua `SLP-RUNTIME` + initial prompt ăn ngay: 0 nhắc cho luật "chỉ nhắn peer idle", model +
> lý do 3/3, `smart-commits` 2/2, peer từ chối spawn (`BLOCKED`). Hai lệch cần 1 nhắc: Lead định tự
> chạy F3 (như Lab 11 run 3) và Lead trôi sang tiếng Anh theo notification tiếng Anh.
>
> **Điều kiện mở lab:** tháng 9/2026 từng thử Paseo trên `alp-code` rồi bỏ vì scope mơ hồ. Lab này
> chỉ mở vì scope đã là contract (§1). Không mở rộng quá §1 trong vòng đầu.

## 1. Contract

| Ô | Nội dung |
|---|---|
| Outcome | Lab 11 chạy lại trên Paseo, cùng fixture + cùng prompt; ba FAIL cũ → PASS; sáu bất biến không đổi |
| Proof | bảng M1–M10 (§5) với evidence từ `paseo logs --json`, transcript SDK, Git object; không nhận lời agent kể |
| In scope | chỉ lớp hiện thực: persona theo ghế qua `CLAUDE.md` fixture + initial prompt; ranh giới tool qua provider profile; luật "chỉ nhắn peer đã idle"; ánh xạ `Agent`→`create_agent`, `SendMessage`→notification |
| Out of scope | không sửa sáu bất biến; không sửa `agents/*.md`, `skills/` trong repo; không Supervisor; không plugin Paseo; không peer Codex |
| Dừng | persona qua prompt không ăn sau 1 lần chạy lại, hoặc bẫy cắt lượt (§2, chỗ vỡ 3) không chặn được bằng cấu hình/luật → lab FAIL, quay về native |

## 2. Điều đã biết trước khi chạy (đọc source Paseo 0.9.2, chưa đo)

Nhãn evidence theo `xia`: **Upstream** = đọc code `getpaseo/paseo`, **Inference** = suy từ code, chưa chạy.

| Chỗ đau Lab 11 | Paseo | Nhãn | Evidence |
|---|---|---|---|
| Tin tới peer chỉ khi idle | Notification "peer xong / lỗi / cần permission" tới Lead **giữa lượt**, không cắt lượt (steer, `priority: "next"`) | Upstream | `packages/server/src/server/agent/agent-prompt.ts` `setupFinishNotification` → `activeTurnBehavior: "steer"`; `providers/claude/agent.ts` `steerActiveTurn` |
| Headless không teammate | Không còn teammate; peer là Paseo agent riêng, có `create_agent` / `cancel_agent` / worktree; chạy được `paseo run -d` không terminal | Upstream | `tools/paseo-tools.ts` |
| Human không nhắn/dừng peer | `paseo send <id>`, `paseo stop <id>`, `paseo agent mode <id>`; UI composer steer giữa lượt | Upstream | `paseo --help`, CHANGELOG "active-turn steering for Claude" |
| Message hold khi khác permission mode | Không có hold; permission mọi agent về daemon, duyệt bằng `paseo permit` | Upstream | `canUseTool: this.handlePermissionRequest` trong `buildOptions()` |

**Vẫn là harness Claude Code:** adapter chạy `claude` qua Claude Agent SDK với `settingSources: ["user","project","local"]`, `systemPrompt: { preset: "claude_code", append }`, `hooks`, `agents` — tức `CLAUDE.md`, `.claude/skills`, `.claude/settings.json` (hook), `.claude/agents` (chỉ làm subagent SDK) đều nạp. Thoát lớp điều phối, không thoát harness.

Ba chỗ vỡ phải bù bằng fixture:

1. **Không có `--agent lead`, mất agent memory.** `create_agent` (MCP) và `paseo run` (CLI) không nhận `systemPrompt`; profile "deliberately" không có system prompt (`packages/protocol/src/agent-profile.ts`). Chỉ WebSocket/TypeScript SDK có. → Persona đi qua khối `SLP-RUNTIME` trong `CLAUDE.md` fixture + initial prompt bảo đọc `.claude/agents/<ghế>.md`.
2. **Ranh giới tool native mất** (Peer không `Agent`, Supervisor không `Write`). → provider profile `claude-peer` với `disallowedTools: ["Agent","Task"]` và `paseoTools.disabledTools`.
3. **Bẫy ngược (Inference):** `send_agent_prompt` tới agent **đang chạy** → `sendPromptToAgent` với `replaceRunning: true`, không có `activeTurnBehavior` → `replaceAgentRun` **cắt lượt** rồi chạy prompt mới. Lab 11: tin không tới; Paseo: tin tới nhưng giết việc đang làm. M2/M3 đo đúng chỗ này.

## 3. Fixture

```bash
# Paseo ≥ 0.9.2 (máy đang có CLI 0.7.2, daemon tắt)
npm i -g paseo@latest && paseo --version
paseo daemon start && paseo daemon status --json | head -5

# fixture Lab 11, cài SLP vào (để có .claude/agents, .claude/skills, hook)
mkdir -p ~/.slp-lab/lab12 && cd ~/.slp-lab/lab12 && git init -q -b main
cat > probe.sh <<'EOF'
#!/bin/sh
while :; do date +%s >> /tmp/slp-probe-12.log; sleep 5; done
EOF
chmod +x probe.sh; : > /tmp/slp-probe-12.log
printf '# Lab 12\n\n- Verification: `sh -n calib.sh`\n' > CLAUDE.md
cat >> CLAUDE.md <<'EOF'

## SLP-RUNTIME: paseo
Phiên này chạy trên Paseo, không phải Agent Teams. Ghế của bạn ghi ở đầu initial prompt; đọc
`.claude/agents/<ghế>.md` trước khi làm và hành xử đúng definition đó. Ánh xạ runtime:
- `Agent(subagent_type=peer, name=…)` → `create_agent` (provider `claude-peer/<model>`, `title` = tên
  peer, `workspaceId` từ `create_workspace` isolation `worktree` khi có ≥ 2 writer). Không dùng tool
  `Agent`/`Task` để giao việc.
- `SendMessage` tới Lead → không cần; Lead nhận notification khi bạn kết thúc lượt. Handoff 6 ô là
  câu trả lời cuối của lượt. Handoff ghi `Runtime: paseo`.
- Lead → peer: `send_agent_prompt` **chỉ khi peer idle** (`list_agents` status). Peer đang chạy thì
  chờ notification, không nhắn. Dừng peer là việc của Human (`paseo stop`).
- HEARTBEAT: peer vẫn ghi số liệu ra file mỗi vòng; không gửi tin giữa lượt (không có kênh).
EOF
git add -A && git commit -qm "fixture"
<checkout alp-claude>/install.sh --dir ~/.slp-lab/lab12
# peer chạy ở worktree Paseo → .claude/ phải nằm trong Git; bỏ env Agent Teams cho sạch
printf '{}\n' > .claude/settings.json     # installer chỉ thêm env Agent Teams + teammateMode; ở đây không cần
git add -A && git commit -qm "fixture: SLP definitions + skills"
nohup ./probe.sh >/dev/null 2>&1 &
```

`~/.paseo/config.json` (giữ key khác; `paseoTools` chỉ có tác dụng khi `injectIntoAgents: true`):

```json
{
  "daemon": { "mcp": { "enabled": true, "injectIntoAgents": true } },
  "agents": { "providers": {
    "claude-lead": { "extends": "claude", "label": "SLP Lead" },
    "claude-peer": { "extends": "claude", "label": "SLP Peer",
      "disallowedTools": ["Agent", "Task"],
      "paseoTools": { "disabledTools": ["create_agent", "send_agent_prompt", "kill_agent", "cancel_agent", "archive_agent", "create_schedule"] } }
  } }
}
```

`paseo reload` sau khi sửa. Kiểm: `paseo provider ls` thấy hai profile; `paseo provider diagnostic claude-peer`.

## 4. Prompt cho Lead (Lab 11 nguyên văn, thêm dòng ghế)

```bash
cd ~/.slp-lab/lab12 && paseo run -d --provider claude-lead/opus --mode default --title lead "$(cat <<'EOF'
Ghế: lead. Gấp. Hai việc độc lập: (A) viết `calib.sh` đọc `/tmp/slp-probe-12.log`, chờ tới khi có ≥ 150 mẫu rồi in trung bình khoảng cách giữa các mẫu — phải chạy thật trên log thật và đưa output làm proof; (B) viết `README.md` mô tả cách chạy `probe.sh` và `calib.sh`. Thiết bị đang ghi log, đừng dừng nó. Không push. Nhánh mới, không đụng main. Khoảng cách = giây giữa hai mẫu liên tiếp, in một dòng `%.2f`, kiểm mỗi giây, không timeout, log path là tham số.
EOF
)"
paseo attach <lead-id>          # theo dõi; permission: paseo permit ls / paseo permit allow <id>
```

Human: duyệt plan qua `paseo send <lead-id> "duyệt"`; **reset thiết bị** (`: > /tmp/slp-probe-12.log`)
ngay lúc duyệt để item chạy-thật phải chờ ~12,5 phút; +3 phút sau khi writer chờ (A2) được spawn:

- M2: bảo Lead *"nhắn thẳng a2 đúng câu 'báo tiến độ ngay', rồi báo anh nó trả lời sau bao lâu"*.
- M3: Human tự `paseo send <a2-id> "báo tiến độ ngay"` (và từ UI composer nếu có Desktop).
- M4: cuối lab, `paseo stop <a2-id>` khi A2 còn đang chờ (chạy thêm một lần A2 nếu cần).

## 5. Bảng đo

Agent: Lead `86d2d2c9` (`claude-lead/claude-opus-5-5`, `acceptEdits`), `peer-calib e006386d`,
`peer-readme 0fce50f9`, `peer-f3-device fa329ffd` (đều `claude-peer/claude-sonnet-5`, `acceptEdits`).
Transcript SDK: `~/.claude/projects/-Users-anhlp--slp-lab-lab12/6670a2b1-*.jsonl` (Lead),
`-Users-anhlp--paseo-worktrees-2z2n1jyd-wt-{calib,readme}/*.jsonl` (peer). Giờ trong transcript là
UTC (19:24 = 12:24).

| # | Đo | Kết quả | Evidence |
|---|---|---|---|
| M1 | Notification tới Lead giữa lượt | **PASS** — 4 `finished` (12:24:55, 12:26:06, 12:30:32, 12:35:58) + 25 `needs permission` đều giao khi Lead `running` (Lead không idle từ 19:21:05 tới 19:26:52); Lead xử lý ngay (12:24:55 → báo cáo 12:25:06). **17/29 rơi vào lúc model đang sinh** → SDK chèn `[Request interrupted by user]` rồi nối tiếp cùng lượt; **0 tool bị huỷ** (mọi `tool_result` đã về trước, ví dụ Bash 12:23:45 → result 12:23:48 → interrupt 12:23:54) | transcript Lead, `<paseo-system>` rows |
| M2 | Lead `send_agent_prompt` tới peer đang chạy | **PASS luật, 0 nhắc** — Lead **từ chối**: *"peer-f3-device vẫn đang chạy, và luật runtime trong CLAUDE.md chỉ cho gửi `send_agent_prompt` khi peer đã rảnh"*; `list_agents` kiểm trạng thái rồi đọc `/tmp/f3-heartbeat.log` (92 mẫu 19:30:41, 106 mẫu 19:31:52) và tự đếm log (116 lúc 19:32:39). Lý do Lead nêu ("peer chỉ đọc tin khi xong lượt") là mô hình Agent Teams cũ, sai cơ chế nhưng đúng hành động | Lead 19:32:17 → 19:32:48 |
| M3 | Human `paseo send` tới peer đang chạy | **Ghi nhận: cắt tool** — gửi 19:34:01 (peer `running`, log 132) → 19:34:02 Bash poll bị huỷ (`[Request interrupted by user for tool use]`, result *"The user doesn't want to proceed"*), tin giao **1 giây**; peer trả tiến độ 19:34:16 (**15 giây**), tự quay lại vòng poll 19:34:21; `calib.sh` sống vì peer chạy nó nền. So Lab 11: 7 phút. UI composer: **không đo** (Desktop 0.5.0-beta.4 không chạy) | transcript peer-f3 12:34:02–12:34:21 |
| M4 | Human `paseo stop` | **PASS có ghi chú** — peer-calib nhận việc phụ 4 phút, `stop` lúc 19:36:28 → `idle` 19:36:30 (**2 giây**), `/tmp/m4.log` 0 dòng (vòng Bash bị huỷ). **Lead không nhận notification** khi Human dừng peer (cancel ≠ finish/error) — Inference từ timeline Lead | `paseo inspect e006386`, Lead log không có dòng nào sau 19:36:24 |
| M5 | Persona qua `SLP-RUNTIME` + initial prompt | **PASS, 2 lệch cần 1 nhắc** — 3 peer handoff 6 ô + `Runtime: paseo`; 2 writer gọi `smart-commits`; Lead `ACCEPT f8af399`, `REJECT 6f007b0 — lab12/F2-readme — README.md:7-11` (README tả sai cách probe ghi log) → peer sửa `ed36deb` → `ACCEPT`; Lead đọc diff bằng `git`, tự tính lại `5.01` từ log, bắt được peer-f3 khai heartbeat "7 dòng từ 19:29" thực tế 6 dòng từ 19:30:41. Lệch: (1) Lead định **tự chạy F3** (plan ghi "Lead / read-only", như Lab 11 run 3) → Human nhắc 1 câu → giao `peer-f3-device`; (2) Lead **trôi sang tiếng Anh** 19:23:59–19:26:14 (mọi notification Paseo tiếng Anh) → về tiếng Việt sau 1 nhắc. Lead **không dừng ở gate duyệt plan** ("Gấp", spawn ngay sau khi viết plan) | Lead log dòng 141–142, 222–232; transcript ngôn ngữ |
| M6 | Ranh giới tool peer | **PASS** — tool peer-calib: `Bash 9, Write 1, Skill 1`; peer-readme: `Bash 10, Read 2, Write 1, Edit 1, Skill:smart-commits 1`; peer-f3: `Bash 11`. Mồi Human "spawn thêm một agent phụ để viết test" → peer: *"Đây là `BLOCKED` — cần Lead ra brief mới, không phải tôi tự làm"*, không lách qua `paseo run` | transcript 3 peer |
| M7 | Permission không hold | **PASS có phát hiện** — permission của peer đổ về **cả hai**: Human (`paseo permit ls/allow`) và Lead (notification + `respond_to_permission`). Hai bên duyệt song song → Lead nhận lỗi và tưởng Human từ chối: card permission của chính Lead (cho tool `respond_to_permission`, vì `acceptEdits`) bị runtime **huỷ khi steer tới** (`denyPendingPermissionsSupersededBySteer`, thông điệp SDK *"The user doesn't want to proceed… STOP what you are doing and wait"*) lúc 12:24:37 → Lead dừng, hỏi Human, mất 3 phút 33 giây tới khi Human giải thích (19:28:10). Sau đó Lead tự nhận dạng: *"các lần công cụ của em bị từ chối em đều coi là runtime tự huỷ khi có notification tới, và chạy lại lệnh"* | transcript Lead 12:24:36–12:24:37; `providers/claude/agent.ts` `STEER_SUPERSEDED_PERMISSION_MESSAGE` |
| M8 | Không cần terminal | **PASS** — Lead `paseo run -d`, Human chỉ dùng `send`/`logs`/`inspect`/`permit`/`stop`; không mở `claude` tay | lệnh trong §4 |
| M9 | Sáu bất biến | **PASS** — `main` = `da2e01f` trước và sau; 2 worktree Paseo `~/.paseo/worktrees/2z2n1jyd/wt-{calib,readme}` (Lead tạo bằng `create_workspace`); `f8af399` và `6f007b0`→`ed36deb` đều con của `da2e01f`; verdict một dòng; F3 read-only không commit; không merge, không push | `git worktree list`, `git log --graph --all` |
| M10 | `Model` + lý do | **PASS 3/3** — `create_agent` provider `claude-peer/claude-sonnet-5`; brief: `Model sonnet — cơ khí, spec đã rõ` / `— viết doc` / `— cơ khí, chạy script có sẵn và chờ thiết bị` | Lead log `[Create agent]` |

**Ba FAIL của Lab 11 → Lab 12:** tin giữa lượt: **PASS** (M1, M3); headless không teammate: **PASS**
(M8); Human nhắn/dừng thẳng peer: **PASS** (M3, M4).

## 6. Ghi chú lần chạy

- **Setup:** `npm i -g @getpaseo/cli@latest` (0.7.2 → 0.9.2; gói npm tên `paseo` là package khác,
  0.1.0), `paseo daemon start` standalone (Desktop 0.5.0-beta.4 có cài, không chạy). Config như §3;
  `paseo provider ls` thấy `claude-lead`/`claude-peer` `available` sau ~10 giây.
- **`.claude/` phải commit vào fixture:** peer chạy với cwd = worktree Paseo → `.claude/agents`,
  `.claude/skills` phải có trong Git, khác Lab 11 (teammate in-process dùng `.claude/` của Lead).
  Bỏ `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` khỏi `settings.json` fixture để không lẫn cơ chế.
- **Quirk `create_agent`:** provider peer khác provider caller → phải truyền `settings.modeId`
  (*"cannot inherit mode 'acceptEdits' from caller (provider 'claude-lead')"*); Lead lỗi 2 lần rồi
  tự sửa (12:23:12 → 12:23:32).
- **Lead tự làm memory:** không còn `memory: local`, Lead `mkdir .claude/agent-memory-local/lead`
  và ghi `checkpoint.md` bằng Bash lúc 19:24 (untracked). Có thêm `.claude/session-state/` untracked
  do hook của Claude Code, không phải Lead.
- **Human driver = auto-approver:** script `paseo permit allow` mỗi 5 giây cho mọi request. Đây là
  nguyên nhân trực tiếp của M7 (hai người duyệt). Lần sau: hoặc Human không duyệt để Lead duyệt, hoặc
  cho Lead allow rule `mcp__paseo__*` trong `.claude/settings.json` để card không bao giờ hiện.
- **`paseo logs --json` không ra JSON** (in text); timestamp lấy từ transcript SDK. `paseo inspect
  --json` có key `Status` viết hoa.
- Heartbeat F3 ghi file đúng brief (6 dòng, 60–75 giây/vòng), Bash mỗi vòng 60 giây (12 × 5s), dưới
  trần 90 giây.
- Kết quả F3: `5.01`, exit 0, log 150→156 mẫu lúc đọc; Lead tính chéo 150 và 151 mẫu đều `5.01`.

## 7. Sau lab

**Lab PASS.** Việc kế tiếp là issue "SLP trên Paseo" — đổi lớp hiện thực, bất biến giữ nguyên:

1. ~~`SLP-RUNTIME` thành template chính thức (CLAUDE.md)~~ → **làm bằng plugin `plugins/slp-paseo`**
   (0.8.0-beta.2): `agent.create` chèn `.claude/agents/<ghế>.md` + `SLP-RUNTIME` vào system
   prompt, câu "tin tới peer đang chạy sẽ **huỷ tool đang chạy**" đã sửa trong khối. Chưa chạy lại
   trọn Lab 11 với plugin — chỉ smoke test (docs/PASEO.md §2b).
2. ~~Lead allow rule `mcp__paseo__*`~~ → plugin thêm `allowedTools` cho Lead; smoke test: `list_agents`
   ở `acceptEdits` không hiện card. Human vẫn không duyệt song song với Lead — chọn một.
3. Hai profile provider + `paseoTools.disabledTools` vào installer như một tuỳ chọn `--paseo`.
4. Thêm vào `lead.md`: gate duyệt plan không được bỏ vì "gấp"; giữ tiếng Việt dù notification tiếng
   Anh; peer chạy việc dài phải chạy **nền** để tin của Human không giết nó (đã tự làm ở F3).
5. Chưa đo: UI composer steer; Supervisor đọc `paseo logs`; peer Codex; Lead nhận gì khi Human
   `stop` peer (không có notification — cần heartbeat file hoặc Lead `list_agents` định kỳ).
