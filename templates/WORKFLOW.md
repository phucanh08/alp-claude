# Quy trình làm việc SLP — ghế, phase, skill, gate

Tài liệu này nối năm agent definition (`lead.md`, `peer.md`, `supervisor.md`, `oracle.md`,
`reviewer.md`) với năm skill theo phase (và skill phương pháp theo loại việc, như `bug-loop`)
thành một luồng từ *ý định của Human* tới *`ACCEPT <sha>`*. Agent definition giữ bất biến (ai
chấm, ai viết, ai không có authority); skill giữ **cách làm** của từng phase và nói bằng từ vựng
authority (người yêu cầu / người giao việc / người nhận việc — ánh xạ ghế ở mục dưới). Luật số
một không đổi: **skill không cấp authority**. Capability runtime thêm vào cũng không.

Đây là **doc thường, không phải skill**: installer cài ra `.alp/WORKFLOW.md` (ngoài
`.claude/skills/`, runtime không nạp). Main/Lead/Peer đọc bằng `Read` khi chưa chắc phase kế
tiếp, skill nào hợp, hay ghế mình bị cấm gì. Từ v0.10.0 thay router `ask-alp` cũ.

Trả lời ba câu trước khi chọn skill:

1. **Mode nào?** — *Smart* (session thường của Human tự cầm vai người giao việc) hay *Supervised*
   (ghế Lead riêng, có thể có Supervisor). Chọn lúc mở phiên, không đổi giữa chừng — § Mode.
2. **Bạn ngồi ghế nào?** — quyết định bạn *được* dùng gì (§ Ghế, § Phân bổ, § Cấm).
3. **Bạn đang ở tình huống nào?** — quyết định bạn *nên* dùng gì kế tiếp (§ Tổng quan, § On-ramp).

## Ghế → từ vựng authority

Các skill không nhắc tên ghế; chúng nói bằng *quyền bạn đang cầm*. Bảng này là ánh xạ duy
nhất.

| Ghế SLP | Từ trong skill | Quyền cầm | Không cầm |
|---|---|---|---|
| Human | **người yêu cầu** | chốt outcome; cấp authority ngoài máy (push, deploy, service ngoài); accept khi người giao việc tự viết | — |
| Lead | **người giao việc** | chẻ việc, sở hữu topology; ruling boundary; viết brief; chấm `ACCEPT`/`REJECT <sha>`; kênh hỏi người yêu cầu | accept việc chính mình viết (`LEAD-WROTE`) |
| Peer | **người nhận việc** | đúng những gì brief ghi: owned scope, write hoặc read-only, commit lease | kênh hỏi người yêu cầu (thiếu → `BLOCKED` về người giao việc); topology; ruling |
| Supervisor | **người quan sát** có quyền được giao | đọc Git object, log hộp thư, transcript; hỏi `DRIFT` / `ESCALATE`; `RULING S#` đúng danh sách `CLAUDE.md` workspace; hỏi Peer một câu qua hộp thư (Lead cc); bàn hướng đi với Human | brief, verdict, task cho Peer; ruling không mã; không dùng skill nào |
| Oracle | **người tư vấn** (ghế độc lập) | đọc repo/Git/docs; trả đúng một lượt cho người gọi | sửa file, spawn agent; authority — ý kiến là evidence, không phải verdict |
| Reviewer | **người soi diff** (ghế độc lập) | đọc một diff bằng SHA; trả finding một lượt, có severity | sửa file; verdict `ACCEPT`/`REJECT` (của Lead); review working tree |

Disposition (Engineer · Architect · Scout) là *chế độ làm việc* ghi trong brief, không phải ghế;
skill được nhắc disposition. Review và cố vấn không phải disposition — đó là ghế riêng
(`reviewer`, `oracle`).

## Phân bổ ghế → skill

Mỗi ghế chỉ dùng đúng bộ skill của mình — bản runtime là **package của ghế**:
`.alp/agents/<ghế>/skills/<skill>/` (cài từ `templates/role-skills.json` + `templates/skills/`,
y như alp-paseo; sửa được). Khóa `main` = ghế `main` — session thường của Human ở mode Smart
(`.claude/settings.json` → `agent: main`). Ghế có thư mục `skills/` rỗng (supervisor, oracle,
reviewer) không dùng skill nào.

Claude Code chỉ discover skill chung ở `.claude/skills/`, nên adapter (`.claude/slp/alp.py`) sinh
`.claude/skills/` = hợp các bộ skill của mọi ghế, rồi **hook `PreToolUse` trên `Skill`** chặn ghế
gọi skill SLP không có trong `.alp/agents/<ghế>/skills/` (đọc `agent_type` runtime đưa vào hook;
session không có agent → `defaultAgent` trong `.alp/settings.json`). Skill ngoài SLP không bị
đụng. Hook là rào chắn, không cấp authority: thêm skill vào package không vượt được bảng cấm dưới.

| Ghế | Skill |
|---|---|
| main (Smart) | `goal-griller`, `xia`, `sequence-execution-plan`, `prompt-leverage`, `smart-commits`, `bug-loop` |
| lead | như main |
| peer | `xia`, `smart-commits`, `bug-loop` (đúng cái brief khai trong `Required skills`, hoặc theo disposition) |
| supervisor, oracle, reviewer | — |

## Tổng quan

| # | Phase | Role | Skill | Artifact ra | Gate để sang phase sau |
|---|---|---|---|---|---|
| 0 | Ý định | Human | (`prompt-leverage` nếu muốn) | prompt thô hoặc prompt 7 khối | — |
| 1 | Intake | Lead | `goal-griller` | **Task Contract** (6 ô) | đủ 6 ô; boundary có ruling hoặc lệnh dừng; Human xác nhận nếu Lead suy diễn |
| 2 | Recon | Peer **Scout** (Lead spawn) | `xia` | **Research brief** trong handoff 6 ô | brief có nhãn evidence; câu hỏi cho Lead đã được Lead ruling |
| 3 | Sequence | Lead | `sequence-execution-plan` | **Plan** `plans/…/plan.md`: work item lát dọc, test seam, dependency, Now/Next/Later, writer lease | Now ≤1 writer/checkout; item đầu ready; ≥3 item hoặc chạm boundary → Human duyệt |
| 4 | Brief | Lead | `prompt-leverage` | **Brief 14 trường** cho một Peer | `Base` là SHA thật; owned scope là path; boundary có ruling hoặc `BLOCKED`-khi-chạm; `Premise: bắt buộc` có nguồn |
| 5 | Implement | Peer Engineer/Architect | (peer.md); `Required skills` nếu brief khai (bug → `bug-loop`) | thay đổi trong owned scope | verification chạy thật; claim hành vi có proof ≥ L2 |
| 6 | Commit | Peer writer (hoặc Lead nếu `LEAD-WROTE`) | `smart-commits` | **Candidate** `base..head` | commit gate pass; không path ngoài scope |
| 7 | Handoff | Peer | (peer.md) | handoff 6 ô | `Ownership: released` |
| 8 | Review | Reviewer — ghế riêng `reviewer.md` (chỉ khi trúng trigger) | (reviewer.md) | finding trên đúng SHA | đọc SHA, không working tree |
| 9 | Accept | Lead | (lead.md checklist) | `ACCEPT <sha>` / `REJECT <sha>` | đã đọc `git diff base sha` thật |
| ∥ | Governance | Supervisor | (supervisor.md) | `DRIFT` / `ESCALATE` / `NOTE` / `RULING S#` | không tham gia gate nào; hỏi, và quyết đúng danh sách `S#` |

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
                    ├─(Reviewer trigger?)──Agent(reviewer)──▶ finding @ sha
                    └─ACCEPT <sha> | REJECT <sha> ──▶ Human (summary)
Supervisor (session riêng, 1..N Lead) ◀─SLP-REGISTER + checkpoint─ Lead ; ─DRIFT @lead/RULING S#/ESCALATE─▶ Lead / Human ; ─câu hỏi─▶ Peer (Lead cc, qua slp-mail)
```

## Mode — Smart và Supervised

Mode chọn **lúc mở phiên**, không đổi giữa chừng — cần mode khác thì mở phiên mới. Hai mode chia
cùng bộ skill, cùng brief 14 trường, cùng luật authority; khác nhau ở **ai cầm ghế người giao
việc**.

| Mode | Người giao việc | Người nhận việc | Ghế độc lập | Khi nào dùng |
|---|---|---|---|---|
| **Smart** (mặc định cho việc mới/nhỏ) | ghế `main` — mở `claude` bình thường (settings `agent: main` nạp `.claude/agents/main.md`), cầm vai này theo tài liệu này | Peer spawn trực tiếp từ session đó (`Agent(subagent_type: peer)`) | `oracle`, `reviewer` gọi được từ session chính | một bounded outcome, một writer, không cần trọng tài riêng |
| **Supervised** (SLP đầy đủ) | Lead — session `claude --agent lead` | Peer do Lead spawn | Lead gọi `oracle`/`reviewer`; Human có thể tự spawn `reviewer` soi candidate của Lead | việc lớn, nhiều Peer, cần tách người quyết khỏi người viết, có Supervisor governance |

- Smart **không mở ghế Lead, không Supervisor**: session chính tự intake (`goal-griller`), tự plan
  (`sequence-execution-plan`), tự brief (`prompt-leverage`) và spawn Peer trực tiếp. Session chính
  tự viết → Human accept (cùng luật `LEAD-WROTE`: mở summary bằng dòng đó, không tự `ACCEPT`).
- Supervised là luồng đầy đủ của tài liệu này; Human không spawn Peer trực tiếp — đổi hướng đi qua
  Lead (§ Hộp thư của `lead.md`), tin gửi thẳng Peer có server tự cc Lead.
- Muốn ghim mode theo workspace: ghi một dòng ở `CLAUDE.md` workspace (`Mode: smart` /
  `Mode: supervised`) — session đọc và theo; đổi mode vẫn cần phiên mới.

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

**Vào:** một work item + contract + brief Scout. **Ra:** brief 14 trường theo `lead.md`.

Ánh xạ: Outcome → `Objective`; Proof + Validation → `Verification`; Scope → `Owned` /
`Excluded scope`; Stop/pause → `Authority` + điều kiện `BLOCKED`; Done → `Handoff contract`;
Constraint (có nguồn) → `Premise: bắt buộc`; cách làm Lead/lát trước chọn → `Premise: đang dùng`.
`scripts/augment_prompt.py` nháp khung; Lead điền `Base` (SHA thật), `Owned scope`, ruling, và
`Model` (bắt buộc, kèm lý do; Agent call truyền `model:` cùng giá trị — `lead.md` § Chọn model).
Peer nhận brief sẽ gửi `HEARTBEAT` theo `peer.md`; Lead đếm chéo file evidence mỗi heartbeat và
arm mốc 10 phút cho mỗi peer — im lặng quá mốc → `PING` xuống (`lead.md` § Monitoring).

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
đảo ngược, proof đáng ngờ, REOPEN rút lại không evidence). Lead spawn ghế riêng
`Agent(subagent_type: reviewer, …)` — read-only cứng, ngoài team, trả finding một lượt. Reviewer
đọc **đúng SHA** bằng `git show sha:path` / `git diff base sha`; brief cho Reviewer không chứa
verdict của Lead (`prompt-leverage` luật "không seed"). Verdict vẫn là của Lead.

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
Mỗi `REOPEN_REQUEST` Lead xếp vào một trong ba ô của `lead.md` (đổi quyết định / phương án khác
cũng đúng / không đáng gián đoạn) và trả lời ô đó; chỉ ô đầu vào bảng trên. Đổi quyết định xong,
vòng chưa hết: `Premise` brief kế tiếp + plan + owner bị ảnh hưởng phải nhận cái mới.

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
- [ ] Brief 14 trường; `Base` SHA thật; boundary ruling hoặc `BLOCKED`-khi-chạm; `Premise: bắt buộc` có nguồn (Phase 4).
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

v0.10.0 thêm hai ghế advisor (`oracle.md`, `reviewer.md`) và hai mode Smart/Supervised — port từ
bài gốc ALP, **chưa đo trong lab**: xem `docs/labs/README.md` § Chưa đo. Trạng thái còn lại của
tài liệu này (phase, gate, replan) đã kiểm chứng như trên.
Router `ask-alp` bị gỡ ở cùng bản: skill đã phân bổ theo ghế nên router thành thừa; nội dung của
nó (ánh xạ ghế, bảng cấm, on-ramp) gộp vào tài liệu này. Installer dời `.claude/skills/ask-alp`
cũ vào `.claude/backups/` (ngoài vùng discovery).
