---
name: sequence-execution-plan
description: Biến Task Contract hoặc backlog nhiều item thành đồ thị phụ thuộc nhỏ rồi thành thứ tự giao việc cho Peer — Now/Next/Later, ai giữ writer lease trước, cái gì chạy song song read-only. Dùng khi Lead có hơn một work item, khi ưu tiên mâu thuẫn với thứ tự thực thi, hoặc sau REOPEN/DEPENDENCY/BLOCKED/REJECT cần replan.
---

# Sequence Execution Plan — từ contract tới thứ tự giao việc

Vị trí trong SLP: sau Task Contract (`goal-griller`) và research brief (`xia`), trước brief cho
writer (`prompt-leverage`). Đây là phần *decomposition → routing → ownership → dependency* của
Lead. Output là bản đồ tạm: **mỗi work item = một brief tương lai**, thứ tự = ai cầm writer lease
trước.

Ai dùng: **Lead**. Peer không sequence (topology là của Lead). Human có thể dùng để sắp backlog
trước khi giao Lead.

## Giữ năm trường tách biệt

| Trường | Trả lời câu | Không được thay bằng |
|---|---|---|
| Outcome priority | outcome chưa đạt thì thiệt hại cỡ nào? | thứ tự làm |
| Current impact | trong lúc chưa đạt, chuyện gì đang xảy ra? | mitigation status |
| Mitigation status | tác động tức thời đã giảm chưa? | durable resolution |
| Durable resolution | outcome thật sự đạt chưa (có `ACCEPT` SHA)? | "đã có commit" |
| Execution order | làm gì kế tiếp, theo dependency và risk? | priority |

Một prerequisite P2 có thể chạy trước fix P0 khi nó **thật sự cần**. Outcome P0 vẫn mở tới khi
acceptance của nó pass. Thiệt hại đang tiếp diễn → mitigation nhỏ nhất an toàn đi trước
prerequisite.

## Dựng plan

### 1. Frame outcome

Lấy từ Task Contract: outcome quan sát được, ai hưởng, tác động hiện tại, ràng buộc, non-goal,
acceptance evidence. Tách **fact** khỏi **assumption**. Chỉ hỏi Human khi câu trả lời đổi
hành động đầu tiên; còn lại ghi assumption và đi tiếp.

### 2. Chẻ thành work item = brief tương lai

Item nhỏ nhất tạo được tiến độ **kiểm chứng độc lập**. Investigation chỉ là item khi nó giải một
unknown có tên (→ Scout `xia`).

Mỗi item ghi:

- **Result** — trạng thái quan sát được sau khi xong.
- **Type** — outcome · mitigation · prerequisite · implementation · validation · rollout · cleanup.
- **Disposition** — Engineer · Architect · Reviewer · Scout; **write?** yes/no.
- **Owned scope** — path/glob; hai writer không được giao nhau.
- **Boundary** — chạm boundary `CLAUDE.md` nào; ruling có sẵn chưa.
- **Done evidence** — lệnh/artifact; sẽ thành `Verification` của brief.
- **Uncertainty** — low/medium/high + unknown là gì.
- **State** — ready · blocked · in progress · candidate · accepted.

Cấm item kiểu "cải thiện kiến trúc", "xử lý edge case", "test hết".

### 3. Viết quan hệ thành câu

- `A blocks B` — B không bắt đầu/xong được tới khi A xong.
- `A enables B` — A làm B rẻ/an toàn hơn nhưng không bắt buộc.
- `A mitigates B` — A giảm tác động của B, không giải quyết bền.
- `A overlaps B` — chung một phần acceptance.
- `A replaces B` — A xong thì mọi criteria của B thỏa.
- `A validates B` — A cung cấp evidence B đúng.

Không suy dependency từ sở thích: "code sạch hơn nếu làm A trước" không chứng minh B bị A chặn.

### 4. Kiểm mọi "nền tảng" được đề xuất

Phân đúng một loại: **necessary** (không có nó thì target sai/không an toàn/vi phạm ràng buộc),
**useful** (giảm effort, nhưng đường thẳng vẫn đạt criteria), **speculative** (giá trị phụ thuộc
việc tương lai chưa chắc).

Trước khi xếp nền tảng đi trước, trả lời: criteria nào bất khả nếu thiếu nó? evidence nào cho
thấy đường thẳng không đủ? tốn bao lâu kể cả unknown? thiệt hại gì tiếp diễn trong lúc chờ? thu
hẹp được về đúng capability target cần không? mở khóa outcome nào khác đã cam kết?

Necessary → trước fix bền. Useful → đường thẳng trước trừ khi enablement đo được đáng giá.
Speculative → ngoài horizon cam kết.

### 5. Tác động nặng đang diễn ra

Tách *response* khỏi *resolution*: (1) chặn thiệt hại bằng hành động nhỏ nhất, đảo ngược được;
(2) thêm observability kiểm containment; (3) prerequisite đã chứng minh cần; (4) fix bền + validate;
(5) gỡ biện pháp tạm sau khi fix bền pass. Không để dự án nền tảng lớn hoãn containment. Không
gọi mitigation là resolution.

### 6. So sánh đường đi

Ít nhất các đường: thẳng · prerequisite→target · mitigation→prerequisite→target→cleanup ·
mitigation ∥ prerequisite→target · chỉ item thay thế (chuyển criteria) · Scout→chọn.

Mỗi đường ước: thời gian tới giảm risk đầu tiên, tới hoàn thành bền, thiệt hại tiếp diễn, effort
và khả năng đảo ngược, unknown chính, giá trị mở khóa. Loại đường vi phạm ràng buộc hoặc bỏ sót
criteria. Chọn đường giảm risk sớm nhất và về đích bền với effort/unknown kiểm soát được.

### 7. Xếp horizon — theo luật writer của SLP

- **Now** — một hoặc hai item *ready*, Lead giao được ngay không cần họp lại.
- **Next** — item mở khóa bởi Now, ghi rõ điều kiện rẽ nhánh.
- **Later** — hợp lệ nhưng sắp lại được; speculative để đây hoặc bỏ.

Ràng buộc runtime (từ `lead.md`):

- Trong một shared checkout, **Now chứa tối đa một writer**; read-only (Scout/Reviewer/Architect)
  chạy song song thoải mái.
- Muốn hai writer song song → mỗi writer một worktree Lead tạo trước, owned scope không giao nhau,
  và **contract cho interface dùng chung đã có trong brief**. Không có worktree thì không phải
  song song, là xếp hàng — plan phải nói thẳng.
- Reviewer là item `validates` sau khi có candidate SHA, chỉ khi trúng trigger trong `lead.md`.

Mọi thứ tự không hiển nhiên phải có câu nhân–quả:

> Làm M trước F vì thiệt hại đang tiếp diễn và M chặn được hôm nay. Làm Y trước F vì criteria C
> không đạt an toàn nếu thiếu capability Y. Giữ outcome X ở P0 tới khi F qua validation V.

### 8. Không mất dấu khi gộp việc

Gộp item chỉ sau khi chuyển: toàn bộ acceptance criteria; urgency và record tác động; owner;
evidence cần để đóng; ghi chú quan hệ. Item cũ ghi *merged / superseded / duplicate / tracked by*;
chỉ *resolved* khi outcome thật đạt. Item P2 nuốt P0 → nâng priority hoặc giữ P0 parent.

Trong SLP: `REJECT <sha>` không đóng item — item về `in progress` với finding; `REOPEN_REQUEST`
được chấp nhận → item về bước 1 với tầng bị mở lại ghi rõ.

### 9. Trigger replan

Now ổn định trừ khi evidence đảo nó. Replan khi:

- Peer trả `REOPEN_REQUEST` / `DEPENDENCY_REQUEST` / `BLOCKED` có evidence;
- Lead `REJECT` một candidate và finding đổi hình dạng việc;
- Scout brief đảo một assumption ở bước 1;
- Human đổi Task Contract, ràng buộc, hay ưu tiên;
- item bị block hoặc mở nhiều nhánh;
- một horizon hoàn thành.

Khi replan: cập nhật fact + dependency trước, sinh lại đường đi, rồi mới xếp lại. Không xếp lại
chỉ vì Peer thích kiến trúc khác.

## Artifact

Trừ khi Human yêu cầu format khác:

1. **Outcome & evidence** — từ Task Contract.
2. **Bảng work item** — ID · Result · Type · Disposition/write · Owned scope · Boundary · Done
   evidence · Uncertainty · State.
3. **Dependency** — câu quan hệ, hoặc graph gọn.
4. **Đường đi** — các phương án với thời gian tới mitigation / resolution và trade-off chính.
5. **Sequence** — Now / Next / Later; nhánh song song + join point; **writer lease** thuộc item nào.
6. **Lý do** — nhân–quả cho thứ tự gây ngạc nhiên.
7. **Risk & traceability** — risk mở, item gộp, biện pháp tạm, cleanup.
8. **Trigger replan.**

Ngày tuyệt đối hoặc sự kiện đo được thay cho "sớm". Ước lượng ghi là ước lượng. Không bịa priority,
SLA, dependency, effort.

Plan ghi vào memory checkpoint của Lead và gửi Human một lần; **không** ghi vào `CLAUDE.md`. Plan
là bản đồ tạm — SHA + brief + accept summary mới là checkpoint bền.

## Quality gate

- [ ] Mỗi item có result quan sát được + done evidence.
- [ ] Mỗi dependency có nguyên nhân cụ thể, không phải sở thích kiến trúc.
- [ ] Tác động nặng đang diễn ra có quyết định mitigation rõ.
- [ ] Mọi acceptance criteria được đường đã chọn phủ.
- [ ] Không mitigation/thay thế nào bị ghi là resolved.
- [ ] Now có ≤1 writer mỗi checkout; writer song song có worktree + contract shared interface.
- [ ] Item đầu tiên ready và đủ nhỏ để viết brief ngay.
- [ ] Nền tảng speculative nằm ngoài horizon cam kết.
- [ ] Plan nói evidence nào sẽ đổi thứ tự.

Ví dụ đã làm (incident, nền tảng, gộp item, nhánh Scout): `references/worked-examples.md`.
