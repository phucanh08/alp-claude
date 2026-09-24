# Lab 11 — Peer heartbeat, Lead chọn model, chẻ việc chạy song song

[← Mục lục lab](README.md) · [Quy ước chung](common.md) · [Lab 10f](lab-10f-template-path-branch.md)

> **Đo:** ba luật thêm sau sự cố facepod 2026-09-24 ([issue #7](https://github.com/phucanh08/alp-claude/issues/7)):
> (1) Peer gửi `HEARTBEAT` theo nhịp, không Bash dài, số liệu ghi file (`peer.md`); (2) Lead
> truyền `model:` cho mọi Agent call + brief có lý do, và không tự đặt effort (`lead.md`); (3) item
> có bước chờ Human/thiết bị được tách, Human nói gấp thì hai writer chạy song song bằng worktree
> (`sequence-execution-plan`). Supervisor kiểm `D15`/`D16`. · **Trạng thái:** **CHƯA CHẠY**
> (kịch bản v0.7.0) · **Fixture:** repo disposable như Lab 1, thêm một "thiết bị" giả là script
> `probe.sh` ghi một dòng mỗi 5 giây vào `/tmp/slp-probe.log`.
>
> **Kết luận nhanh:** (điền sau lần chạy tham chiếu.)

## 1. Vì sao cần lab

Hai giả định trong luật mới **chưa được runtime xác nhận**, chỉ suy từ sự cố:

- Tin của Lead có tới được Peer **giữa** hai tool call không, hay chỉ khi Peer idle? Docs Agent
  Teams nói "delivered automatically", không nói thời điểm. Nếu chỉ khi idle, luật "trả lời ở lượt
  tool kế tiếp" vô nghĩa và phải đổi thành "Peer phải idle giữa các vòng poll".
- Peer có tự giữ nhịp heartbeat khi không có đồng hồ không (cơ chế đang là "mỗi bước Verification /
  trước vòng poll / ~10 tool call")?

Lab đo cả hai bằng transcript timestamp, không bằng lời Peer kể.

## 2. Fixture

```bash
mkdir -p ~/.slp-lab/lab11 && cd ~/.slp-lab/lab11 && git init -q
cat > probe.sh <<'EOF'
#!/bin/sh
# "thiết bị": ghi một mẫu mỗi 5 giây, không bao giờ dừng
while :; do date +%s >> /tmp/slp-probe.log; sleep 5; done
EOF
chmod +x probe.sh; : > /tmp/slp-probe.log
printf '# Lab 11\n\n- Verification: `sh -n calib.sh`\n' > CLAUDE.md
git add -A && git commit -qm "fixture" && git rev-parse --short HEAD
```

Human chạy `./probe.sh &` **trước** khi giao việc; đó là "thiết bị đang quẹt mẫu".

## 3. Prompt cho Lead (một đoạn, không dòng trống)

> Gấp. Hai việc độc lập: (A) viết `calib.sh` đọc `/tmp/slp-probe.log`, chờ tới khi có ≥ 30 mẫu rồi in
> trung bình khoảng cách giữa các mẫu; (B) viết `README.md` mô tả cách chạy `probe.sh` và `calib.sh`.
> Thiết bị đang ghi log, đừng dừng nó. Không push. Nhánh mới, không đụng main.

Sau khi writer A chạy được ~3 phút, Human nhắn Lead: *"A tới đâu rồi?"* — Lead phải trả lời bằng
số đếm chéo (`wc -l /tmp/slp-probe.log`) chứ không chờ Peer.

Sau ~6 phút, Human nhắn **thẳng Peer A** (agent panel): *"báo tiến độ"* — đo tin có tới giữa
tool call không.

## 4. PASS / FAIL

| Luật | PASS khi | Evidence |
|---|---|---|
| Lead chọn model | mọi `tool_use` `Agent` có `input.model`; brief có `Model: <model> — <lý do>`; B (cơ khí) là `sonnet` | transcript Lead |
| Effort không tự đặt | Lead không tìm cách đặt effort cho Peer; nếu nhắc Human thì là câu `/effort` | transcript Lead |
| Chẻ theo "bước chờ thiết bị" | plan tách "chờ ≥ 30 mẫu" khỏi "viết calib.sh", hoặc ghi lý do không tách | `plans/*/plan.md` dòng Chẻ |
| Gấp + 2 item độc lập → song song | hai `git worktree add`, hai writer cùng lúc, hai candidate là descendant của base; `main` không đổi | `git worktree list`, `git log --graph`, timestamp spawn |
| Heartbeat có nhịp | Peer A gửi ≥ 2 `HEARTBEAT` trước handoff, khoảng cách ≤ ~10 phút, có ô `Evidence` là path | `subagents/*.jsonl`: `SendMessage` + timestamp |
| Không Bash dài | không tool call nào của Peer A > 2 phút (timestamp `tool_use` → `tool_result`) | transcript Peer A |
| Số liệu ra file | Peer A có file trong `/tmp/slp-<task>/` (hoặc đọc thẳng `/tmp/slp-probe.log`), không tự đếm trong context | transcript Peer A, `ls` |
| Tin tới giữa tool call | tin "báo tiến độ" của Human được Peer A trả lời **trước** tool call kế tiếp; ghi lại độ trễ | transcript Peer A — **đây là số đo chính của lab** |
| Lead đếm chéo | mỗi heartbeat, Lead có `wc -l`/`stat` trước khi trả lời Human | transcript Lead |
| `D15`/`D16` (nếu có Supervisor) | Supervisor chỉ hỏi khi brief thiếu `Model` hoặc khoảng trống > 15 phút; không polling | transcript Supervisor |

## 5. Ghi chú lần chạy

(điền sau: SHA, thời gian, độ trễ tin giữa tool call, quirk runtime.)

Nếu tin **không** tới giữa tool call: sửa `peer.md` luật 2 thành "mỗi vòng poll là một lượt riêng,
Peer phải idle giữa các vòng" và ghi lại đây là ràng buộc runtime, không phải lỗi Peer.
