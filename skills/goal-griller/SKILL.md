---
name: goal-griller
description: Biến những ý tưởng mơ hồ thành Task Contract kiểm chứng được trước khi chẻ việc hay giao writer. Dùng khi yêu cầu thiếu outcome/proof/scope, khi định giao writer mà chưa trả lời được "xong là gì", hoặc khi được gọi /goal-griller. Cần có kênh hỏi người yêu cầu; nhận việc qua brief thì không dùng.
---

# Goal Griller — nướng ý định thành Task Contract

Vị trí trong SLP: **cổng vào** (intake). Người yêu cầu nói ý; người giao việc không chẻ việc,
không viết brief, không giao writer khi chưa trả lời được *xong là gì* và *chứng minh bằng gì*.
Skill này là cuộc phỏng vấn ngắn theo vòng: mỗi vòng hỏi hết các câu hỏi được ngay, mỗi câu kèm đáp
án đề xuất, tự tra repo trước khi hỏi.

Điều kiện dùng (ghế nào ứng với gì: `/ask-alp`):

- Bạn có **kênh hỏi người yêu cầu** và **quyền chẻ việc** — mặc định, tại intake, trước
  `sequence-execution-plan` và trước mọi brief.
- Người yêu cầu tự chạy ở session thường để đưa sẵn contract cho người giao việc — được.
- Bạn **nhận việc qua brief**, không có kênh hỏi người yêu cầu — không dùng. Thiếu ô → `BLOCKED`
  kèm ô thiếu, trả về người giao việc; không phỏng vấn ai.

## Hard gate — sáu ô

Chưa đủ sáu ô → chưa có Task Contract. Chưa có Task Contract → không giao writer.

| # | Ô | Câu hỏi phải trả lời được | Đổ vào đâu trong SLP |
|---|---|---|---|
| 1 | Outcome | Cuối cùng điều gì phải đúng? Một câu, quan sát được | `Objective` của brief |
| 2 | Proof | Chứng minh bằng lệnh/artifact nào mà người khác chạy lại được? | `Verification` của brief; ô `Verification` của handoff |
| 3 | Scope | Được đổi gì, cấm đổi gì | `Owned scope` / `Excluded scope` |
| 4 | Context | Đọc gì trước khi làm: file, doc, log, issue, lệnh | phần context của brief |
| 5 | Validation loop | Check rẻ chạy lặp trong lúc làm; check đầy đủ chạy cuối | `Verification` (fast vs full) |
| 6 | Stop / pause | Xong khi nào; dừng hỏi người yêu cầu khi nào thay vì tự chế | `Authority`; điều kiện `BLOCKED` |

Ô nào chạm **boundary** mà `CLAUDE.md` đánh dấu (schema, public API, allowlist, contract path…)
→ contract phải ghi **ruling hướng đi** cho boundary đó, hoặc ghi rõ *chưa ruling, writer dừng
`BLOCKED` khi chạm*. Không có đường "writer tự quyết cho nhất quán".

## Vòng phỏng vấn

1. Nhắc lại ý định trong **một câu**.
2. Liệt kê các ô còn thiếu; câu nào **không phụ thuộc** câu trả lời chưa có là câu hỏi được ngay.
3. Tra được từ repo thì tra, không hỏi: `CLAUDE.md`, README, test hiện có, script, log,
   `git log`. Cần đọc rộng hơn vài file → giao một **Scout** read-only với skill `xia`; không
   tự đọc cả repo để điền ô. Tính từ mơ hồ ("production-ready", "sạch", "chuẩn") **không
   phải việc recon**: đó là ô Outcome trống → hỏi người yêu cầu trước, chỉ giao Scout đo khi
   họ nói muốn đo (Lab 7c: Scout liệt kê 13 gap, người yêu cầu chỉ muốn test + README).
4. Hỏi **cả vòng** trong một message: đánh số, mỗi câu một ý, kèm đáp án đề xuất và vì sao đáp án
   đó có lẽ đúng. Câu phụ thuộc câu khác trong vòng → để vòng sau.
5. Người yêu cầu trả lời → cập nhật contract → quay lại bước 2.

Ba câu sắc hơn mười câu chung — vòng nào quá năm câu thì bỏ câu tra được hoặc để sau. Đủ sáu ô
thì dừng hỏi ngay. Lý do hỏi theo vòng: câu hỏi lộ dần giữa việc buộc người yêu cầu trả lời
nhiều lượt và writer phải dừng chờ (Lab 10: 5 câu ở intake, thêm 5 câu giữa item thứ hai).

## Thứ tự câu hỏi

Trừ khi repo cho thấy chỗ tắc khác:

1. Cuối cùng điều gì phải đúng?
2. Chứng minh thế nào?
3. Cái gì cấm đụng?
4. Đọc gì, giữ gì trước khi làm?
5. Check nào chạy lặp, check nào chỉ chạy cuối?
6. Khi nào phải dừng hỏi thay vì tự chế?
7. Để lại proof gì để người chấm dùng?

## Từ chối đề mơ hồ

| Đề thô | Viết lại thành outcome + proof |
|---|---|
| "Cải thiện app" | "Dashboard load lần đầu nhanh hơn ≥25%, không đổi hành vi nhìn thấy; proof: output benchmark trước/sau + screenshot" |
| "Sửa hết bug" | "Suite Playwright checkout đang đỏ chuyển xanh; luồng thanh toán thành công hiện có vẫn pass" |
| "Refactor codebase" | "Gom logic auth/session trùng lặp về một module; toàn bộ test hiện có và public API giữ nguyên" |
| "Làm cho production-ready" | Hỏi người yêu cầu *trước* khi giao Scout: *production-ready đo bằng gì ở repo này?* — cho tới khi có lệnh/metric cụ thể |
| "Nghiên cứu rồi làm cái tốt nhất" | Tách: Scout `xia` trả brief → người yêu cầu / người giao việc chọn → mới có outcome |

## Task Contract — output

```text
TASK CONTRACT <task id>
Outcome        <một câu, quan sát được>
Proof          <lệnh + kết quả mong đợi, hoặc artifact cụ thể>
Scope          may change: <path/glob>    must not change: <path/glob>
Boundary       <boundary trong CLAUDE.md bị chạm + ruling, hoặc: none>
Context        <file/doc/log/lệnh phải đọc trước>
Validation     during: <lệnh rẻ>    final: <lệnh đầy đủ>
Done when      <điều kiện, kiểm được>
Pause if       <điều kiện → BLOCKED / hỏi người yêu cầu>
Risk           <rủi ro chính, và proof artifact chứng minh nó không xảy ra>
```

Contract này là input cho `sequence-execution-plan` (khi nhiều work item) hoặc đổ thẳng vào brief
qua `prompt-leverage` (khi một item).

## Không tự khởi động

- Chỉ được nhờ nướng contract → trả contract, **không** giao việc, không sửa file.
- Có phỏng vấn hoặc suy diễn → đưa người yêu cầu xem contract cuối, họ xác nhận rồi mới giao
  việc. Ghi contract vào memory checkpoint nếu ghế của bạn có memory.
- Người yêu cầu ép "cứ làm đi" khi còn ô trống → vẫn không giao writer. Được phép giao Scout
  read-only đi lấy dữ liệu cho ô trống; không được đặt placeholder rồi commit (Lab 2).

## Anti-pattern

- Gộp câu phụ thuộc nhau vào một vòng → câu trả lời lửng, ô nào cũng nửa vời.
- Hỏi nhỏ giọt một câu mỗi lượt khi các câu độc lập → người yêu cầu trả lời năm lượt thay vì một.
- Hỏi thứ `grep` ra được.
- Giao Scout đi định nghĩa tính từ mơ hồ thay người yêu cầu → recon bỏ phí.
- Coi "test pass" là Proof khi test đó chưa tồn tại và contract chưa nói ai viết.
- Contract có Outcome nhưng Proof là "review thấy ổn".
