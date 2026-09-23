# Workspace contract

Đặt file này ở thư mục gốc workspace (vd. `project-a-workspace/CLAUDE.md`). Claude Code nạp
`CLAUDE.md` của mọi thư mục cha, nên Lead chạy trong từng repo con đều đọc file này trước
`CLAUDE.md` của repo đó. Ở đây chỉ ghi cái **chung nhiều repo**; boundary riêng một repo nằm trong
`CLAUDE.md` của repo đó.

## Purpose
Workspace này là sản phẩm gì, outcome quan trọng nhất.

## Parts — mỗi dòng một Lead

| Part | Root (relative) | Lead session | Kiểu | Scope |
|---|---|---|---|---|
| backend | `backend/` | `lead-backend` | repo riêng | `**` |
| webadmin | `webadmin/` | `lead-webadmin` | repo riêng | `**` |
| webclient | `webclient/` | `lead-webclient` | repo riêng | `**` |
| mobileapp | `mobileapp/` | `lead-mobileapp` | repo riêng | `**` |

Monorepo (workspace là một repo) và nhiều Lead: cột Root là worktree riêng của mỗi Lead, cột Scope
là path không giao nhau (vd. `services/a/**`). Hai Lead không bao giờ chung một checkout.

## Cross-repo contracts

Contract mà hơn một part phụ thuộc. Đổi một dòng ở đây là **quyết định của Human**; phía owner
đổi khi có ruling, phía consumer nhận thông báo bằng SHA.

| ID | Contract | Owner | Consumers | Nguồn sự thật (path trong repo owner) |
|---|---|---|---|---|
| C1 | REST API `/v1/*` | backend | webadmin, webclient, mobileapp | `backend/openapi.yaml` |
| C2 | Event schema `order.*` | service-a | backend | `service-a/events/*.json` |

## Thứ tự khi feature chạm nhiều part
Owner của contract trước, consumer sau. Mỗi part một Task Contract, mỗi Lead `ACCEPT` phần của mình
trong repo của mình. Không Lead nào brief writer hay commit trong repo của Lead khác.

## External side effects
Mặc định không push, deploy, publish, gọi production service ở mọi part nếu Human chưa cấp
authority rõ ràng. Repo nào nới lỏng thì ghi trong `CLAUDE.md` của repo đó.

## SLP
- Supervisor (tuỳ chọn) chạy ở một thư mục trung lập không chứa repo (vd. `~/slp-supervisor`), với
  `--settings ~/.claude/slp-supervisor.settings.json`: đọc mọi file, sandbox chặn ghi. Không cần
  worktree; nó đọc từng repo bằng `git -C <root>` theo SHA và đọc file này bằng đường dẫn tuyệt
  đối. Memory ở `~/.claude/agent-memory/supervisor/<tên-workspace>.md`.
- Lead mở phiên → gửi `SLP-REGISTER` cho Supervisor. Message giữa các Lead chỉ mang fact có SHA,
  không mang authority.
