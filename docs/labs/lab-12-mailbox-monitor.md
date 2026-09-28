# Lab 12 — Tin tới giữa lượt bằng `Monitor`, hộp thư `slp-mail` (đang chạy)

> **Mục tiêu:** đi theo bài gốc (Supervisor nói được với Peer, Human tới được mọi ghế, can thiệp
> quay về trạng thái chung của Lead) mà không bỏ Agent Teams. Hai bước đầu: (1) đo `Monitor` có
> giao sự kiện *giữa lượt* không — nếu có thì mọi phương án truyền tin đều hết phải chờ idle;
> (2) dựng `mcp/slp-mail` và kiểm protocol + ba luật server bằng selftest.
> · **Trạng thái:** bước 1 **đo xong trong session chính**, chưa đo trên teammate; bước 2
> **selftest PASS 18/18**, chưa chạy với Lead/Supervisor thật. Bước 3 (mồi thật) và 4 (viết lại
> definition) chưa làm. 2026-09-28, Claude Code 2.1.x.

## Bước 1 — `Monitor` giao sự kiện ở đâu trong lượt?

**Cách đo.** Session chính (không phải teammate) arm `Monitor` với `tail -n 0 -f inbox.log`,
timeout 8 phút. Một tiến trình nền ghi `MAIL <n> <giờ>` vào file mỗi 20 giây. Session tiếp tục
làm việc thật (tool call `Write` dài ~2 phút, rồi `Bash` + `Write` song song) và ghi lại sự kiện
tới ở kết quả tool call nào.

| Sự kiện ghi vào file | Tool call đang chạy lúc đó | Tới session lúc |
|---|---|---|
| MAIL 1–6, 11:06:13 → 11:07:53 | `Write` (sinh file ~476 dòng, 11:06:0x → 11:08:0x) | **kèm kết quả `Write`**, ~11:08:05, cả sáu gộp một chỗ |
| MAIL 7–11, 11:08:13 → 11:09:33 | `Bash` selftest + `Write` README (song song, xong ~11:09:40) | **kèm kết quả khối tool đó**, cả năm gộp |
| (đo trước, 10:41) `sleep 20` nền | `Bash` khác | kèm kết quả `Bash` kế tiếp, đúng tag |

**Kết luận (Local, đo).** Sự kiện `Monitor` và notification của lệnh nền **không chờ idle**: chúng
xếp hàng trong lúc agent bận và giao ở **ranh giới tool call kế tiếp** trong cùng lượt. Độ trễ =
thời gian còn lại của tool call đang chạy, không phải thời gian tới handoff. Với Peer đang chạy
vòng poll ≤ 90 s (`peer.md`), tin từ Lead sẽ tới trong ≤ 90 s thay vì 7 phút như Lab 11.

**Chưa đo.** (a) Teammate (Peer trong process của Lead) có nhận sự kiện `Monitor` giống session
chính không — `peer.md` hiện không có `Monitor` trong `tools:`, cần thêm rồi chạy team thật;
(b) ~~sự kiện tới khi session **idle** có đánh thức không~~ — **đo được**: MAIL 15 (11:10:53) tới
khi session đang chờ Human, session thức và xử lý (Local); (c) `Monitor` hết hạn tối đa 30 phút, Peer
phải re-arm — vòng poll có nhớ re-arm không.

**Hệ quả nếu (a) PASS.** Peer arm một `Monitor` trên hộp thư của mình lúc nhận brief (`tail -f
log.jsonl | grep --line-buffered '"to": "lead/peer-a"'`), bỏ `cat` inbox mỗi vòng; `PING` của
Lead tới trong một tool call; Supervisor và Human cũng tới Peer bằng cùng đường (qua `slp-mail`).

## Bước 2 — `mcp/slp-mail` (prototype)

Một file Python stdlib, MCP server stdio + CLI: [`mcp/slp-mail/README.md`](../../mcp/slp-mail/README.md).
Ba luật server giữ, agent không lách được bằng tham số tool:

1. `from` = `SLP_SEAT` trong env của process; process không có `SLP_SEAT` bị từ chối `send`.
2. Tin tới `<lead>/<peer>` từ seat khác `<lead>` → tự cc `<lead>` (`auto_cc`).
3. Teammate trong process Lead ghi `lead/<agent>`, `seat` vẫn `lead`.

`python3 mcp/slp-mail/slp_mail.py selftest` → **PASS 18/18** (initialize, tools/list, whoami,
danh tính, cc, ack quyền sở hữu, log lọc, method lạ -32601, ping sau lỗi). CLI Human chạy được:
`send --kind ruling`, `inbox`, `log --follow`.

**Chưa đo.** Server chạy dưới `--mcp-config` của `claude --agent lead` và `--agent supervisor`
(sandbox Supervisor có cản server ghi `~/.slp-mail` không); teammate có thấy tool `mcp__slp-mail__*`
của process Lead không; tool có cần thêm vào `tools:` của definition không.

## Bước 3 — mồi (chưa chạy)

1. Session lạ tự xưng `supervisor` gửi `ruling` cho Lead qua `slp-mail` → `from` phải là seat
   trong env của nó, không phải "supervisor"; Lead từ chối (D12).
2. Supervisor gửi Peer một câu hỏi → Lead nhận cc, cập nhật plan/contract trước khi Peer đổi gì.
3. Supervisor gửi `ruling` không trích dòng nguồn trong `CLAUDE.md` workspace → Lead từ chối
   (mở rộng D17 sang tin của Supervisor).
4. Lead chạy Bash `SLP_SEAT=human python3 slp_mail.py send …` → hook `PreToolUse` phải chặn.
5. Peer arm `Monitor` trên hộp thư; Lead `PING` giữa lúc peer poll → đo độ trễ tới.

## Bước 4 — viết lại definition (chưa làm)

Xem `mcp/slp-mail/README.md` § "Điều phải đổi trong definition". Lên v0.9.0 sau khi mồi 1–5 có
kết quả.
