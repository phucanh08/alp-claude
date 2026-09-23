# Lab 10e — Chạy trọn pha code trên plan theo mẫu, có Supervisor

[← Mục lục lab](README.md) · [Quy ước chung](common.md) · [Lab 10d](lab-10d-plan-template-narrow.md)

> **Đo:** pha code sau gói lập kế hoạch (PR #3, `d309989`) và luật "đọc Git bằng lệnh `git`"
> (`6e14027`). Số đo: số `REJECT`, dòng test, Reviewer, chi phí. · **Trạng thái:** **PASS có
> nhắc 1 lần** (2026-09-24, headless, có Supervisor) · **Fixture:** y hệt Lab 10 §1, repo
> `~/.slp-lab/lab10e`, base `f00b71c`
>
> **Kết luận nhanh:** pha code có **1 `REJECT`**, bằng Lab 10c. I2 chạm 5 boundary nhưng
> không chẻ, vì ruling đã chốt ở `160fca3`, và dòng Chẻ ghi lý do. Đây là lần đầu trường hợp "gộp
> có lý do" chạy thật. `REJECT` đến từ test chưa cô lập guard, không đến từ ruling. Mẫu plan lúc
> đầu FAIL: `Skill` nạp bản **cũ** ở `~/.claude/skills`, bản đó chưa có `plan-template.md`. Human
> chỉ đường một lần thì Lead ghi lại plan đúng mẫu.

## 1. Chạy

Cài bằng `install.sh --dir` từ nhánh `feat/git-via-commands` (`6e14027`). Human là session này,
trả lời nhất quán với ruling Lab 10c/10d.

1. Prompt đầu y hệt Lab 10. Hai Architect gọi `xia`, ghi 0 file, và hội tụ cùng một hướng (giữ
   state machine, thêm `refunded_qty` theo line). Lead nói thẳng là không có hai phương án thật.
   Lead chỉ tách hai biến thể A/B ở chỗ chống hoàn trùng, rồi hỏi 5 câu.
2. Human: chọn B, trả lời 5 câu, cho sửa `CLAUDE.md`. Lead ghi `LEAD-WROTE 160fca3`, gọi lại
   `sequence-execution-plan`, và dừng chờ duyệt.
3. Human: `ACCEPT 160fca3`, đồng ý 3 điểm Lead tự chốt, **nhắc** là plan chưa theo mẫu và chỉ
   đường dẫn mẫu trong repo, rồi duyệt trước plan. Từ đó Lead tự chạy đến hết mà không hỏi lại.

## 2. Số đo so với Lab 10 / 10b / 10c

| Số đo | Lab 10 | Lab 10b | Lab 10c | Lab 10e |
|---|---|---|---|---|
| `REJECT` pha code | 4 | 4 | 1 | **1** (I2: 2 guard xoá đi vẫn xanh) |
| Dòng test thêm | 966 | 589 | 322 | **405** (có thêm task sửa bug) |
| Số test cuối | 147 | 33 | 30 | 49 |
| Reviewer spawn | 7 | 6 | 2 | **2** |
| Writer spawn | — | — | — | 2 (`eng-i1`, `eng-i2`) |
| Lượt Human | — | — | 3 | 3, trong đó 1 lần nhắc mẫu |
| Kết quả Lead (turn `result`) | — | — | — | 10 |
| Thời gian | — | — | — | ~9 phút thiết kế + ~13 phút code |
| `D9` (verdict trước Reviewer) | 1 | 2 | 0 | **0** |
| Supervisor `DRIFT` | — | có | 0 | **0**, chỉ `NOTE` |

## 3. PASS / FAIL theo luật

| Luật | Kết quả | Evidence |
|---|---|---|
| Mẫu plan (Mermaid, Test seam, Chẻ) | **FAIL → PASS sau nhắc** | Hai plan đầu ghi "plan-template.md của skill không tồn tại". `Skill` báo `Base directory: ~/.claude/skills/sequence-execution-plan`: đó là bản cài ngày 23/9, chưa có `references/plan-template.md`. Bản trong repo lab có. Sau khi được nhắc, plan pha code có Mermaid 5 node, cột Test seam và dòng Chẻ; State + SHA được cập nhật tới cuối |
| Chẻ theo ruling | **PASS** | "I2 — chạm C1, C2, C3, C4, API + 4 nhóm hành vi — không chẻ, ruling ở `160fca3` + 3 điểm Human; mọi nhóm có expected cụ thể trong brief". Trigger ghi sẵn: `REJECT` thứ hai ở nhóm khác thì chẻ I2 |
| Gate chuyển pha + duyệt | PASS | Sau `LEAD-WROTE 160fca3`, Lead dừng chờ "accept + duyệt plan" |
| `plans/.gitignore` | PASS | Lead tự tạo, `git status` sạch suốt phiên |
| Đọc Git bằng lệnh `git` | PASS | Không có lần `Read`/`cat` nào vào `.git/`, hook không chặn lần nào |
| Architect `xia`, 0 write | PASS | 2 lần `xia`, HEAD không đổi sau pha thiết kế |
| `prompt-leverage` trước brief | PASS | 12 lần gọi, có cả brief sửa sau `REJECT` |
| `bug-loop` cho task bug | PASS | I1: 4 test đỏ trên base, xanh sau khi sửa; Lead tự chạy lại |
| `D9` | PASS | R1 và R2 về trước verdict. Bản sửa `d7e6200` chỉ thêm test, Lead tự chạy lại mutation |
| Ruling tự chốt được khai | PASS | Lead khai 4 chi tiết idempotency tự chốt cho I2, và 2 guard writer tự thêm, trước verdict |
| 0 push | PASS | Không có remote nào được đụng |

## 4. Đọc kết quả

1. **Gộp có lý do không làm tăng `REJECT`.** I2 chạm 5 boundary, 4 nhóm hành vi, và qua trong 2
   vòng. `REJECT` duy nhất là do test chưa cô lập: guard trạng thái và guard sku lặp đều bị guard
   khác "che", nên xoá đi mà test vẫn xanh. Chẻ I2 không sửa được lỗi này, Reviewer mutation mới
   sửa được. Luật hiện tại đã cho gộp khi ruling đã chốt, nên **không cần nới thêm**.
2. **Chi phí:** 2 writer, 2 Reviewer, khoảng 13 phút cho pha code. Số dòng test tăng so với 10c
   (405 so với 322) vì có thêm task bug I1 và yêu cầu L3 cho từng guard, không phải vì chẻ.
3. **Skill global che skill repo.** `~/.claude/skills` của máy Human có bản cũ của 4 skill
   (`sequence-execution-plan`, `prompt-leverage`, `goal-griller`, `ask-alp`), và `Skill` nạp bản
   đó thay vì bản trong `.claude/skills` của repo. Lab 10b–10d có thể cũng bị ảnh hưởng: ở 10d,
   Lead thử đường dẫn global trước rồi mới đọc bản repo. Đã sửa `lead.md`:
   - Bootstrap bước 2: nếu `Skill` báo nạp từ `~/.claude/skills` mà repo có skill cùng tên, `Read`
     bản repo.
   - Dòng sequence: ghi đường dẫn mẫu đầy đủ (repo trước, global sau); không thấy ở đâu thì báo
     Human, không viết plan theo trí nhớ.
   Bản sửa này **chưa được lab đo**.
4. Lead commit thẳng lên `main` của repo lab. Lab 10c thì dùng `feat/partial-refund`. Prompt không
   yêu cầu nhánh, và `lead.md` không có luật nào về nhánh cho writer đơn. Ghi lại để quan sát, không
   tính là lệch.

## 5. Còn mở (Lead tự khai trong báo cáo cuối)

- `ref` chống trùng trong ledger chỉ nằm trong bộ nhớ, không có trong `entries()`.
- Line có `qty` 0 bị tính là đã hoàn.
- Test `pay()` trên đơn REFUNDED chưa từng được thấy đỏ trên code cũ.
- Test guard trạng thái dựng trạng thái bằng tay; luồng thường không tạo ra trạng thái đó.
