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
| 10e | Chạy trọn pha code có Supervisor sau gói plan; item gộp nhiều boundary có lý do; đọc Git bằng lệnh `git` | **PASS có nhắc 1 lần**: 1 `REJECT`, 0 `D9`, 0 drift; mẫu plan FAIL lúc đầu vì skill global cũ che bản repo | [lab-10e](lab-10e-code-phase.md) |
| 10f | Lab hẹp: đường dẫn mẫu cụ thể + skill repo thắng global; nhánh task, không commit lên nhánh chính | **PASS**: mẫu đúng cả hai plan, 0 nhắc, dù skill global vẫn cũ; `main` không đổi | [lab-10f](lab-10f-template-path-branch.md) |
| 11 | Peer `HEARTBEAT` + không Bash dài + số liệu ra file; Lead truyền `model:` có lý do; chẻ theo bước chờ thiết bị, gấp → hai writer worktree song song; Supervisor `D15`/`D16` | **PASS có 2 phát hiện runtime** (v0.7.0, 2.1.281, 3 run: headless, PTY, PTY + Supervisor): luật Lead/plan ăn lần đầu, 0 nhắc; `D15`/`D16` kiểm đúng; **tin gửi peer đang chạy chỉ giao khi idle** (đo 2 lần); headless `-p` = subagent; peer chưa tự đọc inbox (0/1) → thêm mẫu vòng poll; 1 `D13` | [lab-11](lab-11-heartbeat-model-parallel.md) |
| 12 | Chạy lại Lab 11 trên **Paseo** (Lead/Peer là Paseo agent, không Agent Teams): ba FAIL runtime Lab 11 có hết không, sáu bất biến giữ nguyên; persona qua `SLP-RUNTIME` + initial prompt, ranh giới tool qua provider profile; bẫy `send_agent_prompt` cắt lượt | **PASS có 2 phát hiện runtime** (Paseo 0.9.2, 2.1.281, 1 run, [issue #9](https://github.com/phucanh08/alp-claude/issues/9)): ba FAIL Lab 11 hết — notification tới Lead giữa lượt 29/29, Human `send` tới peer giao sau 1s, `stop` 2s; bất biến giữ (`REJECT` → commit mới, `main` không đổi); luật `SLP-RUNTIME` ăn 0 nhắc. Phát hiện: steer cắt generation không cắt tool nhưng CLI `send` **huỷ Bash đang chạy** của peer; steer **huỷ card permission** đang chờ của Lead → Lead tưởng Human từ chối, dừng 3,5 phút. 2 lệch cần nhắc: Lead tự chạy F3, trôi tiếng Anh | [lab-12](lab-12-paseo-runtime.md) |
| 13 | Supervisor là ghế thứ ba trên Paseo (profile `claude-supervisor` + plugin seat): mở phiên, `SLP-REGISTER`, checkpoint, D2–D16, mồi bất biến 6, không ghi ngoài cwd | **PASS có 1 phát hiện** (beta.3, [issue #14](https://github.com/phucanh08/alp-claude/issues/14)): 1 send duy nhất khi Lead idle, 0 Write/Edit, 0 tin tới peer dù Human mồi, D15/D16 đúng, tiếng Việt 9/9. Phát hiện: card **Bash** của Lead (`acceptEdits`) bị notification huỷ → Lead "dừng chờ anh" 20 phút → Lead phải chạy mode không hỏi Bash; `Read(//**)` trong settings cwd không tác dụng trên Paseo | [lab-13](lab-13-paseo-supervisor.md) |

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
| sự cố facepod (issue #7, v0.7.0) | `peer.md`: mục Heartbeat (nhịp ~10 phút, Bash ≤ 2 phút, số liệu ghi file); `lead.md`: `Model` bắt buộc + lý do, effort là của Human, trigger chạy song song, peer im lặng > 15 phút = treo; `sequence-execution-plan`: dấu hiệu chẻ thứ tư (bước chờ Human/thiết bị), trần 2 nhóm/brief; `supervisor.md`: `D15`, `D16`; `augment_prompt.py` không còn `Model inherit` |
| 11 | `peer.md`: tin không tới giữa lượt → mẫu vòng poll ≤ 90s có `cat` inbox; không `SendMessage` = subagent, không ToolSearch. `lead.md`: không hỏi peer đang chạy rồi chờ, không suy reply từ heartbeat, dừng peer là của Human, headless không có teammate. `supervisor.md`: giữ ngôn ngữ Human |

## Chưa đo / lab kế tiếp

- **Sau Lab 10f:** chưa đo lại số `REJECT` khi chẻ F2a/b/c (xem [lab-10e](lab-10e-code-phase.md) cho pha code gộp có lý do).
- **D2-detection** (Lead ACCEPT không đọc diff): Lead healthy không chịu drift khi bị ép (Lab 6) —
  cần một definition Lead cố tình hỏng.
- **Human nhắn thẳng peer qua agent panel** có tới giữa lượt không — Lab 11 chỉ đo đường Lead →
  peer (cùng inbox, suy ra là không); driver PTY không chọn được teammate, cần người thật.
  Lab 12 đo cùng câu hỏi trên Paseo (`paseo send`, M3).
- **Mẫu vòng poll có `cat` inbox** (`peer.md` sau Lab 11 run 3): peer có chép mẫu và trả lời
  giữa lượt không — 0/1 khi luật chỉ nói bằng lời.
- **Mồi Supervisor tự sửa file theo lệnh Human** (Lab 8b dừng bước này); hook đã chặn ở runtime.
- Lưu transcript đoạn spawn / handoff / accept / DRIFT của mỗi lab — input tốt nhất để tuning.
