---
name: prompt-leverage
description: Nâng prompt thô thành prompt hoặc brief sẵn sàng thực thi mà không đổi ý định — bổ sung Objective, Context, Work Style, Tool Rules, Output Contract, Verification, Done. Dùng khi Human viết prompt cho Lead, khi Lead viết brief 13 trường cho Peer, khi cần rút template dùng lại, hoặc khi được gọi /prompt-leverage.
---

# Prompt Leverage — từ prompt thô tới brief thực thi được

Vị trí trong SLP: hai chỗ.

| Chỗ | Ai | Input | Output |
|---|---|---|---|
| Human → Lead | Human (hoặc Lead nhắc lại) | ý định thô | prompt 7 khối, đủ để `goal-griller` không phải hỏi lại điều hiển nhiên |
| Lead → Peer | Lead | Task Contract + (Scout brief) + một work item từ `sequence-execution-plan` | **brief 13 trường** theo `lead.md` |

Skill này **không đổi ý định**. Nó điền cấu trúc thiếu, không viết lại phong cách, không thêm
ceremony cho việc nhỏ.

## Luật SLP đè lên framework

- **Trung lập về cách làm, có ruling về boundary.** Brief không pre-solve (không kể Peer sửa
  file nào theo cách nào), nhưng phải chứa ruling cho boundary `CLAUDE.md` mà owned scope chạm.
  Chưa ruling được → brief bảo Peer `BLOCKED` khi chạm.
- **Không seed verdict.** Brief cho Reviewer hoặc lane mù không chứa kết luận của Lead, không trích
  finding lane kia.
- **Không nới authority.** Nâng prompt không được thêm quyền push/deploy/gọi ngoài mà `CLAUDE.md`
  hay Human chưa cấp. Thiếu authority → ghi vào `Authority: ... không`, không bỏ trống.
- **Verification là lệnh.** "Đảm bảo chất lượng" không phải Verification; `pytest tests/x -q` là.
- **Done = handoff 6 ô**, không phải "báo xong".

## Luồng

1. Đọc prompt thô, gọi tên **việc thật** trong một câu.
2. Suy disposition: Engineer · Architect · Reviewer · Scout (Lead → Peer), hoặc loại việc: coding
   · research · review · planning · writing (Human → Lead).
3. Dựng lại bằng các khối trong `references/framework.md`; ánh xạ sang 13 trường brief khi đích
   là Peer.
4. Giữ tỷ lệ: việc một dòng không thành spec một trang. Depth `Quick` / `Standard` / `Deep`.
5. Trả prompt đã nâng; kèm danh sách *đã thêm gì* khi hữu ích. Prompt đã mạnh → nói vậy, sửa tối
   thiểu.

`scripts/augment_prompt.py` cho bản nháp xác định (deterministic) — điền khung, phát hiện
disposition/depth từ từ khóa; Lead vẫn phải điền `Base`, `Owned scope`, `Boundary`, ruling.

## Chế độ output

- `Inline` — chỉ prompt/brief đã nâng.
- `Upgrade + rationale` — kèm gạch đầu dòng đã thêm gì và vì sao.
- `Template` — biến thành template điền chỗ trống dùng lại (ví dụ brief cho một loại task lặp).
- `Hook spec` — mô tả lớp tiền xử lý: nhận prompt → phân loại + risk → bung khối → trả prompt.
  Trên Claude Code có thể gắn `UserPromptSubmit` hook chạy script và inject gợi ý cấu trúc làm
  context; **chưa lab**, chỉ mô tả khi Human hỏi.

## Quality bar

Trước khi trả:

- [ ] vẫn đúng ý định gốc, giữ ngôn từ của người viết nơi có thể;
- [ ] không thêm ceremony vô ích;
- [ ] verification đúng mức risk, là lệnh chạy được;
- [ ] có định nghĩa xong rõ (handoff 6 ô khi đích là Peer);
- [ ] (Lead → Peer) đủ 13 trường; `Base` là SHA thật; `Owned scope` là path; boundary có ruling
      hoặc lệnh dừng;
- [ ] không seed lời giải, verdict, hay authority.

## Reference

| File | Khi nào đọc |
|---|---|
| `references/framework.md` | định nghĩa 7 khối, ánh xạ sang brief 13 trường, mức depth, điều chỉnh theo disposition |
| `scripts/augment_prompt.py` | nháp khung brief/prompt từ prompt thô |
