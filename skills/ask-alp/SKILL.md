---
name: ask-alp
description: Router của bộ SLP — trả lời "tôi ngồi ghế nào, đang ở phase nào, nên dùng skill nào, bị cấm gì". Dùng khi Human gõ /ask-alp, khi Lead hoặc Peer chưa chắc phase kế tiếp hay skill nào hợp, hoặc khi cần ánh xạ ghế (Human/Lead/Peer/Supervisor) sang từ vựng authority mà các skill dùng. Không chứa quy trình, không cấp authority.
---

# Ask ALP — skill nào, ghế nào, lúc nào

Bạn không cần nhớ hết bảy skill; hỏi router. Luật số một không đổi: **skill không cấp
authority**. Capability runtime thêm vào cũng không.

Trả lời hai câu trước khi chọn skill:

1. **Bạn ngồi ghế nào?** — quyết định bạn *được* dùng gì.
2. **Bạn đang ở tình huống nào?** — quyết định bạn *nên* dùng gì kế tiếp.

## Ghế → từ vựng authority

Sáu skill kia không nhắc tên ghế; chúng nói bằng *quyền bạn đang cầm*. Bảng này là ánh xạ duy
nhất.

| Ghế SLP | Từ trong skill | Quyền cầm | Không cầm |
|---|---|---|---|
| Human | **người yêu cầu** | chốt outcome; cấp authority ngoài máy (push, deploy, service ngoài); accept khi người giao việc tự viết | — |
| Lead | **người giao việc** | chẻ việc, sở hữu topology; ruling boundary; viết brief; chấm `ACCEPT`/`REJECT <sha>`; kênh hỏi người yêu cầu | accept việc chính mình viết (`LEAD-WROTE`) |
| Peer | **người nhận việc** | đúng những gì brief ghi: owned scope, write hoặc read-only, commit lease | kênh hỏi người yêu cầu (thiếu → `BLOCKED` về người giao việc); topology; ruling |
| Supervisor | **người quan sát** | đọc Git object và transcript; hỏi `DRIFT` / `ESCALATE` | mọi thứ khác; không dùng skill nào |

Disposition (Engineer · Architect · Reviewer · Scout) là *chế độ làm việc* ghi trong brief, không
phải ghế; skill được nhắc disposition.

## Luồng chính: ý định → `ACCEPT <sha>`

| Phase | Ghế | Skill | Ra | Bỏ qua khi |
|---|---|---|---|---|
| Intake | người giao việc (người yêu cầu tự chạy được) | `goal-griller` | Task Contract 6 ô | contract đã đủ 6 ô |
| Recon | Scout read-only (người giao việc spawn) | `xia` | research brief nhãn Local/Upstream/Docs/Inference, trong handoff 6 ô | người yêu cầu waive; sửa nhỏ, seam rõ |
| Sequence | người giao việc | `sequence-execution-plan` | work item, dependency, Now/Next/Later, writer lease | đúng một item, không dependency |
| Brief | người giao việc | `prompt-leverage` | brief 13 trường, trung lập cách làm, có ruling boundary | không bao giờ |
| Implement → Commit | writer (người nhận việc có write) | `smart-commits` ở commit gate | Candidate `base..head`, không push | read-only disposition |
| Handoff → Review → Accept | người nhận việc → (Reviewer) → người giao việc | (agent definition) | handoff 6 ô → finding @ sha → `ACCEPT`/`REJECT <sha>` | — |

Gate cứng giữa phase: chưa có Task Contract → không giao writer; owned scope chạm boundary chưa
ruling → brief bắt writer `BLOCKED` khi chạm; Now ≤ 1 writer mỗi checkout.

## Theo loại việc — skill phương pháp

Phase nói *lúc nào*; loại việc nói *làm bằng phương pháp gì*. Skill phương pháp không gắn
disposition: người giao việc khai trong brief (`Required skills`), người nhận việc gọi khi được
khai. Không khai thì không bắt buộc — không có gate toàn cục.

| Loại việc | Skill | Ghế được chạy tới đâu |
|---|---|---|
| chưa rõ, cần tìm hiểu, nhiều đường phải so | `xia` | read-only; writer đang giữ lease thì xin người giao việc spawn Scout |
| bug, test đỏ không rõ lý do, hành vi sai, chậm đi | `bug-loop` | read-only: Phase 1–4 (loop đỏ được → giả thuyết đã xác nhận); writer: đủ tới regression test + dọn |
| feature, test mới | — (luật test trong định nghĩa người nhận việc) | writer; proof L2 tối thiểu |

## On-ramp — vào luồng từ giữa chừng

- **`REOPEN_REQUEST` / `DEPENDENCY_REQUEST` / `BLOCKED` có evidence, hoặc `REJECT` đổi hình dạng
  việc** → về `sequence-execution-plan` (Phase 3); premise sai → về `goal-griller` (Phase 1).
- **Người yêu cầu tự nướng contract ở session thường** → `goal-griller`, rồi đưa contract cho
  người giao việc; người giao việc bỏ qua Intake.
- **Người yêu cầu muốn prompt tốt hơn trước khi giao** → `prompt-leverage` chế độ prompt 7 khối.
- **Người giao việc tự viết code** → vẫn `smart-commits`, summary mở bằng
  `LEAD-WROTE: <sha> — cần Human accept`; không tự `ACCEPT`.
- **Task đến từ session khác** → người giao việc hỏi người yêu cầu authority trước, rồi Intake.
- **Cần research giữa lúc đang giữ write lease** → không tự chạy `xia`; xin người giao việc
  spawn Scout riêng.

## Ghế nào cấm skill nào

| Skill | Cấm cho | Vì |
|---|---|---|
| `goal-griller` | người nhận việc | thiếu ô → `BLOCKED` về người giao việc; không có kênh hỏi người yêu cầu |
| `xia` | writer đang giữ lease | Scout là read-only; cần research → người giao việc spawn Scout riêng |
| `sequence-execution-plan` | người nhận việc, người quan sát | topology là của người giao việc |
| `prompt-leverage` | người nhận việc viết lại brief của mình; người giao việc nâng brief để seed verdict | brief là của người giao việc; trung lập là luật |
| `bug-loop` | người quan sát; read-only vượt Phase 4 | sửa + regression test là của writer giữ lease |
| `smart-commits` | read-only disposition, người quan sát; mọi ai **push** khi chưa cấp | write ownership; external side effect là của người yêu cầu |
| mọi skill | người quan sát | Supervisor không có tool `Skill`; đúng ý |

## Reference

| File | Khi nào đọc |
|---|---|
| `references/workflow.md` | luồng đầy đủ từng phase: vào/ra, gate, khi nào bỏ qua, vòng replan, Supervisor xuyên suốt, checklist một lượt task |
