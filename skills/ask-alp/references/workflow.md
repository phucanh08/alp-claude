# Quy trình làm việc SLP — phase, role, skill, gate

Tài liệu này là bản dài của router `ask-alp`: nối ba agent definition (`lead.md`, `peer.md`,
`supervisor.md`) với năm skill theo phase (và skill phương pháp theo loại việc, như `bug-loop`) thành một luồng từ *ý định của Human* tới
*`ACCEPT <sha>`*. Agent definition giữ bất biến (ai chấm, ai viết, ai không có authority); skill
giữ **cách làm** của từng phase và nói bằng từ vựng authority (người yêu cầu / người giao việc /
người nhận việc — ánh xạ ghế trong `SKILL.md`). Skill không cấp authority — đó vẫn là luật số một.

Bảng "ghế nào cấm skill nào" nằm trong `SKILL.md` của `ask-alp`, không lặp ở đây.

## Tổng quan

| # | Phase | Role | Skill | Artifact ra | Gate để sang phase sau |
|---|---|---|---|---|---|
| 0 | Ý định | Human | (`prompt-leverage` nếu muốn) | prompt thô hoặc prompt 7 khối | — |
| 1 | Intake | Lead | `goal-griller` | **Task Contract** (6 ô) | đủ 6 ô; boundary có ruling hoặc lệnh dừng; Human xác nhận nếu Lead suy diễn |
| 2 | Recon | Peer **Scout** (Lead spawn) | `xia` | **Research brief** trong handoff 6 ô | brief có nhãn evidence; câu hỏi cho Lead đã được Lead ruling |
| 3 | Sequence | Lead | `sequence-execution-plan` | **Plan** `plans/…/plan.md`: work item lát dọc, test seam, dependency, Now/Next/Later, writer lease | Now ≤1 writer/checkout; item đầu ready; ≥3 item hoặc chạm boundary → Human duyệt |
| 4 | Brief | Lead | `prompt-leverage` | **Brief 13 trường** cho một Peer | `Base` là SHA thật; owned scope là path; boundary có ruling hoặc `BLOCKED`-khi-chạm |
| 5 | Implement | Peer Engineer/Architect | (peer.md); `Required skills` nếu brief khai (bug → `bug-loop`) | thay đổi trong owned scope | verification chạy thật; claim hành vi có proof ≥ L2 |
| 6 | Commit | Peer writer (hoặc Lead nếu `LEAD-WROTE`) | `smart-commits` | **Candidate** `base..head` | commit gate pass; không path ngoài scope |
| 7 | Handoff | Peer | (peer.md) | handoff 6 ô | `Ownership: released` |
| 8 | Review | Peer Reviewer (chỉ khi trúng trigger) | (peer.md) | finding trên đúng SHA | đọc SHA, không working tree |
| 9 | Accept | Lead | (lead.md checklist) | `ACCEPT <sha>` / `REJECT <sha>` | đã đọc `git diff base sha` thật |
| ∥ | Governance | Supervisor | (supervisor.md) | `DRIFT` / `ESCALATE` / `NOTE` | không tham gia gate nào; chỉ hỏi |

Phase 2, 3, 8 là **tuỳ điều kiện** — bỏ qua khi không trúng điều kiện ghi trong bảng "Khi nào
bỏ qua" dưới. Phase 1, 4, 6, 7, 9 luôn có.

```text
Human ──prompt──▶ Lead ─goal-griller─▶ Task Contract
                    │  (thiếu dữ liệu?) ──Agent(peer, Scout)──▶ xia ──brief──▶ Lead
                    ├─sequence-execution-plan─▶ Plan (Now: 1 writer)
                    ├─prompt-leverage─▶ Brief ──Agent(peer, Engineer)──▶ Peer
                    │                                              │ implement
                    │                                              ├─smart-commits─▶ base..head
                    │                                              └─handoff 6 ô──▶ Lead
                    ├─(Reviewer trigger?)──Agent(peer, Reviewer)──▶ finding @ sha
                    └─ACCEPT <sha> | REJECT <sha> ──▶ Human (summary)
Supervisor (session riêng, 1..N Lead) ◀─SLP-REGISTER + checkpoint─ Lead ; ─DRIFT @lead/ESCALATE─▶ Lead / Human
```

## Phase 1 — Intake: `goal-griller`

**Vào:** prompt của Human. **Ra:** Task Contract.

Lead đọc `CLAUDE.md`, nhắc lại ý định một câu, rồi kiểm sáu ô: Outcome, Proof, Scope, Context,
Validation loop, Stop/pause. Ô nào tra được từ repo thì tra; cần đọc rộng thì sang Phase 2; còn
lại hỏi Human **một câu một lần** kèm đáp án đề xuất.

Gate: chưa đủ sáu ô → **không giao writer**. Human ép "cứ làm" → Lead vẫn không giao writer, chỉ
được giao Scout (Lab 2).

Khi nào bỏ qua: Human đã đưa contract đủ sáu ô (ví dụ đã tự chạy `goal-griller` ở session thường).

## Phase 2 — Recon: `xia` (Scout)

**Vào:** câu hỏi cụ thể từ Lead (ô nào của contract đang trống, boundary nào chưa rõ).
**Ra:** research brief gắn nhãn Local / Upstream / Docs / Inference, gói trong handoff 6 ô.

Lead spawn `Agent(subagent_type: peer, name: scout-<topic>)`, brief ghi `Disposition: Scout`,
`Concurrency: read-only`, `Commit lease: n/a`, depth `Quick|Standard|Deep`, và **câu hỏi phải trả
lời**. Scout không sửa file, không ruling. Nhiều Scout read-only chạy song song được (Lab 3).

Lead dùng brief để: điền ô contract còn trống, ruling boundary, chọn đường đi. Lead không
`ACCEPT` brief như code.

Khi nào bỏ qua: Human waive research (Lead ghi `Research: waived by Human` vào brief); sửa nhỏ,
seam rõ; việc lặp lại trên phần repo team đã thuộc.

## Phase 3 — Sequence: `sequence-execution-plan`

**Vào:** Task Contract + brief Scout. **Ra:** plan — bảng work item (mỗi item = một brief tương
lai), câu dependency, Now/Next/Later, item nào giữ writer lease.

Luật SLP đè lên plan:

- Now chứa **tối đa một writer mỗi checkout**; read-only chạy song song.
- Hai writer song song = hai worktree Lead tạo trước + contract cho interface chung trong brief.
  Chưa có worktree → là xếp hàng, plan nói thẳng.
- Song song là **bắt buộc** khi Human nói gấp và có ≥ 2 item ready độc lập; item có bước chờ
  Human/thiết bị tách khỏi item code/test; một brief ôm ≤ 2 nhóm hành vi.
- Mitigation không được gọi là resolution; outcome mở tới khi có `ACCEPT <sha>`.

- Mỗi item là lát dọc vừa một context, có test seam. Ruling chưa chốt → chẻ hoặc chốt trước khi
  giao writer; chạm >1 boundary / nhiều nhóm hành vi mà ruling đã chốt → được gộp, dòng Chẻ ghi lý do.

Plan ghi ra `plans/<YYMMDD-HHmm>-<slug>/plan.md` (sơ đồ Mermaid + bảng + Now/Next), cập nhật mỗi
`ACCEPT`/`REJECT`/replan; không commit (`plans/.gitignore` chứa `*`), không ghi vào `CLAUDE.md`.
Từ ba item hoặc chạm boundary → Human duyệt file này trước writer đầu tiên. Chuyển từ thiết kế
sang code là plan mới, qua lại Phase 3.

Khi nào bỏ qua: đúng một work item, không dependency, không boundary — đi thẳng Phase 4.

## Phase 4 — Brief: `prompt-leverage`

**Vào:** một work item + contract + brief Scout. **Ra:** brief 13 trường theo `lead.md`.

Ánh xạ: Outcome → `Objective`; Proof + Validation → `Verification`; Scope → `Owned` /
`Excluded scope`; Stop/pause → `Authority` + điều kiện `BLOCKED`; Done → `Handoff contract`.
`scripts/augment_prompt.py` nháp khung; Lead điền `Base` (SHA thật), `Owned scope`, ruling, và
`Model` (bắt buộc, kèm lý do; Agent call truyền `model:` cùng giá trị — `lead.md` § Chọn model).
Peer nhận brief sẽ gửi `HEARTBEAT` theo `peer.md`; Lead đếm chéo file evidence mỗi heartbeat.

Ba luật không được vi phạm khi nâng brief: trung lập về cách làm nhưng có ruling boundary;
không seed verdict cho Reviewer / lane mù; không nới authority.

## Phase 5–7 — Implement, Commit, Handoff

Peer làm theo `peer.md`. Tại commit gate, writer dùng `smart-commits`:

- kiểm cổng (unmerged, staged ngoài scope, HEAD là descendant của `Base`);
- gom commit theo ý định sản phẩm, conventional commit, chỉ owned path;
- quality gate một lần bằng lệnh fast trong `CLAUDE.md`;
- **không push** — trừ khi brief/`CLAUDE.md` cấp;
- trả block Candidate `base..head` vào handoff 6 ô, `Ownership: released`.

Lead tự viết → cũng `smart-commits`, nhưng summary mở bằng `LEAD-WROTE: <sha> — cần Human
accept`; Lead không tự `ACCEPT`.

## Phase 8 — Review (có điều kiện)

Chỉ khi trúng một trong năm trigger trong `lead.md` (brief pre-solve, chạm seam `CLAUDE.md`, khó
đảo ngược, proof đáng ngờ, REOPEN rút lại không evidence). Reviewer đọc **đúng SHA** bằng
`git show sha:path` / `git diff base sha`; brief cho Reviewer không chứa verdict của Lead
(`prompt-leverage` luật "không seed").

## Phase 9 — Accept

Checklist trong `lead.md`. Verdict là một dòng `ACCEPT <sha> — <task id>` hoặc
`REJECT <sha> — <task id> — <finding path:line>`. `REJECT` → item về `in progress` trong plan,
Peer commit tiếp trên cùng nhánh; không amend.

## Vòng replan

`sequence-execution-plan` §9 định nghĩa trigger. Trong SLP, các sự kiện sau **luôn** đưa Lead về
Phase 3 (hoặc Phase 1 nếu contract sai):

| Sự kiện | Về phase | Vì sao |
|---|---|---|
| `REOPEN_REQUEST` có evidence, Lead chấp nhận | 1 (tầng `foundation`/`API`/…) hoặc 3 | premise sai → contract hoặc dependency sai |
| `DEPENDENCY_REQUEST` | 3 | cần owner/scope khác → đồ thị đổi |
| `BLOCKED` thiếu authority/giá trị boundary | 1 → Human | chỉ Human cấp được |
| `REJECT` với finding đổi hình dạng việc | 3 | item có thể phải chẻ lại |
| `REJECT` thứ hai cùng item, finding ở nhóm hành vi khác nhau | 3 | item quá to → chẻ lại, không rework tiếp |
| Scout brief đảo assumption | 1 hoặc 3 | fact đổi trước, thứ tự đổi sau |
| Human đổi ưu tiên / ràng buộc | 1 | contract là nguồn |

Không replan chỉ vì Peer thích kiến trúc khác (đó là `REOPEN_REQUEST` không evidence — Lab 2).

## Supervisor xuyên suốt

Supervisor không nằm trong phase nào và không dùng skill nào ở đây (definition không có tool
`Skill`; đúng ý). Nó nhận checkpoint từ Lead ở ba mốc: giao writer (Phase 4), nhận handoff
(Phase 7), verdict (Phase 9). Skill mới không thêm drift mới cho Supervisor; nhưng vài drift cũ
có evidence rõ hơn:

- D4 (verification là lời kể) — handoff giờ có block Candidate của `smart-commits`, thiếu output
  thật là thấy ngay.
- D7 (boundary đổi mà brief không ruling) — Task Contract có ô `Boundary`; trống mà diff chạm
  boundary → drift.
- D6 (hai writer một checkout) — plan của Phase 3 ghi writer lease; Supervisor so với brief.

Workspace nhiều repo: mỗi repo một Lead (`lead-<repo>`), mỗi Lead chạy trọn luồng này trong root
của mình; một Supervisor nghe tất cả, mỗi Lead một làn. Feature chạm nhiều repo → mỗi repo một Task
Contract, owner của cross-repo contract (trong `CLAUDE.md` workspace) đi trước. Commit ra ngoài
root đã `SLP-REGISTER` → `D14`.

## Checklist một lượt task chuẩn

- [ ] Task Contract đủ 6 ô, Human đã thấy (Phase 1).
- [ ] Nếu spawn Scout: brief có nhãn evidence, Lead đã ruling các follow-up (Phase 2).
- [ ] Plan có bảng item + writer lease; Now ≤1 writer/checkout (Phase 3, nếu >1 item).
- [ ] Brief 13 trường; `Base` SHA thật; boundary ruling hoặc `BLOCKED`-khi-chạm (Phase 4).
- [ ] Handoff có block Candidate `base..head`, verification output thật, `Ownership: released` (Phase 6–7).
- [ ] Reviewer (nếu có) đọc đúng SHA (Phase 8).
- [ ] Dòng `ACCEPT`/`REJECT <sha>` sau khi Lead đọc diff thật (Phase 9).
- [ ] Checkpoint gửi Supervisor ở 3 mốc, nếu Supervisor chạy.

## Trạng thái kiểm chứng

Năm skill được viết lại từ `hoangnb24/skills` (plugin `khuym`) cho Claude Code + SLP ở v0.3.0
và đã qua **Lab 7 + 7b** (`docs/labs/lab-07-phase-skills.md`, PASS 2026-09-22): 7a đo `goal-griller`,
`prompt-leverage`, `smart-commits`, accept; 7b đo `xia` (Scout thật, 0 Edit, nhãn evidence),
`sequence-execution-plan` (W1→W2, một writer) và tầng authority khi task đến từ session khác.
Biến thể có Supervisor chưa chạy. Ghi chú chi tiết trong `docs/labs/lab-07-runs.md`.

`bug-loop` (v0.6.0) adapt từ `mattpocock/skills` `diagnosing-bugs` + `phucanh08/alp-code`
`test-quality-guard`; Lab 9 + 9b PASS (2026-09-23) — ghi chú ở `docs/labs/lab-09-bug-loop.md`.
