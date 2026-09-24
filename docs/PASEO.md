# SLP trên Paseo (bản beta) — dùng với Paseo Desktop

Bản beta chạy Lead/Peer là **Paseo agent** thay vì teammate của Claude Code Agent Teams. Sáu bất
biến SLP không đổi; chỉ lớp điều phối đổi. Bằng chứng: [Lab 12](labs/lab-12-paseo-runtime.md).
Tài liệu này là hướng dẫn thao tác với **Paseo Desktop**; dùng CLI thuần thì xem §3 của lab.

## 1. Yêu cầu

| Thành phần | Bản | Vì sao |
|---|---|---|
| Paseo Desktop | **≥ 0.9.x** (kiểm ở **Settings → About**) | steer giữa lượt cho Claude từ 0.5.0, profile từ 0.4.0, Lead trả lời permission của peer (`respond_to_permission`) từ 0.8.0, `paseoTools` theo provider có trong docs 0.9.2 — Lab 12 đo trên 0.9.2. Máy này Desktop đang 0.5.0-beta.4: **Settings → About → Check** để cập nhật |
| Claude Code CLI | ≥ 2.1 | Paseo chạy Claude qua Agent SDK, gọi binary `claude` trong PATH |
| SLP | `SLP_REF=beta` (xem README) | `VERSION` phải có `-beta.N` |

Desktop **tự kèm daemon** và tự cập nhật. Nếu máy đang chạy daemon standalone (`paseo daemon
status`), dừng nó trước khi mở Desktop: `paseo daemon stop` — hai daemon không cùng nghe
`127.0.0.1:6767`. Kiểm đúng daemon đang dùng: **Settings → your host → Overview → Full status**,
dòng `desktopManaged: true`.

## 2. Cấu hình một lần (trên máy chạy daemon)

Desktop đọc cùng file `~/.paseo/config.json` với CLI. Thêm hai profile provider và bật tool
injection (giữ nguyên key khác đang có):

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

Rồi `paseo reload` (hoặc khởi động lại Desktop). Kiểm: **Settings → your host → Providers** thấy
**SLP Lead** và **SLP Peer** ở trạng thái available; **Settings → your host → Agents → Enable Paseo
tools** đang bật (đây là cùng công tắc với `injectIntoAgents`).

Ý nghĩa: Peer bị cắt `Agent`/`Task` phía Claude và cắt `create_agent`/`send_agent_prompt`/`kill_agent`
phía Paseo → Peer không spawn được ai, không nhắn ai (Lab 12 M6). Lead giữ trọn bộ tool Paseo.

Tuỳ chọn: **Settings → your host → Agents → Agent profiles** tạo profile "SLP Lead" (provider SLP
Lead, model Opus, mode Auto) và "SLP Peer" (provider SLP Peer, model Sonnet, mode Accept edits) để
chọn một cú khi tạo agent. Profile chỉ gói provider/model/mode, **không** chứa system prompt.

## 2b. Plugin `slp-paseo` (khuyến nghị — thay cho bước 3 và 4 của §3)

Plugin trong `plugins/slp-paseo/` của repo này làm hai việc mà config không làm được:

- `agent.create`: agent tạo bằng provider `claude-lead`/`claude-peer` nhận system prompt =
  `.claude/agents/<ghế>.md` (trong cwd của agent, không có thì `~/.claude/agents/`) + khối
  `SLP-RUNTIME`. Đây là cái thay cho `claude --agent <ghế>` của bản native.
- Lead được thêm `allowedTools: mcp__paseo__*` nên card permission cho tool Paseo không bao giờ
  hiện — hết bẫy M7. Lưới thứ hai: nếu card vẫn hiện, plugin allow ngay.

Cài (plugin là code không sandbox, chạy trên máy daemon — Paseo bắt xác nhận):

```bash
# ~/.paseo/config.json: "pluginsEnabled": true  → paseo reload
git clone -b beta https://github.com/phucanh08/alp-claude ~/alp-claude   # hoặc checkout sẵn có
cd ~/alp-claude/plugins/slp-paseo && npm install && npm run typecheck && npm test
paseo plugin install ~/alp-claude/plugins/slp-paseo
paseo plugin ls          # slp-paseo running
paseo plugin logs slp-paseo   # mỗi agent tạo ra: "slp-paseo: lead ← <path> (+allowedTools mcp__paseo__*)"
```

Desktop: **Settings → Plugins** bật Enable plugins, cùng công tắc `pluginsEnabled`. Sửa source →
`paseo plugin reload slp-paseo`. Kiểm chứng 24/9/2026 trên 0.9.2: Lead mode `acceptEdits` gọi
`list_agents` không hiện card (trước plugin: có), `config.systemPrompt` 27.945 ký tự có
`# Ghế SLP: lead` + `SLP-RUNTIME`; peer nhận `peer.md`, không có `create_agent`/`send_agent_prompt`/
`Agent`/`Task` (ranh giới đó vẫn từ profile §2).

## 3. Chuẩn bị repo

1. Cài SLP bản beta vào repo: `curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/beta/install.sh | SLP_REF=beta bash`.
2. **Commit `.claude/`** (agents, skills, settings). Peer chạy trong worktree Paseo, chỉ thấy file
   trong Git — khác Agent Teams, nơi teammate dùng `.claude/` của Lead.
3. *(Bỏ qua nếu đã cài plugin §2b.)* Thêm khối `SLP-RUNTIME` vào `CLAUDE.md` của repo:

```markdown
## SLP-RUNTIME: paseo
Phiên này chạy trên Paseo, không phải Agent Teams. Ghế của bạn ghi ở đầu initial prompt; đọc
`.claude/agents/<ghế>.md` trước khi làm và hành xử đúng definition đó. Ánh xạ runtime:
- `Agent(subagent_type=peer, name=…)` → `create_agent` (provider `claude-peer/<model>`, `title` = tên
  peer, `workspaceId` từ `create_workspace` isolation `worktree` khi có ≥ 2 writer). Không dùng tool
  `Agent`/`Task` để giao việc.
- `SendMessage` tới Lead → không cần; Lead nhận notification khi bạn kết thúc lượt. Handoff 6 ô là
  câu trả lời cuối của lượt. Handoff ghi `Runtime: paseo`.
- Lead → peer: `send_agent_prompt` **chỉ khi peer idle** (`list_agents` status). Tin tới peer đang
  chạy sẽ **huỷ tool đang chạy** của nó. Peer đang chạy thì chờ notification, không nhắn. Dừng peer
  là việc của Human.
- Peer: việc dài (chờ thiết bị, chạy test lâu) chạy **nền**, poll bằng Bash ≤ 90 giây, số liệu ghi
  file mỗi vòng để Lead đếm chéo; không gửi tin giữa lượt (không có kênh).
```

4. *(Bỏ qua nếu đã cài plugin §2b.)* Cho Lead **không bị hỏi permission khi gọi tool Paseo** — thêm vào `.claude/settings.json`:

```json
{ "permissions": { "allow": ["mcp__paseo__*"] } }
```

Lý do: notification "peer xong / peer cần permission" tới Lead giữa lượt bằng steer, và steer
**huỷ card permission đang chờ** của Lead. Lab 12 M7: Lead đang chờ duyệt `respond_to_permission`,
notification tới, card bị huỷ, Lead đọc thành "Human từ chối" và đứng 3,5 phút. Allow rule làm card
không bao giờ hiện. Cách khác là chạy Lead ở mode **Auto**.

## 4. Chạy một phiên

1. **Mở workspace**: Desktop → chọn project (thư mục repo). Đây là workspace gốc, chỗ Lead ngồi.
2. **Tạo Lead**: New agent → provider **SLP Lead** (hoặc profile), model Opus, mode Accept edits
   hoặc Auto. Tin đầu tiên bắt đầu bằng `Ghế: lead.` rồi tới đề bài, ví dụ đề của Lab 11.
3. **Lead tự làm phần còn lại**: đọc `lead.md`, lập plan, `create_workspace` worktree cho từng
   writer, `create_agent` với provider `claude-peer/<model>` và brief có `Model … — lý do`. Các
   peer hiện trong **Subagents track** cạnh composer; bấm vào để xem hội thoại thật của từng peer.
4. **Permission**: card hiện trong thread của agent xin. Lead nhận notification và tự
   `respond_to_permission` cho peer. **Chọn một người duyệt**: hoặc để Lead duyệt (khuyến nghị,
   Lead kiểm brief trước khi cho), hoặc anh duyệt tay trong Subagents track — không cả hai, vì
   duyệt song song là nguyên nhân trực tiếp của bẫy M7.
5. **Gate duyệt plan**: Lead có thể bỏ gate khi đề ghi "gấp" (Lab 12). Muốn gate thì viết trong đề
   "dừng chờ anh duyệt plan trước khi spawn".
6. **Chấm**: Lead đọc diff `base..sha` bằng `git`, trả một dòng `ACCEPT <sha>` / `REJECT <sha> —
   finding`. REJECT gửi tới peer **đang idle** qua `send_agent_prompt`; peer sửa bằng commit mới.
7. **Merge/push** là việc của anh, Lead không làm.

## 5. Nhắn và dừng peer từ Desktop

| Thao tác | Cơ chế | Hệ quả |
|---|---|---|
| Gõ vào composer của **Lead** | steer khi Lead đang chạy | tới ngay giữa lượt; cắt đoạn text đang sinh, **không** huỷ tool đang chạy |
| Gõ vào composer của **peer đang chạy** (Subagents track) | steer | như trên — **chưa đo ở Lab 12** (chỉ đo `paseo send` CLI, là interrupt: huỷ Bash đang chạy, peer trả lời sau 15 giây rồi tự poll lại) |
| Nút **Stop** của agent | cancel | dừng ≤ 2 giây; **Lead không được báo** — nói Lead một câu hoặc để Lead tự `list_agents` |
| Đổi mode/model của agent đang chạy | Settings của agent | áp cho lượt kế |

Peer chạy việc dài phải chạy **nền** (F3 ở Lab 12 làm đúng): tin của anh không giết được process
đang đo.

## 6. Khác với bản native (main)

| | Native Agent Teams (`main`) | Paseo (`beta`) |
|---|---|---|
| Persona | `claude --agent lead`, frontmatter `tools:`/`memory:` | `Ghế: lead` + `.claude/agents/*.md` + `SLP-RUNTIME`; ranh giới tool bằng profile |
| Memory Lead | native `memory: local` | Lead tự ghi file `.claude/agent-memory-local/lead/` (Lab 12 tự làm) |
| Tin Lead → peer đang chạy | nằm inbox tới khi idle | huỷ tool đang chạy → luật chỉ nhắn khi idle |
| Tin peer → Lead | `SendMessage` + HEARTBEAT | notification khi peer xong / cần permission; số liệu qua file |
| Human → peer | agent panel | Subagents track / `paseo send` / Stop |
| Headless | `-p` không có teammate | mọi thứ là agent, chạy từ Desktop, CLI, điện thoại |
| Supervisor | session riêng, cross-session messaging | **chưa chuyển** (vòng sau) — tạm đọc bằng `paseo logs <id>` |
| Ngôn ngữ | ổn | notification Paseo tiếng Anh kéo Lead sang tiếng Anh — nhắc một câu, hoặc ghi "nói tiếng Việt" ngay trong đề |

## 7. Xem lại sau phiên

- `paseo ls -a` liệt kê agent kể cả đã archive; `paseo logs <id>` timeline; transcript SDK có
  timestamp ở `~/.claude/projects/<slug-của-worktree>/*.jsonl`.
- Worktree Paseo ở `~/.paseo/worktrees/<hash>/<slug>`; archive workspace thì Paseo dọn worktree
  sau workspace cuối — commit của peer vẫn ở nhánh trong repo gốc.
- Lỗi/phiên bản: **Settings → your host → Overview → Full status**, `~/.paseo/daemon.log`.
