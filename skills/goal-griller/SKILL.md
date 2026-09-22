---
name: goal-griller
description: Biến những ý tưởng mơ hồ thành Task Contract kiểm chứng được trước khi Lead chẻ việc hay giao writer. Dùng khi Human đưa yêu cầu thiếu outcome/proof/scope, khi Lead định spawn writer mà chưa trả lời được "xong là gì", hoặc khi được gọi /goal-griller.
---

# Goal Griller — nướng ý định thành Task Contract

Vị trí trong SLP: **cổng vào** (intake). Human nói ý; Lead không chẻ việc, không viết brief,
không spawn writer khi chưa trả lời được *xong là gì* và *chứng minh bằng gì*. Skill này là cuộc
phỏng vấn ngắn: mỗi lần một câu, kèm đáp án đề xuất, tự tra repo trước khi hỏi.

Ai dùng:

- **Lead** — mặc định, tại intake, trước `sequence-execution-plan` và trước mọi brief.
- **Human** — có thể tự chạy ở session thường để đưa Lead một contract sẵn.
- **Peer** — không. Peer thiếu field thì `BLOCKED` về Lead, không phỏng vấn Human.

## Hard gate — sáu ô

Chưa đủ sáu ô → chưa có Task Contract. Chưa có Task Contract → không giao writer.

| # | Ô | Câu hỏi phải trả lời được | Đổ vào đâu trong SLP |
|---|---|---|---|
| 1 | Outcome | Cuối cùng điều gì phải đúng? Một câu, quan sát được | `Objective` của brief |
| 2 | Proof | Chứng minh bằng lệnh/artifact nào mà người khác chạy lại được? | `Verification` của brief; ô `Verification` của handoff |
| 3 | Scope | Được đổi gì, cấm đổi gì | `Owned scope` / `Excluded scope` |
| 4 | Context | Đọc gì trước khi làm: file, doc, log, issue, lệnh | phần context của brief |
| 5 | Validation loop | Check rẻ chạy lặp trong lúc làm; check đầy đủ chạy cuối | `Verification` (fast vs full) |
| 6 | Stop / pause | Xong khi nào; dừng hỏi Human khi nào thay vì tự chế | `Authority`; điều kiện `BLOCKED` |

Ô nào chạm **boundary** mà `CLAUDE.md` đánh dấu (schema, public API, allowlist, contract path…)
→ contract phải ghi **ruling hướng đi** cho boundary đó, hoặc ghi rõ *chưa ruling, Peer dừng
`BLOCKED` khi chạm*. Không có đường "Peer tự quyết cho nhất quán".

## Vòng phỏng vấn

1. Nhắc lại ý định trong **một câu**.
2. Chọn ô **yếu nhất** còn thiếu.
3. Tra được từ repo thì tra, không hỏi: `CLAUDE.md`, README, test hiện có, script, log,
   `git log`. Cần đọc rộng hơn vài file → giao một Peer **Scout** read-only với skill `xia`;
   Lead không tự đọc cả repo để điền ô.
4. Hỏi **đúng một câu**. Kèm đáp án đề xuất và vì sao đáp án đó có lẽ đúng.
5. Human trả lời → cập nhật contract → quay lại bước 2.

Ba câu sắc hơn mười câu chung. Đủ sáu ô thì dừng hỏi ngay.

## Thứ tự câu hỏi

Trừ khi repo cho thấy chỗ tắc khác:

1. Cuối cùng điều gì phải đúng?
2. Chứng minh thế nào?
3. Cái gì cấm đụng?
4. Đọc gì, giữ gì trước khi làm?
5. Check nào chạy lặp, check nào chỉ chạy cuối?
6. Khi nào phải dừng hỏi thay vì tự chế?
7. Để lại proof gì để Lead/Human chấm?

## Từ chối đề mơ hồ

| Đề thô | Viết lại thành outcome + proof |
|---|---|
| "Cải thiện app" | "Dashboard load lần đầu nhanh hơn ≥25%, không đổi hành vi nhìn thấy; proof: output benchmark trước/sau + screenshot" |
| "Sửa hết bug" | "Suite Playwright checkout đang đỏ chuyển xanh; luồng thanh toán thành công hiện có vẫn pass" |
| "Refactor codebase" | "Gom logic auth/session trùng lặp về một module; toàn bộ test hiện có và public API giữ nguyên" |
| "Làm cho production-ready" | Hỏi: *production-ready đo bằng gì ở repo này?* — cho tới khi có lệnh/metric cụ thể |
| "Nghiên cứu rồi làm cái tốt nhất" | Tách: Scout `xia` trả brief → Human/Lead chọn → mới có outcome |

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
Pause if       <điều kiện → BLOCKED / hỏi Human>
Risk           <rủi ro chính, và proof artifact chứng minh nó không xảy ra>
```

Contract này là input cho `sequence-execution-plan` (khi nhiều work item) hoặc đổ thẳng vào brief
qua `prompt-leverage` (khi một item).

## Không tự khởi động

- Human chỉ nhờ nướng contract → trả contract, **không** spawn, không sửa file.
- Có phỏng vấn hoặc suy diễn → đưa Human xem contract cuối, Human xác nhận rồi Lead mới delegate.
  Lead ghi contract vào memory checkpoint (`.claude/agent-memory-local/lead/`).
- Human ép "cứ làm đi" khi còn ô trống → Lead vẫn không giao writer. Được phép giao Scout
  read-only đi lấy dữ liệu cho ô trống; không được đặt placeholder rồi commit (Lab 2).

## Anti-pattern

- Hỏi ba câu một lượt → Human trả lời lửng, ô nào cũng nửa vời.
- Hỏi thứ `grep` ra được.
- Coi "test pass" là Proof khi test đó chưa tồn tại và contract chưa nói ai viết.
- Contract có Outcome nhưng Proof là "review thấy ổn".
