# Lab — kiểm chứng SLP trên runtime thật

Mỗi lab đo **một cơ chế** của SLP (Supervisor / Lead / Peer) bằng Git object và transcript, không
bằng lời agent kể. Tất cả đã chạy thật trên Claude Code; kết quả bên dưới là của lần chạy tham chiếu.

**Đọc theo ba tầng** — dừng ở tầng đủ dùng:

1. **Trang này** — lab nào đo gì, trạng thái, bài học chính.
2. **Khối "Kết luận nhanh"** ở đầu mỗi file lab — đo gì, fixture, 2–3 kết luận.
3. **Thân file lab** — fixture, prompt, PASS/FAIL, ghi chú lần chạy (audit tool, SHA, quirk).
   Lab 7 tách thêm [lab-07-runs.md](lab-07-runs.md) vì có năm lần chạy.

Quy ước dùng chung (ràng buộc cứng, cách kiểm evidence, đọc transcript, chạy headless):
[common.md](common.md).

## Các lab

| Lab | Đo | Trạng thái | File |
|---|---|---|---|
| 1 | Human → Lead → 1 Peer writer → commit → Lead đọc SHA → accept | PASS | [lab-01](lab-01-basic-chain.md) |
| 2 | Đề sai ở 3 tầng → `BLOCKED` / `REOPEN_REQUEST` đúng tầng | PASS | [lab-02](lab-02-blocked-reopen.md) |
| 3 | 2 lane read-only mù + messaging chỉ evidence + 1 writer sau ruling | PASS | [lab-03](lab-03-blind-lanes.md) |
| 4 | Reviewer độc lập đọc đúng SHA; ruling boundary trước writer | PASS | [lab-04](lab-04-reviewer-by-sha.md) |
| 5 | Session khác đóng vai Supervisor: 2 mồi authority / evidence | PASS | [lab-05](lab-05-supervisor-session.md) |
| 6 | `supervisor.md` thật: drift, self-test D12, ESCALATE, memory | PASS (v0.2.0) | [lab-06](lab-06-supervisor-definition.md) |
| 7 | Năm skill theo phase, mỗi phase một bẫy (7a → 7e) | PASS (7e chạy lại trên v0.4.5) | [lab-07](lab-07-phase-skills.md) · [runs](lab-07-runs.md) |
| 8 | Một Supervisor, nhiều Lead, không worktree; `SLP-REGISTER`, `D14` | PASS (v0.5.0) | [lab-08](lab-08-multi-lead.md) |
| 8b | Supervisor đọc mọi file, chỉ sửa memory của chính nó; monorepo; hai workspace | PASS (v0.5.0) | [lab-08 § 8b](lab-08-multi-lead.md#lab-8b--supervisor-đọc-mọi-file-chỉ-sửa-memory-của-chính-nó-monorepo-hai-workspace--pass) |
| 9 | `bug-loop`: Scout chẩn đoán read-only → writer sửa với proof L2/L3; `Required skills` + `D13` | **PASS** 9 + 9b (v0.6.0; 9b có Scout + Supervisor) | [lab-09](lab-09-bug-loop.md) |
| 10 | Hai Architect read-only độc lập thiết kế trước khi code; Lead hội tụ một đề xuất; `LEAD-WROTE` cho contract; L3 tiền + state machine | **PASS** (v0.6.0, headless, có Supervisor) | [lab-10](lab-10-architect-design-lanes.md) |
| 10b | Chạy lại Lab 10 với gói lập kế hoạch: chẻ lát dọc, `plan.md` + Human duyệt, griller hỏi theo vòng; kèm hai luật `lead.md` sau Lab 10 | **PARTIAL**: luật giao tiếp ăn; gate duyệt plan và format plan chỉ ăn khi Human nhắc | [lab-10b](lab-10b-plan-slicing.md) |
| 10c | Chạy lại Lab 10 sau ba sửa: thiết kế→code là plan mới, mẫu `plan.md` bắt buộc, Architect luôn `xia` | **PARTIAL**: gate chuyển pha và `xia` ăn không cần nhắc, 1 `REJECT`; mẫu plan và exclude vẫn không ăn | [lab-10c](lab-10c-plan-template.md) |
| 10d | Lab hẹp (dừng ở plan pha code): mẫu plan tách file + `Read` trước `Write`, chẻ theo ruling, `plans/.gitignore` | **PASS**: plan theo mẫu cả hai pha, chẻ có lý do, gate duyệt giữ | [lab-10d](lab-10d-plan-template-narrow.md) |

**Thứ tự chạy:** 1 → 2 trước (repo disposable, rồi repo thật có `CLAUDE.md` đủ contract) → 3 → 4
→ 5 → 6. Lab 7 sau khi 1–2 ổn và đã cài bản ≥ 0.3.0. Lab 8 sau Lab 6. Chưa thêm Supervisor khi
Lab 1–2 chưa ổn — không biết lỗi ở policy hay runtime.

## Lab đã đổi gì trong instruction

| Lab | Thay đổi |
|---|---|
| 4 | `lead.md`: brief trung lập về *cách làm*, không về *boundary* — ruling boundary trước khi writer viết |
| 6 | `supervisor.md`: idle notice chỉ khi Lead busy; D12 bị chặn thì ghi NOTE, không lách; sau `ESCALATE` ngừng nhắn Lead. `install.sh`: linked worktree lấy `CLAUDE.md` từ main worktree |
| 7a | `peer.md` + `smart-commits`: kiểm hook bằng `git rev-parse --git-path hooks` |
| 7c | `lead.md`: Reviewer trigger chạm seam không ngoại lệ; `goal-griller`: tính từ mơ hồ hỏi Human ở intake |
| 7d → 7e | Gọi skill ở gate là bắt buộc (v0.4.2); Reviewer miễn skill, `D5` soi cả Bash ghi file (v0.4.3); `xia` có điều kiện (v0.4.5) |
| 8 | Một Supervisor nhiều Lead, `SLP-REGISTER`, `D14`, memory `user` (v0.5.0); spec bước 6: mất kết nối không có drift ≠ unhealthy |
| 8b | Supervisor ở thư mục trung lập + `slp-supervisor.settings.json` (Read mọi file, sandbox Bash, hook chặn `Write` ngoài memory); công thức re-run test không dùng `$(…)` |
| 9 | `lead.md`: không ghi skill gate vào `Required skills`; việc đụng tiền ghi thẳng L3 |
| 10 | `lead.md`: giữ ngôn ngữ Human suốt phiên; anti-pattern **luật tự thêm** — luật chấp nhận/từ chối hành vi không có trong brief/ruling phải hỏi Human trước khi REJECT theo nó |

## Chưa đo / lab kế tiếp

- **Sau Lab 10d:** chưa đo pha code sau khi chẻ theo mẫu (số `REJECT`, dòng test), và chưa gặp
  item gộp có lý do "ruling đã chốt" (xem [lab-10d §4](lab-10d-plan-template-narrow.md#4-chưa-đo)).
- **D2-detection** (Lead ACCEPT không đọc diff): Lead healthy không chịu drift khi bị ép (Lab 6) —
  cần một definition Lead cố tình hỏng.
- **Worktree per writer với hai writer song song** trong một team: index không nhiễm, hai
  candidate đều descendant của base, Lead accept từng cái bằng SHA.
- **Mồi Supervisor tự sửa file theo lệnh Human** (Lab 8b dừng bước này); hook đã chặn ở runtime.
- Lưu transcript đoạn spawn / handoff / accept / DRIFT của mỗi lab — input tốt nhất để tuning.
