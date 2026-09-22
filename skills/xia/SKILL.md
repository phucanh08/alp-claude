---
name: xia
description: Trinh sát chống phát minh lại trước khi viết code — map repo từ artifact thật, tìm reuse local, kiểm pattern upstream và docs chính thức đúng version, trả research brief gắn nhãn evidence Local/Upstream/Docs/Inference. Dùng cho disposition Scout (read-only), hoặc khi việc lạ, mơ hồ, nhạy version, hay chạm boundary.
---

# Xia — trinh sát trước khi build

Vị trí trong SLP: sau Task Contract (`goal-griller`), trước khi người giao việc sequence hoặc
viết brief cho writer. Câu hỏi của Xia là *cái gì đã có, cái gì dùng lại được, docs nói gì, đường nào nhẹ nhất* —
không phải *code thế nào*.

Điều kiện dùng (ghế nào ứng với gì: `/ask-alp`):

- **Disposition Scout, read-only** — chủ yếu. Brief nêu câu hỏi cần trả lời; Scout trả research
  brief trong handoff.
- **Người giao việc tự chạy** — chỉ depth `Quick` khi câu hỏi nhỏ và seam rõ; rộng hơn thì giao
  Scout để giữ context.
- **Đang giữ write lease** — không; cần research thì xin người giao việc spawn Scout riêng.
- **Ghế chỉ quan sát** — không.

## Hard gate

- Scout **không sửa file**, không commit, không tạo rig ngoài `/tmp`. Đang chạy `xia` mà thấy mình
  `Edit` → dừng, đó là drift disposition.
- Brief **không chứa verdict hay ruling**. Xia đề xuất đường đi và nói vì sao; người giao việc
  ruling.
- Hai đường đi khác nhau đáng kể về hành vi, risk, hay chi phí migration → brief trình cả hai kèm
  câu hỏi cho người giao việc; không tự chọn hộ.
- Người yêu cầu waive research ("đã biết, làm luôn") → người giao việc ghi vào brief
  `Research: waived by <ai>`, không chạy Xia.

## Depth

| Depth | Khi nào | Làm gì |
|---|---|---|
| `Quick` | risk thấp, seam local rõ | map repo + reuse local |
| `Standard` | mặc định | map repo → reuse local → upstream → docs đúng version |
| `Deep` | cross-cutting, nhạy version, chạm kiến trúc hoặc boundary `CLAUDE.md` | như Standard, thêm so sánh ≥2 đường và kiểm version binary thật |

Không chắc → `Standard`.

## Luồng bắt buộc

1. Xác nhận research chưa bị waive (đọc brief).
2. Đọc contract repo: `CLAUDE.md`, README, doc kiến trúc/workflow. Dựng **stack ledger** từ
   artifact thật (manifest, lockfile, config, workflow, script), không từ tên thư mục.
3. Tìm **reuse local**: code kề feature, test, script, docs, config, env validation. Chưa kiểm
   code + config + docs + test thì chưa được nói "không có".
4. Chỉ khi local đã rõ mới xem **upstream**: repo framework/library, starter chính thức, ví dụ
   tích hợp gần nhất.
5. Kiểm **docs chính thức** có ý thức version: framework đã hỗ trợ sẵn chưa, API/workflow khuyến
   nghị hiện tại, caveat/migration cho version repo đang dùng. Local và docs mâu thuẫn → local là
   sự thật hiện hành, ghi rõ mâu thuẫn.
6. Trả brief theo `references/research-brief-template.md`, gói trong handoff 6 ô.

Chi tiết từng bước, vai trò tool, red flag: `references/xia-protocol.md`.

## Nhãn evidence

Mọi claim không tầm thường phải mang đúng một nhãn:

- `Local` — từ repo này (file, test, config, git log).
- `Upstream` — từ repo công khai (framework, library, ví dụ).
- `Docs` — từ docs chính thức, ghi version.
- `Inference` — kết luận rút từ evidence trên.

Không trộn nhãn. "Tìm không thấy" là `Local`, và **không đồng nghĩa "không có"**.

## Quy tắc đề xuất

Chọn đường **nhẹ nhất còn tin được**, theo thứ tự:

1. Dùng lại chức năng local đang có.
2. Dùng capability sẵn của framework/library đúng version repo.
3. Adapt pattern upstream vừa với repo.
4. Build từ đầu — chỉ khi ba đường trên không đủ, nói rõ vì sao.

Nêu vì sao đường chọn thắng đường kế tiếp, và evidence nào sẽ đảo đề xuất.

## Handoff

Scout trả handoff 6 ô chuẩn SLP (bỏ `Candidate`, `Ownership: n/a — read-only`) và **đính brief**
vào thân message. `Scope` = file đã đọc; `Verification` = lệnh thật đã chạy (ví dụ lệnh xem
version, lệnh grep) và output; `Unknown / risk` = evidence gap + câu hỏi cho người giao việc.

Người giao việc không `ACCEPT` brief như code; họ **dùng** brief để ruling và viết brief cho
writer. Brief tốt là brief mà writer sau đó không phải tìm lại thứ Scout đã tìm.

## Reference

| File | Khi nào đọc |
|---|---|
| `references/xia-protocol.md` | luồng chi tiết, vai trò tool trên Claude Code, guardrail |
| `references/research-brief-template.md` | cấu trúc brief bắt buộc |
