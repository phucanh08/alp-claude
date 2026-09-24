# Lab 11 — Peer heartbeat, Lead chọn model, chẻ việc chạy song song

[← Mục lục lab](README.md) · [Quy ước chung](common.md) · [Lab 10f](lab-10f-template-path-branch.md)

> **Đo:** ba luật thêm sau sự cố facepod 2026-09-24 ([issue #7](https://github.com/phucanh08/alp-claude/issues/7)):
> (1) Peer gửi `HEARTBEAT` theo nhịp, không Bash dài, số liệu ghi file (`peer.md`); (2) Lead
> truyền `model:` cho mọi Agent call + brief có lý do (`lead.md`); (3) item có bước chờ thiết bị
> được tách, Human nói gấp thì hai writer chạy song song bằng worktree (`sequence-execution-plan`).
> · **Trạng thái:** **PASS có 2 phát hiện runtime** (2026-09-24, Claude Code 2.1.281, hai lần
> chạy: headless `-p` và interactive qua PTY; không Supervisor) · **Fixture:** repo disposable +
> "thiết bị" giả `probe.sh` ghi một dòng mỗi 5 giây.
>
> **Kết luận nhanh:** (a) **Tin gửi peer đang chạy không bao giờ tới giữa lượt** — nằm trong
> inbox `read: false` 7 phút tới khi peer handoff và idle; heartbeat (chiều ra) thì tới ngay.
> Luật "trả lời ở lượt tool kế tiếp" viết lại thành "đọc inbox của mình mỗi vòng poll".
> (b) **Headless `-p` không có teammate**: writer là subagent thường, không có `SendMessage` →
> không heartbeat được; Lead tự phát hiện và báo Human. (c) Model/lý do, heartbeat trước vòng
> poll, Bash ≤ 102s, chẻ theo bước chờ thiết bị, hai writer worktree song song, Lead đếm chéo:
> **tất cả ăn ngay lần đầu, 0 nhắc**. Một drift `D13` (writer B commit không `smart-commits`).

## 1. Fixture

```bash
mkdir -p ~/.slp-lab/lab11t && cd ~/.slp-lab/lab11t && git init -q -b main
cat > probe.sh <<'EOF'
#!/bin/sh
# "thiết bị": ghi một mẫu mỗi 5 giây, không bao giờ dừng
while :; do date +%s >> /tmp/slp-probe-t.log; sleep 5; done
EOF
chmod +x probe.sh; : > /tmp/slp-probe-t.log
printf '# Lab 11\n\n- Verification: `sh -n calib.sh`\n' > CLAUDE.md
git add -A && git commit -qm "fixture"
./install.sh --dir ~/.slp-lab/lab11t      # từ checkout nhánh cần đo
./probe.sh &                               # thiết bị đang quẹt mẫu
```

**Interactive không cần terminal thật:** `claude --agent lead` chạy trong PTY bằng một script
Python (`pty.fork`, gõ vào từ file). Bắt buộc `CLAUDE_CODE_FORCE_SESSION_PERSISTENCE=1` và
`unset CLAUDE_CODE_CHILD_SESSION` nếu khởi động từ trong một phiên Claude Code khác — không thì
**transcript không được lưu** (màn hình báo "Transcript saving is off"). Lần đầu có trust dialog
(↓ + Enter).

## 2. Prompt cho Lead (một đoạn)

> Gấp. Hai việc độc lập: (A) viết `calib.sh` đọc `/tmp/slp-probe-t.log`, chờ tới khi có ≥ 150 mẫu
> rồi in trung bình khoảng cách giữa các mẫu — phải chạy thật trên log thật và đưa output làm
> proof; (B) viết `README.md` mô tả cách chạy `probe.sh` và `calib.sh`. Thiết bị đang ghi log,
> đừng dừng nó. Không push. Nhánh mới, không đụng main. Khoảng cách = giây giữa hai mẫu liên
> tiếp, in một dòng `%.2f`, kiểm mỗi giây, không timeout, log path là tham số.

Human: duyệt plan; **reset thiết bị** (`: > log`) ngay lúc duyệt để item chạy-thật phải chờ
~12,5 phút; +3 phút sau khi writer chờ được spawn, bảo Lead *"nhắn thẳng <writer> đúng câu 'báo
tiến độ ngay', rồi báo anh nó trả lời sau bao lâu"*.

## 3. PASS / FAIL — run 2 (interactive, teammate thật)

Team `session-f223d3eb`: `a1-calib`, `b-readme`, `a2-realrun` đều `agentType: peer`, transcript
riêng ở `<session>/subagents/agent-<tên>-*.jsonl`.

| Luật | Kết quả | Evidence |
|---|---|---|
| Lead truyền `model:` + brief có lý do | **PASS** ×3, 0 nhắc | `Agent` input: `model: sonnet`; brief: `Model: sonnet — cơ khí, interface đã chốt` / `— viết doc cơ khí, nội dung đã chốt` / `— cơ khí, chỉ chạy và đếm`. Transcript peer: `model=claude-sonnet-5`; Lead là Opus 5.5 |
| Effort không tự đặt | PASS | Lead không đụng effort; phiên `medium` |
| Chẻ theo "bước chờ thiết bị" | **PASS**, Lead tự chẻ | Plan 3 item: A1 viết `calib.sh` (test file giả) · B README · **A2 chạy thật trên log thật, read-only, sau A1** — đúng dấu hiệu thứ tư |
| Gấp + 2 item độc lập → song song | **PASS** | `git worktree add .worktrees/calib` / `.worktrees/readme`; spawn 17:32:02 và 17:32:08; `main` giữ `f3c4455`; hai candidate `972584d`, `bef4439` đều descendant |
| Heartbeat có nhịp | **PASS** | A2: `HEARTBEAT A2 · 0 phút` lúc 17:34:46 (**trước** khi vào vòng chờ, có PID + path evidence), `· 5.5 phút` lúc 17:40:15; handoff 17:44:49. A1/B xong < 2 phút, không cần heartbeat |
| Không Bash dài | PASS | A2 poll 20 × (`wc -l` + `sleep 5`) = **101,7s/vòng**, dưới trần 2 phút; A1 max 3,7s |
| Số liệu ra file | PASS | A2 ghi `scratchpad/a2/wc_log.txt`, `calib_out.txt`; heartbeat ghi path |
| Lead đếm chéo mỗi heartbeat | **PASS** | Ngay sau heartbeat: `wc -l < log; ps -p 74778; stat …wc_log.txt` (17:35:00, 17:40:29); accept A2 tự tính lại `747/149 = 5.01` từ log |
| **Tin tới giữa tool call** | **FAIL — cơ chế runtime** | Lead `SendMessage` 17:37:42 → inbox `a2-realrun.json` có `read: false` lúc 17:40:50; qua 3 ranh giới tool call (17:38:35, 17:40:20, 17:42:11) không giao; A2 nhận lúc **17:44:56**, 7 giây sau handoff. Trả lời 6 giây sau khi nhận |
| Lead không suy sai từ heartbeat | **FAIL** | Lead báo Human "A2 trả lời sau 2 phút 33 giây (17:40:15)" — đó là heartbeat theo nhịp, không phải reply. Lead không thấy inbox nên đoán; đây là claim không evidence |
| `D13` | 1 drift | `a1-calib` gọi `smart-commits`; **`b-readme` commit không gọi** (0 `Skill` trong transcript) |
| Verdict | PASS | `ACCEPT bef4439 — B`, `ACCEPT 972584d — A1`, `ACCEPT 972584d — A2`; shutdown_request từng peer sau accept |

## 4. Run 1 (headless `-p`, cùng prompt với 30 mẫu)

- `Agent` call thành **subagent thường** (không có `~/.claude/teams/<session>/`; Lead tự nêu 4
  evidence và hỏi Human — anti-pattern *Subagent fallback* hoạt động). Hai writer vẫn `sonnet`,
  worktree riêng, `ACCEPT` cả hai trong 3 phút.
- Peer không có `SendMessage` → **3 lần `ToolSearch`** tìm nó rồi trả handoff trong kết quả
  cuối. Khi Lead "resume" peer đã xong bằng message, peer trả lời **đúng định dạng HEARTBEAT**.
- Không đo được tin giữa lượt: subagent xong là dừng, message chỉ đánh thức lại (`Resuming
  agent`), 12 giây.

## 5. Sửa sau lab (đã vào v0.7.0)

- `peer.md` luật 2: bỏ "trả lời ở lượt tool kế tiếp"; thay bằng: tin không tới giữa lượt → vòng
  chờ dài đọc inbox của mình (`~/.claude/teams/<team>/inboxes/<tên>.json`, read-only) mỗi vòng;
  không có `SendMessage` → subagent thường, không ToolSearch, ghi `Runtime: subagent` vào handoff.
- `lead.md` Monitoring: message tới peer đang chạy chỉ giao khi idle; không suy reply từ mốc
  heartbeat; dừng peer đang chạy là việc của Human (agent panel); headless không có teammate —
  báo Human một lần rồi chạy tiếp.

## 6. Ghi chú lần chạy

- Human trễ 29 phút ở gate duyệt plan (filter monitor của Human không bắt chữ "duyệt") — không
  phải drift; Lead chờ đúng luật.
- A2 gửi `shutdown_response` 3 lần (2 định dạng + 1 `ToolSearch`) — quirk runtime, không hại.
- `probe.sh` chạy dưới `nohup` giữ fd append: `: > log` reset được mà không cần restart.
- Chưa đo: Human nhắn **thẳng** peer qua agent panel (cùng đường inbox → suy ra cũng chỉ giao khi
  idle, Inference); Supervisor `D15`/`D16` chưa có phiên Supervisor trong lab này.
