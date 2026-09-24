# Prompt Leverage — framework

Khung: `Objective → Context → Work Style → Tool Rules → Output Contract → Verification → Done`.

Hai nguồn gốc: *behavior control* (cường độ, tìm rộng, đào sâu, mắt mới, first-principles) và
*execution control* (objective rõ, output contract, tool persistence, kiểm prerequisite, vòng
verification, tiêu chí dừng). SLP thêm lớp thứ ba: *authority control* (ai được làm gì, ai chấm).

## Bảy khối

| Khối | Nội dung | Khi viết prompt cho session khác | Khi viết brief 13 trường |
|---|---|---|---|
| Objective | việc + thành công quan sát được | một câu outcome + proof | `Objective` |
| Context | file, URL, ràng buộc, giả định, ranh giới thông tin; khi nào phải tra thay vì đoán | link Task Contract / issue / log | `Repository root`, `Base`, `Excluded scope`, Scout brief đính kèm |
| Work Style | rộng trước khi cần hiểu hệ; sâu ở chỗ risk; first-principles; mắt mới cho việc không tầm thường | depth mong muốn | `Disposition`, `Model` (bắt buộc, kèm lý do một dòng; `inherit` không phải lựa chọn — effort thuộc Human `/effort`), depth |
| Tool Rules | khi nào bắt buộc đọc file / chạy test / tra docs; không bỏ prerequisite; skill bắt buộc của gate | "đừng đoán, grep" | `Authority`, `Concurrency`, `Commit lease`, skill bắt buộc theo disposition (`xia` cho Scout, `smart-commits` cho writer); `Required skills` khi loại việc cần phương pháp riêng (bug → `bug-loop`) |
| Output Contract | cấu trúc, độ sâu, section bắt buộc | "trả contract rồi dừng" | `Handoff contract` (6 ô) |
| Verification | đúng, có căn cứ, đủ, side effect, phương án tốt hơn | lệnh proof | `Verification` (lệnh + tài nguyên độc quyền) |
| Done | điều phải đúng trước khi dừng | "xong khi …" | `Outcome` trong handoff + `Ownership: released` |

Trường brief không có khối tương ứng — `Project / Task ID`, `Owned scope` — người giao việc điền từ
`sequence-execution-plan`. `Required skills` là trường thứ 14, tuỳ chọn: chỉ định *phương pháp*,
không chỉ định lời giải; bỏ trống khi skill theo disposition là đủ.

## Depth

Dùng mức thấp nhất khớp việc.

- `Quick` — sửa nhỏ, format, rename, câu hỏi có seam rõ.
- `Standard` — coding, research, review thông thường.
- `Deep` — debug khó, kiến trúc, migration/schema/public API, security, output rủi ro cao.

## Điều chỉnh theo disposition

- **Engineer** — repo context, đọc file trước khi sửa, thay đổi nhỏ nhất đúng, verification,
  edge case; `Concurrency: exclusive-writer`, `Commit lease: required`.
- **Architect** — outcome + ràng buộc + trade-off; nêu ownership/lifecycle của mỗi abstraction;
  write chỉ khi brief cấp.
- **Reviewer** — đọc đúng SHA (`git show sha:path`, `git diff base sha`), không working tree;
  finding theo severity kèm `path:line`; **không** được seed verdict của người giao việc. Diff có
  test → Verification của brief đòi trả lời *"phá hành vi này thì test nào đỏ?"*.
- **Scout** — read-only; nhãn evidence Local/Upstream/Docs/Inference; trả brief theo `xia`.

Loại việc khi viết prompt: coding (như Engineer), research (nguồn, evidence, unknown, trích dẫn),
review (mắt mới, failure mode, severity), planning (outcome trước implementation), writing (đối
tượng, giọng, cấu trúc, tiêu chí sửa).

## Heuristic nâng prompt

- Chỉ thêm khối khi nó cải thiện thực thi rõ rệt.
- Không biến yêu cầu một dòng thành spec khổng lồ trừ khi việc thật sự phức tạp.
- Giữ ngôn từ của người viết để prompt vẫn "nghe như của họ".
- Tiêu chí hoàn thành cụ thể thay cho tính từ chất lượng mơ hồ.
- Verification có claim hành vi → đòi proof level (L2 RED → GREEN; L3 thêm mutation cho auth, tiền,
  state machine, security), không chỉ "tests pass".
- Với brief: mọi chỗ người giao việc chưa biết ghi `<TODO: …>` thay vì đoán; `Base` không bao giờ là
  `HEAD` chữ — là SHA.

## Rubric

Prompt/brief đã nâng đạt khi:

1. giữ nguyên ý định gốc;
2. giảm mơ hồ;
3. đặt đúng depth và mức cẩn trọng;
4. định nghĩa output rõ;
5. có bước verification tương xứng;
6. nói khi nào dừng;
7. (SLP) không seed lời giải/verdict, không nới authority, boundary có ruling hoặc lệnh dừng.
