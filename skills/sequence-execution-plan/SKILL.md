---
name: sequence-execution-plan
description: Biến Task Contract hoặc backlog nhiều item thành đồ thị phụ thuộc nhỏ rồi thành thứ tự giao việc — Now/Next/Later, ai giữ writer lease trước, cái gì chạy song song read-only. Dùng khi có hơn một work item, khi ưu tiên mâu thuẫn với thứ tự thực thi, hoặc sau REOPEN/DEPENDENCY/BLOCKED/REJECT cần replan. Cần quyền sở hữu topology.
---

# Sequence Execution Plan — từ contract tới thứ tự giao việc

Vị trí trong SLP: sau Task Contract (`goal-griller`) và research brief (`xia`), trước brief cho
writer (`prompt-leverage`). Đây là phần *decomposition → routing → ownership → dependency* của
người giao việc. Output là bản đồ tạm: **mỗi work item = một brief tương lai**, thứ tự = ai cầm
writer lease trước.

Điều kiện dùng: bạn **sở hữu topology** (quyền chẻ việc và cấp writer lease). Nhận việc qua brief
→ không sequence. Người yêu cầu có thể dùng để sắp backlog trước khi giao. Ghế nào ứng với gì:
`/ask-alp`.

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
acceptance evidence. Tách **fact** khỏi **assumption**. Chỉ hỏi người yêu cầu khi câu trả lời đổi
hành động đầu tiên; còn lại ghi assumption và đi tiếp.

### 2. Chẻ thành work item = brief tương lai

Item nhỏ nhất tạo được tiến độ **kiểm chứng độc lập**. Investigation chỉ là item khi nó giải một
unknown có tên (→ Scout `xia`).

**Lát dọc, vừa một context.** Mỗi item cắt trọn một đường từ input tới hành vi quan sát được
(dữ liệu + logic + test), không chẻ theo tầng ("viết ledger", "viết test"). Một Peer mới làm xong
trong một context. Soát bốn dấu hiệu cho từng item:

- **cần ruling chưa chốt** — ruling của người yêu cầu chưa có trong `CLAUDE.md`/brief → **bắt buộc**
  chẻ, hoặc chốt đủ ruling trước khi giao writer;
- **chạm hơn một boundary** trong `CLAUDE.md` → chẻ, *trừ khi* mọi ruling của các boundary đó đã
  chốt (commit/brief). Giữ gộp thì dòng Chẻ ghi lý do: "chạm C1, C3, C5 — không chẻ, ruling ở
  `<sha>`";
- **done evidence gồm nhiều nhóm hành vi độc lập** — mỗi nhóm có thể bị `REJECT` riêng → chẻ, trừ
  khi mọi nhóm đã có expected cụ thể trong brief; giữ gộp thì ghi lý do như trên. **Trần cứng: một
  brief ôm tối đa 2 nhóm**; "đo 200 mẫu + viết hàm/test + hiệu chuẩn" là ba nhóm → chẻ, không có
  lý do giữ gộp;
- **có bước chờ Human hoặc thiết bị** (quẹt mẫu, cắm máy, duyệt, chờ build ngoài) → tách bước chờ
  thành item riêng (thường là Scout/Engineer thu dữ liệu, ghi file), để phần code/test chạy song
  song với phần chờ. Một Peer ôm cả "chờ" lẫn "viết" thì đứng im suốt lúc chờ và không ai biết
  (sự cố facepod, 2026-09-24).

`REJECT` đến từ ruling Lead tự quyết giữa chừng, không từ số boundary. Lab 10: item "hoàn một phần"
gộp bốn nhóm, ruling chưa chốt → 4 `REJECT`. Lab 10b: chẻ rồi nhưng Lead tự ruling giữa chừng → vẫn
4. Lab 10c: không chẻ, ruling chốt trước trong `CLAUDE.md` + brief → 1. Lưới an toàn là trigger
`REJECT` thứ hai ở mục 9.

Mỗi item ghi — đây là các cột của mẫu plan:

- **Result** — trạng thái quan sát được sau khi xong.
- **Disposition** — Engineer · Architect · Reviewer · Scout; **write?** yes/no.
- **Owned scope** — path/glob; hai writer không được giao nhau.
- **Boundary** — chạm boundary `CLAUDE.md` nào; ruling có sẵn chưa.
- **Test seam** — hàm/API cao nhất mà test gọi để kiểm hành vi; dùng seam có sẵn, càng ít seam
  càng tốt. Seam mới → nêu trong plan cho người yêu cầu thấy. Đổ vào `Verification` của brief.
- **Done evidence** — lệnh/artifact; sẽ thành `Verification` của brief.
- **State** — ready · blocked · in progress · candidate · accepted.

Type (mitigation, prerequisite, validation…) và uncertainty ghi ở Result hoặc mục Risk khi đáng nói,
không thành cột riêng.

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

- **Now** — một hoặc hai item *ready*, giao được ngay không cần họp lại.
- **Next** — item mở khóa bởi Now, ghi rõ điều kiện rẽ nhánh.
- **Later** — hợp lệ nhưng sắp lại được; speculative để đây hoặc bỏ.

Ràng buộc runtime của SLP:

- Trong một shared checkout, **Now chứa tối đa một writer**; read-only (Scout/Reviewer/Architect)
  chạy song song thoải mái.
- Muốn hai writer song song → mỗi writer một worktree người giao việc tạo trước, owned scope không
  giao nhau,
  và **contract cho interface dùng chung đã có trong brief**. Không có worktree thì không phải
  song song, là xếp hàng — plan phải nói thẳng.
- Reviewer là item `validates` sau khi có candidate SHA, chỉ khi trúng trigger review (danh sách
  trong `ask-alp/references/workflow.md`, Phase 8).
- **Song song là bắt buộc, không phải tuỳ chọn**, khi người yêu cầu nói **gấp** *và* Now có ≥ 2
  item ready không phụ thuộc nhau: mỗi item một worktree + writer riêng; plan ghi rõ worktree nào,
  contract interface chung ở đâu. Xếp hàng lúc này là drift, plan phải nói lý do nếu vẫn xếp hàng
  (vd. không tách được scope).
- Item tách ra từ dấu hiệu "bước chờ Human/thiết bị" chạy **song song** với item code/test của nó
  (`A enables B`, không `blocks`), trừ khi code cần dữ liệu đo mới bắt đầu được.

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

- người nhận việc trả `REOPEN_REQUEST` / `DEPENDENCY_REQUEST` / `BLOCKED` có evidence;
- người giao việc `REJECT` một candidate và finding đổi hình dạng việc;
- `REJECT` thứ hai của cùng item mà các finding nằm ở nhóm hành vi khác nhau → item quá to,
  chẻ lại thay vì rework tiếp;
- Scout brief đảo một assumption ở bước 1;
- người yêu cầu đổi Task Contract, ràng buộc, hay ưu tiên;
- item bị block hoặc mở nhiều nhánh;
- một horizon hoàn thành.

Khi replan: cập nhật fact + dependency trước, sinh lại đường đi, rồi mới xếp lại. Không xếp lại
chỉ vì người nhận việc thích kiến trúc khác.

## Artifact — file `plan.md`, chép mẫu rồi điền

Artifact **là** file `plans/<YYMMDD-HHmm>-<slug>/plan.md` ở gốc repo (không ghi vào `CLAUDE.md`);
memory checkpoint chỉ trỏ tới đường dẫn này. Mỗi pha một file (thiết kế, code); không nối pha mới
vào đuôi file pha cũ. Mẫu: **`references/plan-template.md`** — `Read` file này ngay trước `Write`
plan, chép nguyên rồi điền; không viết plan từ trí nhớ, không tự dựng bố cục khác, không đổi tên
cột, không bỏ sơ đồ; ô chưa biết ghi `?` chứ không xoá.

Node ghi trạng thái + SHA (`accepted a1b2c3d`); cạnh = `blocks`. Dòng **Chẻ** bắt buộc: soát ba
dấu hiệu ở mục 2 cho từng item và ghi kết quả — item chạm hai boundary mà ghi "không dấu hiệu"
là sai; giữ gộp phải kèm ruling đã chốt ở đâu. Ngày tuyệt đối hoặc sự kiện đo được thay cho "sớm"; ước lượng ghi là ước lượng; không bịa
priority, SLA, dependency, effort.

Cập nhật trạng thái + SHA mỗi lần `ACCEPT`/`REJECT`/replan — sửa dòng, không viết lại cả file.
Plan là bản đồ, không phải candidate: không commit. Lần đầu ghi, tạo `plans/.gitignore` chứa đúng
một dòng `*` (tự bỏ qua cả thư mục lẫn chính nó; không đụng `.gitignore` của repo, không cần chạm
`.git/`) rồi `git status --short` không còn `plans/` — writer không stage nhầm.

### Duyệt plan

Plan có **từ ba item** hoặc có item **chạm boundary** `CLAUDE.md` → gửi người yêu cầu đường dẫn
file và hỏi một lần: độ chẻ (thô quá / vụn quá), cạnh phụ thuộc, test seam. Ngưỡng tính trên
plan của **pha đang vào**: pha thiết kế read-only dưới ngưỡng không miễn duyệt cho pha code. **Chờ duyệt rồi mới
giao writer đầu tiên**; item read-only (Scout/Architect) chạy trước được. Dưới ngưỡng → gửi một
lần, không chờ. Replan đổi item hoặc cạnh → hỏi lại theo cùng ngưỡng; chỉ đổi trạng thái thì không.

Plan là bản đồ tạm — SHA + brief + accept summary mới là checkpoint bền.

## Quality gate

- [ ] Mỗi item có result quan sát được + done evidence.
- [ ] Mỗi dependency có nguyên nhân cụ thể, không phải sở thích kiến trúc.
- [ ] Tác động nặng đang diễn ra có quyết định mitigation rõ.
- [ ] Mọi acceptance criteria được đường đã chọn phủ.
- [ ] Không mitigation/thay thế nào bị ghi là resolved.
- [ ] Now có ≤1 writer mỗi checkout; writer song song có worktree + contract shared interface.
- [ ] Item đầu tiên ready và đủ nhỏ để viết brief ngay.
- [ ] Mỗi item là lát dọc; không còn ruling chưa chốt; item gộp nhiều boundary có lý do ở dòng Chẻ;
  mỗi item có test seam; không item nào ôm > 2 nhóm hành vi hay gộp bước chờ Human/thiết bị với
  bước viết.
- [ ] Người yêu cầu nói gấp và có ≥ 2 item ready độc lập → plan có worktree cho từng writer.
- [ ] Plan nằm ở `plans/…/plan.md` theo đúng mẫu (sơ đồ, cột Test seam, dòng Chẻ); trúng ngưỡng →
  đã được người yêu cầu duyệt.
- [ ] Nền tảng speculative nằm ngoài horizon cam kết.
- [ ] Plan nói evidence nào sẽ đổi thứ tự.

Ví dụ đã làm (incident, nền tảng, gộp item, nhánh Scout): `references/worked-examples.md`.
