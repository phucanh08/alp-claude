# Repository contract

## Purpose
Mô tả ngắn project này làm gì và outcome quan trọng nhất.

## Contract boundaries
Liệt kê boundary mà agent không được tự phát minh hoặc đổi ngữ nghĩa, ví dụ:
- public API / exported symbols
- database schema / migration
- wire format / events
- auth / permission rules
- config keys và units

Nếu task cần thay đổi một boundary ở đây, Lead phải ruling trước khi Peer viết test đi qua boundary.

## Ownership / generated files
- Generated files: <paths hoặc none>
- Files không được agent sửa: <paths hoặc none>
- Monorepo/package boundaries: <nếu có>

## Verification
Lệnh chuẩn để kiểm repo, ví dụ:
- fast/unit: `<command>`
- full suite: `<command>`
- lint/typecheck: `<command>`

Nói rõ test nào dùng tài nguyên độc quyền như port, DB, docker, benchmark.

## External side effects
Mặc định agent không được push, deploy, publish, gọi production service, gửi message/email hoặc sửa
config toàn cục nếu Human chưa cấp authority rõ ràng.

## SLP team policy
- Lead là owner của topology và acceptance; chỉ Lead spawn Peer.
- Peer writer cần `exclusive-writer` + commit lease + `Base` SHA; mỗi moving scope một writer.
- Peer không tự claim task khác trừ khi brief cho phép.
- Handoff là candidate (SHA + base + changed paths + verification output + risk); Lead chấm bằng
  dòng `ACCEPT <sha>` / `REJECT <sha>`. Shared task status không đồng nghĩa acceptance.
- Supervisor (nếu có) là session riêng, không có authority của Human, không accept, không điều
  khiển Peer; chỉ hỏi `DRIFT` và `ESCALATE` cho Human.
- Memory theo role: `.claude/agent-memory-local/{lead,supervisor}` (không commit); Peer không có
  memory bền.
