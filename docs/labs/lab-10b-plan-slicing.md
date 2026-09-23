# Lab 10b — Chẻ việc, plan.md, Human duyệt plan (chạy lại Lab 10)

[← Mục lục lab](README.md) · [Quy ước chung](common.md) · [Lab 10](lab-10-architect-design-lanes.md)

> **Đo:** gói lập kế hoạch trên nhánh `feat/plan-slicing`: `sequence-execution-plan` chẻ lát dọc
> (ba dấu hiệu phải chẻ, trường Test seam, `REJECT` thứ hai → soi có phải chẻ), plan ghi ra
> `plans/…/plan.md` có sơ đồ Mermaid, Human duyệt plan trước writer đầu (≥3 item hoặc chạm
> boundary); `goal-griller` hỏi theo vòng. Kèm hai luật `lead.md` sau Lab 10 (giữ ngôn ngữ, luật tự
> thêm) · **Trạng thái:** **PARTIAL** (2026-09-24, headless, có Supervisor) · **Fixture:** y hệt
> Lab 10 §1, repo `~/.slp-lab/lab10b`, base `dc34590`
>
> **Kết luận nhanh:** các luật về *cách nói với Human* đều ăn: hỏi theo vòng, 0 câu hỏi giữa pha
> code, tiếng Việt suốt phiên, không có `REJECT` theo luật tự thêm. Các luật về *cấu trúc plan*
> thì không ăn khi chưa ai nhắc. Lead giao writer khi chưa có plan pha code. Plan không có
> Mermaid, không có test seam. F1 gộp bốn boundary, tới khi Human nhắc mới chẻ. Sau khi chẻ, số
> dòng test giảm 39% nhưng số `REJECT` vẫn là 4.

## 1. Chạy

Fixture và cách chạy như Lab 10 §1–2 (`install.sh --dir` từ local clone nhánh này). Human (session
Claude khác) trả lời nhất quán với ruling của Lab 10. Các lượt Human:

1. Prompt đầu y hệt Lab 10.
2. Trả câu hỏi intake: mobile cần thấy phần đã hoàn, **chỉ bằng key thêm**; chỉ hoàn nguyên món;
   đơn đã hoàn một phần vẫn giao được.
3. Chọn khuyến nghị của Lead (B làm xương sống, payload `refunded_lines` của A). Sku trùng →
   từ chối hoàn theo món, `refund()` toàn bộ vẫn được. Bug tách riêng, làm trước. Món cuối tự
   `REFUNDED`. Không nới chữ ký `to_dict`. Cho sửa `CLAUDE.md` qua `LEAD-WROTE`.
4. `ACCEPT f5e0bff`, rồi **nhắc**: "pha code em chưa có plan… lập plan và gửi anh duyệt".
5. Chọn F0b (a). **Nhắc lần hai**: "F1 trông to, chạm cả C3, C4, C5 lẫn public API; soi lại theo
   skill xem có cần chẻ không".
6. Duyệt plan v2: F0b → F1a → F1b, mỗi cái có Reviewer; câu hỏi gom một lượt.

## 2. So với Lab 10

| Số đo | Lab 10 | Lab 10b |
|---|---|---|
| `REJECT` pha code | 4 (cùng W2) | 4 (F1a ×3, F1b ×1), cộng 1 `ACCEPT` bị rút lại |
| Dòng test thêm | 966 | 589 |
| Số test | 147 | 33 |
| Reviewer spawn | 7 | 6 |
| Câu hỏi Human giữa pha code | 5 (giữa W2) | 0, gom 9 câu vào báo cáo cuối |
| Lead trả tiếng Anh | có, khoảng R13–R20 | 0 đoạn |
| `ACCEPT` trước khi Reviewer về (`D9`) | 1 | 2 (Supervisor `ESCALATE`) |

## 3. PASS / FAIL theo luật

| Luật | Kết quả | Evidence |
|---|---|---|
| `goal-griller` hỏi theo vòng | PASS | Lượt 1: 1 câu chặn và 2 câu phụ trong một message, câu nào cũng có đáp án đề xuất. Lượt so sánh: 3 câu và 1 câu tuỳ chọn, đánh số |
| Plan ghi ra `plans/…/plan.md` | PASS | `plans/260923-2226-partial-refund-design/plan.md` (207 dòng); cập nhật theo ruling, verdict và plan v2; không commit, writer không stage |
| Plan có Mermaid và cột Test seam | **FAIL** | Cả ba lần gọi `sequence-execution-plan` đều dùng bảng cũ, 0 sơ đồ, 0 "seam" |
| Human duyệt plan trước writer đầu | **FAIL → PASS sau nhắc** | Sau lượt 3, Lead commit `LEAD-WROTE` rồi spawn writer F0 luôn, không lập plan pha code. Lead chỉ lập plan sau lượt 4 và dừng chờ duyệt. Plan v2 được duyệt thì Lead mới giao F0b |
| Chẻ lát dọc (ba dấu hiệu) | **FAIL → PASS sau nhắc** | Plan v1: F1 chạm C3+C4+C5+API trong một item. Sau lượt 5, Lead chẻ thành F1a (lớp tiền) và F1b (lớp wire), có lý do và ghi 4 cách chẻ đã loại |
| `REJECT` thứ hai → soi có phải chẻ | **không kích hoạt** | Ở `REJECT` thứ hai của F1a, Lead chỉ soi *luật tự thêm*, không soi chẻ. Các finding đều là "mutation sống, test chưa ghim", cùng một nguồn, nên không chẻ là hợp lý |
| Luật tự thêm | PASS, có vết mềm | Lead không `REJECT` F0 vì bug `pay()` ("REJECT … vì lỗi nó không gây ra là tự thêm luật") mà đưa sang F0b. Mỗi `REJECT` ghi nguồn (C5, I1/R2/R3). Vết mềm: Lead tự ruling 3 chỗ `CLAUDE.md` không nói (`refunded_total` đếm gì, dòng giá 0, điều kiện đóng đơn) rồi `REJECT` vì test chưa ghim chúng, và chỉ báo Human ở cuối |
| Giữ ngôn ngữ Human | PASS | 0 đoạn text dài của Lead không có dấu tiếng Việt suốt phiên |
| Brief qua `prompt-leverage` | FAIL ×2, Supervisor bắt | Brief bug F0 và brief sửa kèm `REJECT` không qua gate → `D13`. Lead tự nhận và ghi luật vào memory |
| Architect gọi `xia` | **FAIL** (Lab 10 PASS) | Hai lane không gọi `xia`, dù `peer.md:45` bắt buộc. Supervisor báo `D13`, nhưng Lead cãi rằng `xia` "có điều kiện", tức là đọc luật của Lead, không phải luật của Peer. Brief cho Architect ghi 1 file design vào `plans/` |
| `main` không đổi, 0 push | PASS | `main` = `dc34590`; nhánh `feat/partial-refund` @ `03f9519`, 33 test pass; remote rỗng |

## 4. Đọc kết quả

1. **Gate duyệt plan không bắt được lúc chuyển pha.** Lead gọi `sequence-execution-plan` trước
   brief *thiết kế* (3 item read-only, dưới ngưỡng). Khi Human chọn phương án, gate trong
   `lead.md` ("gọi trước brief đầu tiên") coi như đã qua, nên Lead đi thẳng vào writer. Cần
   thêm: đổi từ thiết kế sang code là replan, phải lập plan pha code và qua ngưỡng duyệt.
2. **Lead có gọi skill nhưng không theo format.** Mermaid, Test seam và ba dấu hiệu chẻ nằm trong
   skill, nhưng Lead viết plan theo quán tính của bảng Artifact cũ. Các mục đó mới chỉ có ở phần
   mô tả và quality gate, chưa có ở một mẫu file mà Lead phải điền theo.
3. **Chẻ đúng vẫn không giảm `REJECT`.** F1a vẫn qua 4 vòng. Nguyên nhân lần này là chất lượng
   test ("mutation sống"), không phải item quá to: Reviewer đo bằng mutation còn Lead soát bằng
   mắt. Sau khi Lead chuyển sang giữ verdict tới khi Reviewer về, F1b chỉ mất 1 vòng.
4. Human phải nhắc hai lần (lượt 4, 5) thì mới có plan và độ chẻ đúng như gói yêu cầu. Nếu không
   có hai lần nhắc đó, lần chạy này sẽ đi lại đường của Lab 10.

## 5. Ghi chú runtime

- `-p`: `Agent` có `name` chạy thành subagent nền. Lead nhận kết quả qua lượt tự kích hoạt, nên
  một lượt Human có thể sinh ra nhiều `result`.
- Supervisor trả Human bằng tiếng Anh trong khi Human viết tiếng Việt. Luật giữ ngôn ngữ mới có
  trong `lead.md`, `supervisor.md` chưa có.
- Lead đọc nhầm "mỗi cái có Reviewer như em ghi" thành yêu cầu thêm Reviewer cho F0b. Ở vòng 2
  của F1b, Lead lại bỏ Reviewer và khai thẳng việc đó.
