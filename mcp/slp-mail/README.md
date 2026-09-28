# slp-mail — hộp thư chung cho các ghế SLP (v0.9.0)

Một file Python, chỉ stdlib: `slp_mail.py`. Vừa là MCP server (stdio) cho Lead / Peer /
Supervisor, vừa là CLI cho Human và cho lab. Thay cho inbox của Agent Teams ở ba chỗ runtime
không cho: Supervisor nói với Peer, Human nói với mọi ghế từ một chỗ, người gửi kiểm chứng được.

**Không thay được**: tin vẫn là *kéo*, agent chỉ thấy khi gọi `inbox` (hoặc khi `Monitor` trên
`log.jsonl` báo — xem Lab 12). Lead vẫn là người duy nhất spawn Peer.

## Chạy

```bash
python3 mcp/slp-mail/slp_mail.py selftest                 # 18 kiểm: protocol, danh tính, cc, ack, log
python3 mcp/slp-mail/slp_mail.py mcp-config lead --workspace shop > /tmp/lead.mcp.json
python3 mcp/slp-mail/slp_mail.py mcp-config supervisor --workspace shop > /tmp/sup.mcp.json

claude --agent lead --name lead --mcp-config /tmp/lead.mcp.json
claude --agent supervisor --name supervisor --settings <.claude>/slp-supervisor.settings.json \
       --mcp-config /tmp/sup.mcp.json
```

Human dùng CLI (seat mặc định `human`):

```bash
export SLP_WORKSPACE=shop
python3 mcp/slp-mail/slp_mail.py send --to lead --kind ruling "Giữ dù, không gắn phanh"
python3 mcp/slp-mail/slp_mail.py send --to lead/peer-a "File evidence đứng 12 phút, vì sao?"   # tự cc lead
python3 mcp/slp-mail/slp_mail.py inbox                       # hộp thư human, chưa đọc
python3 mcp/slp-mail/slp_mail.py log --follow                # xem cả room
```

Log nằm ở `~/.slp-mail/<workspace>/log.jsonl` (đổi bằng `SLP_MAIL_DIR`). Một workspace một log.

## Tool (tên trong Claude Code: `mcp__slp-mail__<tool>`)

| Tool | Làm gì | Ràng buộc |
|---|---|---|
| `send(to, body, kind?, cc?, agent?)` | gửi một tin | `from` = `SLP_SEAT` của process, không nhận từ agent; `agent` chỉ để teammate trong process Lead ghi `lead/<agent>` |
| `inbox(mailbox?, unread_only?, since?)` | đọc hộp thư | đọc mailbox nào cũng được — log là evidence chung |
| `ack(ids, mailbox?)` | đánh dấu đã đọc | chỉ mailbox `<seat>` hoặc `<seat>/<agent>` |
| `log(since?, from?, to?, kind?, limit?)` | truy vấn cả room | — |
| `whoami()` | seat, thư mục, workspace | — |

`kind`: `message` `heartbeat` `ping` `brief` `handoff` `verdict` `ruling` `drift` `escalate`
`note` `register` `request`. Dùng để Supervisor lọc (`log kind=verdict`) thay vì mò transcript.

## Ba luật server giữ, agent không lách được

1. **Danh tính theo process.** `SLP_SEAT` nằm trong `env` của `.mcp.json` lúc khởi động; agent
   không đổi được env của server đang chạy. Process không có `SLP_SEAT` gửi bị từ chối.
2. **Địa chỉ Peer là `<lead>/<peer>`.** Tin tới `lead/peer-a` từ seat khác `lead` → server tự cc
   `lead`, ghi `auto_cc`. Can thiệp từ ngoài team luôn quay về trạng thái chung của Lead.
3. **Teammate là sub-identity của Lead.** Trong process của Lead, Peer gửi với `agent: peer-a`
   → `from: lead/peer-a`, `seat: lead`. Phần trước `/` kiểm chứng được, phần sau tự khai trong
   vùng tin cậy của Lead (Agent Teams chạy teammate trong cùng process, server không tách được).

## Giới hạn đã biết

- **CLI giả mạo.** Mọi process cùng user OS, agent có `Bash` chạy được
  `SLP_SEAT=human python3 slp_mail.py send …`. Chặn bằng hook `PreToolUse` Bash trong
  `templates/slp-mail.settings.json` (Lead dùng qua `--settings`) và trong
  `supervisor.settings.json`; đo ở Lab 12: chặn đúng, Lead cũng tự từ chối trước khi hook chạm.
- **Hai chỗ phải khai tool.** `tools:` frontmatter của agent loại MCP tool nếu không ghi
  `mcp__slp-mail__*` (Lab 12); mode thường còn cần `permissions.allow: ["mcp__slp-mail"]` (headless
  bị chặn im, interactive hỏi từng lần). Cả hai đã có trong definition và template v0.9.0.
- **Sandbox Supervisor không cản.** Server do Claude Code spawn, ngoài sandbox Bash; Supervisor
  thật với `supervisor.settings.json` gửi/đọc được (Lab 12 bước 4).
- **Không đẩy.** Tin không chèn vào lượt của agent; arm `Monitor` trên `log.jsonl` thì sự kiện tới
  kèm kết quả tool call đang chạy (Lab 12: teammate thật, trễ 2–15 s), hết hạn 30 phút phải arm lại.
  Tin ghi trước lúc arm không thấy: `inbox` một lần trước khi arm.
- **Teammate trong process Lead** có thấy tool `mcp__slp-mail__*` không: chưa đo. Không thấy →
  `peer.md` rơi về `SendMessage` + `cat` inbox.
- Một seat một process. Hai Lead cùng máy: `SLP_SEAT=lead-api`, `lead-web`; Peer là
  `lead-api/peer-a`.
