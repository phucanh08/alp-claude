# Lab 10f — Lab hẹp: đường dẫn mẫu cụ thể, skill repo thắng global, nhánh task

[← Mục lục lab](README.md) · [Quy ước chung](common.md) · [Lab 10e](lab-10e-code-phase.md)

> **Đo:** hai sửa sau Lab 10e: đường dẫn mẫu plan cụ thể và "skill repo thắng skill global"
> (`bfbf110`); nhánh task, không commit lên nhánh chính (`1326fb3`). Dừng sau `ACCEPT` của item
> writer đầu. · **Trạng thái:** **PASS** (2026-09-24, headless, không Supervisor) · **Fixture:** y
> hệt Lab 10 §1, repo `~/.slp-lab/lab10f`, base `f4da8e0`
>
> **Kết luận nhanh:** giữ nguyên bản skill cũ ở `~/.claude/skills` (trường hợp xấu nhất), Lead
> vẫn tự đọc mẫu trong repo. Cả hai plan đều theo mẫu, **0 lần nhắc**. Writer commit trên nhánh
> riêng, `main` không đổi.

## 1. Chạy

- `Skill` vẫn báo nạp `sequence-execution-plan` từ `~/.claude/skills`, là bản chưa có mẫu.
- Human gõ 3 lượt, không nhắc gì về plan:
  1. prompt Lab 10;
  2. chọn A, kèm ruling giống Lab 10e;
  3. duyệt plan, và cho F1 gồm cả `pay`.
- Tổng thời gian khoảng 8 phút; từ lúc duyệt plan đến lúc `ACCEPT` F1 khoảng 3 phút.

## 2. PASS / FAIL

| Luật | Kết quả | Evidence |
|---|---|---|
| Mẫu plan, không cần nhắc | **PASS** ×2 | Ngay sau `Skill`, Lead `cat .claude/skills/sequence-execution-plan/references/plan-template.md` trong repo. Plan thiết kế và plan code đều có Mermaid, cột Test seam, dòng Chẻ |
| Chẻ theo ruling | PASS | "F2 — chạm 3 boundary (C4, C1/tiền, C3) → chẻ F2a, F2b, F2c". Lần này Lead tự đặt tên hàm trong plan, và việc Human duyệt plan được tính là ruling |
| Nhánh task, `main` không đổi | **PASS** | `main` = `f4da8e0`. F1 `973070c` nằm trên `fix/check-before-append`. `LEAD-WROTE 5157701` nằm trên `feat/partial-refund`, tách từ F1. Lead ghi "merge là của anh" |
| Gate duyệt plan | PASS | Lead không giao writer trước khi Human duyệt |
| `bug-loop` + L3 cho F1 | PASS | Test đỏ trên base, xanh sau sửa. Lead tự làm hỏng lại code thì test đỏ (4 test ở `pay`, 3 ở `refund`). Reviewer làm lại độc lập |
| `plans/.gitignore`, `git status` sạch | PASS | |

## 3. Ghi chú

- Lead tách bug sang nhánh `fix/…` riêng để có thể merge độc lập, rồi mới tách nhánh tính năng
  từ đó. Luật không yêu cầu điều này, nhưng cũng không trái luật.
- Lab không chạy F2a–F2c, nên không có số đo `REJECT` mới. Số đo pha code dùng
  [Lab 10e](lab-10e-code-phase.md).
