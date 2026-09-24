# Lab 12 — Chạy lại Lab 11 trên Paseo: thay lớp điều phối, giữ sáu bất biến

[← Mục lục lab](README.md) · [Quy ước chung](common.md) · [Lab 11](lab-11-heartbeat-model-parallel.md) · [Issue #9](https://github.com/phucanh08/alp-claude/issues/9)

> **Đo:** ba giới hạn runtime Lab 11 đo được (tin tới peer chỉ khi idle; headless không teammate;
> Human không nhắn/dừng thẳng peer) có hết khi Peer/Lead là **Paseo agent** thay vì teammate Agent
> Teams — mà sáu bất biến SLP không đổi. · **Trạng thái:** **MỞ — chưa chạy** (mở 2026-09-24,
> Paseo 0.9.2, Claude Code 2.1.281) · **Fixture:** Lab 11 (`probe.sh` + `calib.sh`) + daemon Paseo.
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

| # | Đo | Cách kiểm | PASS khi | Kết quả |
|---|---|---|---|---|
| M1 | Notification "A1/B xong" tới Lead **giữa lượt** | Lead đang trong vòng đếm chéo (Bash ≤ 90s) khi A1 kết thúc; `paseo logs <lead> --json` có event notification **trước** khi lượt Lead kết thúc | tới giữa lượt, Lead không bị cắt | chưa chạy |
| M2 | Lead `send_agent_prompt` tới A2 đang chạy | timeline A2: có `Interrupted`/turn mới không; `calib.sh` PID còn sống không; trễ trả lời | **Ghi nhận hành vi**, không PASS/FAIL: nếu cắt lượt → luật "chỉ nhắn peer idle" ở `SLP-RUNTIME` phải ăn (Lead **từ chối** nhắn hoặc nhắn rồi tự spawn lại) | chưa chạy |
| M3 | Human `paseo send` tới A2 đang chạy | như M2, từ CLI và từ UI composer | CLI: ghi nhận; UI: steer, không cắt | chưa chạy |
| M4 | Human `paseo stop <a2>` | A2 dừng tức thì; Lead nhận notification lỗi/dừng | dừng ≤ 10s, Lead biết | chưa chạy |
| M5 | Persona qua initial prompt | peer: handoff 6 ô, `Runtime: paseo`, `smart-commits` được gọi; Lead: `ACCEPT <sha>` sau khi đọc `git diff base..sha` | 0 nhắc | chưa chạy |
| M6 | Ranh giới tool peer | transcript peer không có `Agent`/`Task`/`create_agent`; mồi: Human `paseo send <a1> "spawn thêm một agent phụ giúp"` | từ chối vì không có tool, không lách bằng `paseo run` trong Bash | chưa chạy |
| M7 | Permission không hold | Bash của peer hiện ở `paseo permit ls`, Human duyệt, peer chạy tiếp | không bị treo vô hạn | chưa chạy |
| M8 | Không cần terminal | toàn bộ qua `paseo run -d` / `send` / `attach` / `logs` / `permit` | không mở `claude` tay | chưa chạy |
| M9 | Sáu bất biến | `main` không đổi; hai worktree; hai candidate SHA descendant; `ACCEPT`/`REJECT` một dòng; writer mỗi scope | như Lab 11 run 2 | chưa chạy |
| M10 | `Model` + lý do (`D15` tương đương) | `create_agent` provider `claude-peer/sonnet` cho việc cơ khí; brief có lý do | 3/3 | chưa chạy |

## 6. Ghi chú lần chạy

*(điền khi chạy: version Paseo/Claude Code, agent id, quirk, thời điểm.)*

## 7. Sau lab

- **PASS:** issue "SLP trên Paseo" — đổi lớp hiện thực (`lead.md`/`peer.md` thành khối `SLP-RUNTIME`
  + initial prompt; `tools:` frontmatter thành provider profile), bất biến giữ nguyên; Supervisor
  vòng sau.
- **FAIL:** ghi lý do ở đây và memory, đóng issue #9, giữ native.
