# Lab 10c — Mẫu plan.md, gate chuyển pha, Architect luôn `xia` (chạy lại Lab 10)

[← Mục lục lab](README.md) · [Quy ước chung](common.md) · [Lab 10b](lab-10b-plan-slicing.md)

> **Đo:** ba sửa sau Lab 10b (commit `bb20f80`):
> 1. Đổi từ thiết kế sang code là plan mới, phải qua ngưỡng duyệt.
> 2. `plan.md` theo mẫu bắt buộc (Mermaid, cột Test seam, dòng Chẻ) và `plans/` vào `.git/info/exclude`.
> 3. Architect luôn gọi `xia`, ghi 0 file.
>
> **Trạng thái:** **PARTIAL** (2026-09-24, headless, có Supervisor) · **Fixture:** y hệt Lab 10 §1,
> repo `~/.slp-lab/lab10c`, base `dc34590`
>
> **Kết luận nhanh:** gate chuyển pha và `xia` đã ăn mà không cần nhắc. Human chỉ gõ 3 lượt, 0 lần
> nhắc. Mẫu plan thì vẫn không ăn: Lead gọi skill hai lần nhưng cả hai lần viết theo danh sách
> "Artifact 1–8" đứng trước mẫu, và bỏ qua bước exclude. W2 chạm 4 boundary nhưng không được chẻ.
> Dù vậy, pha code chỉ có **1 `REJECT`** (Lab 10: 4, Lab 10b: 4).

## 1. Chạy

Cài bằng `install.sh --dir` từ local clone `bb20f80`. Human là một session Claude khác, trả lời
nhất quán với ruling của Lab 10/10b, và **không nhắc** về plan hay độ chẻ.

1. Prompt đầu y hệt Lab 10.
2. Lead đưa hai phương án kèm 6 câu hỏi đánh số trong một lượt. Human trả lời:
   - chọn A;
   - chỉ hoàn nguyên món;
   - PAID hoàn một phần xong vẫn giao được;
   - tách bug ra làm trước;
   - cho sửa `CLAUDE.md`.
3. Lead ghi `LEAD-WROTE dac2b60`, **tự** gọi lại `sequence-execution-plan` cho pha code, ghi
   `plan-code.md`, rồi dừng chờ duyệt. Human: `ACCEPT dac2b60`, chọn subagent thường, duyệt plan
   nguyên trạng. Plan để nguyên W2 chưa chẻ, để đo trigger `REJECT` thứ hai.

## 2. So với Lab 10 / 10b

| Số đo | Lab 10 | Lab 10b | Lab 10c |
|---|---|---|---|
| `REJECT` pha code | 4 | 4, cộng 1 `ACCEPT` bị rút | **1** (W2, thiếu test ghim guard trạng thái) |
| Dòng test thêm | 966 | 589 | **322** |
| Số test cuối | 147 | 33 | 30 |
| Reviewer spawn | 7 | 6 | **2** |
| Human nhắc về plan/chẻ | — | 2 | **0** |
| Câu hỏi Human giữa pha code | 5 | 0 | 0, gom 5 câu vào báo cáo cuối |
| `ACCEPT` trước khi Reviewer về (`D9`) | 1 | 2 | **0** |
| Supervisor `DRIFT`/`ESCALATE` | — | có (`D13`, `D9`) | **0**, chỉ `NOTE no drift` |

## 3. PASS / FAIL theo luật

| Luật | Kết quả | Evidence |
|---|---|---|
| Đổi thiết kế → code là plan mới, qua ngưỡng | **PASS** (10b FAIL) | Lead gọi `sequence-execution-plan` lần 2, ghi `plan-code.md` thành file riêng, và hỏi "duyệt kế hoạch" trước khi giao writer W1 |
| Mỗi pha một file | PASS | `plan.md` (thiết kế), `plan-code.md` (code) |
| Mẫu: Mermaid, Test seam, dòng Chẻ | **FAIL** | 0 sơ đồ ở cả hai file. Bảng có cột `Type`, `Unc.` nhưng không có Test seam. Mục đánh số `1. Outcome … 8. Trigger replan` chép đúng danh sách "Artifact" của skill |
| `plans/` vào `.git/info/exclude` | **FAIL** | `git status` vẫn ra `?? plans/`. Writer không stage nhầm nhờ owned scope, không nhờ exclude |
| Cập nhật State + SHA trong plan | FAIL | Sau các verdict, cột State vẫn là `candidate` / `blocked` |
| Chẻ lát dọc | **FAIL** (không nhắc) | W2 gộp `refund_items`, key `to_dict` và việc `refund()` đánh dấu món, chạm C1+C3+C5+API. Plan không có dòng Chẻ |
| `REJECT` thứ hai → soi chẻ | không kích hoạt | Chỉ có 1 `REJECT` |
| Architect gọi `xia`, 0 write | **PASS** (10b FAIL) | Supervisor: cả hai lane gọi `xia` trước file đầu, không có `Edit`/`Write`. Design trả qua handoff |
| `prompt-leverage` trước mọi brief | PASS | 6 lần gọi, có cả brief sửa sau `REJECT`. Supervisor ghi rõ đây là chỗ 10b lệch |
| `D9` Reviewer trước verdict | PASS | R1 và R2 về trước `ACCEPT`/`REJECT`. `5da0e4d` chỉ thêm test nên không review lại, và Lead khai điều này |
| `main` không đổi, 0 push | PASS | `main` = `dc34590`; `feat/partial-refund` @ `5da0e4d`, 30 test pass |

## 4. Đọc kết quả

1. **Skill có hai khung, Lead chọn khung đầu.** Danh sách "Artifact 1–8" đứng trước mẫu, và mẫu
   chỉ là mục con "File plan". Lead có đọc skill nhưng điền theo khung đầu. Đã sửa: bỏ danh sách,
   để mẫu *là* Artifact (đưa Outcome, Dependency và Risk vào trong mẫu), và exclude thành lệnh cụ
   thể có bước kiểm `git status`. Bản sửa này **chưa được lab đo**.
2. **Luật viết ở chỗ Lead đọc lúc quyết định thì ăn.** Gate chuyển pha nằm ở `lead.md` ("Lane
   thiết kế mù") và `xia` nằm ở luật của Peer: cả hai PASS ngay lần đầu. Mẫu plan nằm sâu trong
   skill, sau một khung cạnh tranh: FAIL hai lần liên tiếp.
3. **Ít `REJECT` dù W2 không chẻ.** W2 qua trong 2 vòng. Lý do có thể nằm ở ruling `CLAUDE.md` và
   brief: tên hàm, các trường hợp từ chối và key wire đều chốt trước khi writer viết test. Lab 10
   và 10b vòng nhiều ở đúng những chỗ này. Một lần chạy chưa đủ để nói chẻ không cần thiết.
4. Engineer thêm hai hàm public ngoài ruling (`check_transition`, `Order.refunded_total()`). Lead
   chấp nhận và khai rõ trong báo cáo cuối. Cách xử lý này hợp luật, vì API cho phép "thêm hàm mới".

## 5. Ghi chú runtime

- Lead tự nêu chuyện topology (subagent không phải teammate) và hỏi Human trước writer đầu.
  Human chọn subagent thường như các lab trước.
- Supervisor trả lời Human bằng tiếng Việt suốt phiên (10b trả tiếng Anh).
