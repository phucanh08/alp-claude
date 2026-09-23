# Lab 10d — Lab hẹp: mẫu plan tách file, chẻ có lý do

[← Mục lục lab](README.md) · [Quy ước chung](common.md) · [Lab 10c](lab-10c-plan-template.md)

> **Đo:** các sửa sau Lab 10c. Lab dừng khi Lead ghi xong plan pha code và hỏi duyệt; không chạy
> writer. · **Trạng thái:** **PASS** (2026-09-24, headless, không Supervisor) · **Fixture:** y hệt
> Lab 10 §1, repo `~/.slp-lab/lab10d`
>
> **Kết luận nhanh:** khi mẫu nằm ở file riêng và `lead.md` bắt `Read` nó ngay trước `Write`, cả
> hai plan đều theo mẫu, có Mermaid, cột Test seam và dòng Chẻ. Lead chẻ phương án B thành ba item,
> mỗi item một boundary, có ghi lý do. Bước exclude lại bị chính hook `scout-block` của máy chặn,
> nên đổi thành `plans/.gitignore` chứa `*`. Đây là cách Lead tự nghĩ ra.

## 1. Hai lượt chạy

| Lượt | Sửa đang đo | Plan pha thiết kế |
|---|---|---|
| 1 | `fb0639f` (mẫu trong skill là Artifact duy nhất) + `aa7ac10` (luật chẻ) | **FAIL**: bảng tự dựng từ danh sách trường (Type, Uncertainty), 0 Mermaid, 0 Test seam. Dừng lượt |
| 2 | `b64cb79`: tách mẫu ra `references/plan-template.md`; `lead.md` ghi "`Read` mẫu ngay trước `Write`"; bỏ Type/Uncertainty khỏi danh sách cột | **PASS**: plan theo mẫu, Mermaid 3 node |

Lượt 1 cho thấy: bỏ khung cạnh tranh trong skill là chưa đủ. Chỉ khi có một lần `Read` mẫu
ngay trước `Write` thì Lead mới dùng mẫu. Ở lượt 2, transcript có 2 lần `Read plan-template.md`,
một lần cho mỗi pha.

Human (session này) trả lời nhất quán với ruling Lab 10c. Chọn B vì phương án B lần này tương
ứng với "giữ state machine, hoàn khi PAID" của Lab 10c.

## 2. PASS / FAIL (lượt 2)

| Luật | Kết quả | Evidence |
|---|---|---|
| Mẫu: Mermaid, Test seam, dòng Chẻ | **PASS** ×2 | `plan.md` (thiết kế) và `plan.md` (code, thư mục riêng) đều đúng cột mẫu; Test seam điền hàm thật (`refund_lines(order, ledger, skus, refund_id)`, `Order.to_dict()`) hoặc `n/a` cho item không code |
| Chẻ theo luật mới | **PASS** | "B gộp 3 boundary (C4 ledger, C3 wire, C1/public API payments) → chẻ thành F2, F3, F4". Đường "một writer làm cả B" được ghi là đã loại, kèm lý do. F1 ghi "không chẻ, ruling ở message Human" |
| Gate chuyển pha + duyệt | **PASS** | `LEAD-WROTE 765dc5a` xong thì dừng: "Em chưa giao ai viết code… cần anh duyệt trước" |
| Luật tự thêm | PASS | Lead thêm "sku khớp 0 hoặc >1 line → từ chối" rồi gắn cờ "anh xem kỹ", không lặng lẽ ruling |
| `plans/` không lọt vào `git status` | PASS, cách khác | Lead không sửa được `.git/info/exclude` vì hook `scout-block` chặn mọi đường dẫn `.git`. Lead tạo `plans/.gitignore` chứa `*`. Lượt 1 thì báo bị chặn và nhờ Human |

## 3. Sửa rút ra

- Mẫu plan: `skills/sequence-execution-plan/references/plan-template.md`, cộng dòng gate trong
  `lead.md`.
- Không commit plan: đổi từ `.git/info/exclude` sang `plans/.gitignore` chứa `*`. Không cần chạm
  `.git/` nên không vướng hook, và file tự bỏ qua chính nó.
- Luật chẻ: bắt buộc chẻ khi ruling chưa chốt. Item chạm nhiều boundary được gộp nếu ruling đã
  chốt, nhưng dòng Chẻ phải ghi lý do. Ở lab này Lead vẫn chọn chẻ, vì B chạm ba file và ba boundary
  khác nhau.

## 4. Chưa đo

- Pha code sau khi chẻ F2/F3/F4, tức số `REJECT` và dòng test: lab hẹp không chạy writer.
- Trường hợp gộp có lý do ("không chẻ, ruling ở `<sha>`") cho một item code thật.
