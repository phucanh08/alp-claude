---
name: bug-loop
description: Chẩn đoán bug và regression hiệu năng có kỷ luật — dựng vòng phản hồi đỏ được trên đúng bug, thu nhỏ repro, 3–5 giả thuyết falsifiable, instrument từng biến, rồi mới sửa kèm regression test có proof RED → GREEN (→ MUTATE → RED). Dùng khi việc là bug, test đỏ không rõ lý do, hành vi sai, chậm đi; khi brief ghi `Required skills: bug-loop`; hoặc khi được gọi /bug-loop. Read-only chạy được Phase 1–4; Phase 5–6 cần write authority.
---

# Bug Loop — chẩn đoán trước, sửa sau

Skill này là **cách làm**, không cấp authority. Ghế nào ứng với từ vựng nào: `/ask-alp`.

Luật SLP đè lên mọi phase dưới:

- **Không hỏi người yêu cầu.** Chỗ nào cần người khác (giả thuyết cần domain knowledge, môi
  trường tái hiện, artifact bắt được, người thật phải bấm) → báo người giao việc: đưa vào handoff,
  hoặc `BLOCKED` nếu không đi tiếp được.
- **Read-only** (không có write lease): chạy Phase 1–4, rig dựng ở `/tmp`, trả kết luận + lệnh
  đỏ được trong handoff. Phase 5–6 là của writer.
- **Writer**: chỉ sửa trong owned scope. Rig, instrument, mutation tạm đều không lọt vào commit.
- **Seam** = vị trí trong code nơi test quan sát hành vi. **Boundary** giữ nghĩa SLP: contract
  mà người giao việc ruling. Test đặt ở seam nằm trên boundary chưa có ruling → `BLOCKED`.
- **Che secret**: mọi lệnh, output, artifact đưa ra đều thay secret bằng `<REDACTED>`; loop đọc
  credential từ env, không in ra. Output đã che không đủ để chẩn đoán → nói vậy với người giao việc.

## Phase 1 — Dựng vòng phản hồi

**Đây là cả skill.** Có một tín hiệu pass/fail đỏ được trên *đúng bug này* thì bisect, giả thuyết,
instrument chỉ còn là tiêu thụ nó. Không có thì đọc code bao nhiêu cũng không cứu được.

Cách dựng, gần đúng theo thứ tự thử:

1. Test fail ở seam nào chạm được bug: unit, integration, e2e.
2. Script curl/HTTP vào dev server đang chạy (port, DB là tài nguyên độc quyền: brief phải cấp).
3. Chạy CLI với fixture, diff stdout với snapshot đúng.
4. Headless browser script assert DOM/console/network.
5. Replay trace bắt được (request, payload, event log) qua đúng code path.
6. Harness vứt đi: dựng tập con nhỏ nhất của hệ, gọi một hàm là chạm bug.
7. Property/fuzz: bug "thỉnh thoảng sai" → 1000 input ngẫu nhiên có seed.
8. Bisection: bug xuất hiện giữa hai trạng thái → `git bisect run` trên một **worktree tạm ở
   `/tmp`**, không bao giờ trên checkout dùng chung.
9. Differential: cùng input qua bản cũ/bản mới hoặc hai config, diff output.
10. Người thật phải thao tác → `scripts/hitl-loop.template.sh`. Người đó không phải bạn gọi:
    chép script ra `/tmp`, điền bước, rồi `BLOCKED` về người giao việc kèm đường dẫn script.

**Siết vòng lặp**: nhanh hơn (bỏ init không liên quan, thu hẹp scope), tín hiệu sắc hơn (assert
đúng triệu chứng, không phải "không crash"), tất định hơn (ghim thời gian, seed RNG, cô lập file
system, chặn network). Loop 30 giây flaky gần như vô dụng; loop 2 giây tất định là siêu năng lực.

**Bug không tất định**: mục tiêu là **tăng tỷ lệ tái hiện**, không phải repro sạch. Lặp 100×,
song song, thêm tải, thu hẹp cửa sổ timing. 50% thì debug được; 1% thì chưa.

**Không dựng được loop** → dừng, nói thẳng, liệt kê đã thử gì, `BLOCKED` về người giao việc xin
một trong: quyền vào môi trường tái hiện được; artifact đã che (HAR, log dump, core dump, video có
timestamp); quyền thêm instrument tạm. **Không** sang giả thuyết khi chưa có loop.

**Xong Phase 1** khi gọi tên được **một lệnh** đã chạy ít nhất một lần (kèm invocation + output
đã che), và lệnh đó:

- [ ] **đỏ được**: chạy đúng code path lỗi, assert đúng triệu chứng người báo mô tả;
- [ ] **tất định**: cùng verdict mọi lần (flaky: tỷ lệ tái hiện đã ghim);
- [ ] **nhanh**: giây, không phải phút;
- [ ] **tự chạy được**: không cần người, trừ qua hitl script.

Đang đọc code để dựng lý thuyết mà lệnh này chưa tồn tại → dừng. Nhảy thẳng vào giả thuyết là đúng
lỗi skill này sinh ra để chặn.

## Phase 2 — Tái hiện + thu nhỏ

Chạy loop, thấy nó đỏ. Xác nhận:

- [ ] đỏ đúng **triệu chứng được báo**, không phải một lỗi khác nằm gần — sai bug là sai fix;
- [ ] tái hiện qua nhiều lần chạy (hoặc đủ tỷ lệ);
- [ ] đã chép lại triệu chứng chính xác (message, output sai, timing) để phase sau kiểm fix.

**Thu nhỏ**: cắt input, caller, config, data, bước — **từng thứ một**, chạy lại loop sau mỗi lần
cắt, chỉ giữ thứ gánh lỗi. Xong khi bỏ bất kỳ phần nào còn lại thì loop xanh. Repro tối giản thu
hẹp không gian giả thuyết và thành regression test sạch ở Phase 5.

## Phase 3 — Giả thuyết

Viết **3–5 giả thuyết xếp hạng** trước khi thử cái nào. Một giả thuyết duy nhất neo vào ý đầu tiên.

Mỗi giả thuyết phải **falsifiable**:

> "Nếu <X> là nguyên nhân thì <đổi Y> làm bug biến mất / <đổi Z> làm nó nặng hơn."

Không nói được dự đoán → là cảm giác, bỏ hoặc mài lại.

Danh sách xếp hạng đi vào handoff hoặc message cho người giao việc — họ có thể biết "#3 vừa đổi
tuần trước" hay đã loại #1. Không chờ trả lời; cứ đi theo thứ hạng của bạn.

## Phase 4 — Instrument

Mỗi probe ứng với một dự đoán ở Phase 3. **Đổi một biến mỗi lần.**

1. Debugger/REPL nếu môi trường có — một breakpoint hơn mười dòng log.
2. Log có chủ đích tại điểm phân biệt được các giả thuyết.
3. Không bao giờ "log hết rồi grep".

**Gắn tag mọi log debug**: tiền tố riêng, ví dụ `[DEBUG-a4f2]`. Dọn cuối cùng chỉ còn một lệnh
grep. Log không tag sống sót; log có tag chết.

**Nhánh hiệu năng**: log thường sai công cụ. Đo baseline trước (harness timing, profiler, query
plan), rồi bisect. Đo trước, sửa sau.

Read-only dừng ở đây: handoff ghi giả thuyết đã xác nhận + evidence + lệnh loop + seam đề xuất cho
regression test.

## Phase 5 — Sửa + regression test (writer)

Regression test viết **trước fix**, nhưng chỉ khi có **seam đúng**: seam mà test chạy lại đúng
pattern gây bug như ở call site thật. Seam quá nông (một caller trong khi bug cần nhiều caller;
unit test không dựng lại được chuỗi gây bug) cho niềm tin giả.

**Không có seam đúng thì đó chính là finding.** Ghi vào `Unknown / risk`: kiến trúc đang ngăn
khoá bug lại. Không ép test vào seam sai.

Có seam đúng:

1. Biến repro tối giản thành test fail ở seam đó; oracle lấy từ bug report / contract, không
   từ code đang chạy (`references/test-proof.md` §1).
2. Thấy nó **RED**, chép output.
3. Sửa.
4. Thấy nó **GREEN**.
5. Chạy lại loop Phase 1 trên kịch bản gốc (chưa thu nhỏ).
6. Logic quan trọng (auth, tiền, state machine, security, bug từng tái phát) → thêm mutation proof
   theo `references/test-proof.md` §2: phá đúng hành vi vừa sửa, test phải RED, khôi phục, GREEN.

## Phase 6 — Dọn

Bắt buộc trước khi handoff:

- [ ] Repro gốc không còn tái hiện (chạy lại loop Phase 1).
- [ ] Regression test pass, hoặc việc thiếu seam đã ghi vào `Unknown / risk`.
- [ ] `grep -rn '\[DEBUG-' <owned paths>` rỗng.
- [ ] Rig vứt đi đã xoá hoặc nằm ở `/tmp`; mutation đã khôi phục, `git diff` owned paths chỉ còn
      fix + test.
- [ ] Giả thuyết đúng được ghi trong commit message (qua `smart-commits`) và trong ô
      `Verification` của handoff, để người sau học được.
- [ ] Ô `Verification` ghi proof level (`references/test-proof.md` §3), không chỉ "tests pass".

## Anti-pattern

- Đọc code dựng lý thuyết trước khi có lệnh đỏ được.
- Sửa lần ba vẫn cùng triệu chứng mà chưa quay về Phase 1.
- Regression test chưa từng đỏ trên code lỗi.
- Làm xanh bằng cách nới assertion, sửa expected cho khớp actual, skip/xoá test, update snapshot
  mù, mock mất đúng phần đang cần kiểm (`references/test-proof.md` §4).
- `git bisect` hay `git stash` trên checkout dùng chung.
- Hỏi thẳng người yêu cầu thay vì báo người giao việc.

## Reference

| File | Khi nào đọc |
|---|---|
| `references/test-proof.md` | Phase 5–6; review test của bug fix; khi test mới pass ngay từ đầu |
| `scripts/hitl-loop.template.sh` | loop cần người thật thao tác |

Nguồn: adapt từ `mattpocock/skills@c55ee46` `skills/engineering/diagnosing-bugs` (MIT, xem
`LICENSE-upstream`) và `phucanh08/alp-code@633c287` `skills/test-quality-guard`.
