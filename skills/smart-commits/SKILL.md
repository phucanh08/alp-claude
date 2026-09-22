---
name: smart-commits
description: Gom working tree hiện tại thành các commit logic theo conventional commits, chỉ trong owned scope, không push nếu Human chưa cấp authority, trả về dải SHA base..head làm Candidate cho handoff. Dùng khi Peer writer tới commit gate, khi Lead tự viết (LEAD-WROTE), hoặc khi Human nhờ "commit hết / gom commit / dọn commit stack".
---

# Smart Commits — gom việc đã làm thành candidate sạch

Vị trí trong SLP: **commit gate** của writer, ngay trước handoff. Skill này chỉ *đóng gói việc đã
làm*; nó không được biến thành phiên sửa feature.

Ai dùng:

- **Peer writer** (Engineer/Architect có write) — commit trong owned scope, trả candidate.
- **Lead** khi tự viết — commit rồi mở summary bằng `LEAD-WROTE: <sha> — cần Human accept`.
- **Human** ở session thường — gom working tree của chính mình.
- Read-only disposition, Supervisor — không.

## Luật cứng

- **Không sửa code hay docs để commit dễ hơn.** Quality gate lộ blocker thật → báo, giữ nguyên
  working tree, không tự fix trừ khi Human/brief yêu cầu.
- **Không** `stash`, `reset`, `checkout --`, `clean`, `revert` thay đổi không thuộc mình. Trong
  repo nhiều agent, mọi thay đổi đang có là việc có chủ đích của ai đó.
- **Không** `git add .` / `-A`. Stage đúng path (hoặc hunk) đã đọc.
- **Chỉ owned scope.** Peer thấy staged path hoặc thay đổi ngoài scope → `BLOCKED` với
  `git status --porcelain` làm evidence, không dọn hộ. Human session → hỏi Human path đó có
  vào commit không.
- **Không push mặc định.** Push chỉ khi brief hoặc `CLAUDE.md` cấp authority rõ ràng, hoặc Human
  nói trong session của chính họ. Không có → commit local và nói rõ *chưa push, cần authority*.
- **Không amend/rebase** SHA đã handoff. Sửa thêm = commit mới.
- Conventional commit: `type(scope): subject` + body nói *vì sao* nhóm này đi cùng nhau.

## Luồng

1. **Kiểm cổng** (giống commit gate trong `peer.md`):

   ```bash
   git ls-files --unmerged | head -1          # có → BLOCKED
   git diff --cached --name-only              # staged ngoài scope → BLOCKED / hỏi
   git status --porcelain=v1
   git branch --show-current
   git rev-parse HEAD                         # phải là Base của brief hoặc descendant
   git diff --stat && git diff --cached --stat
   ```

   Lần đầu commit trong repo lạ: kiểm `git config core.hooksPath` và
   `ls "$(git rev-parse --git-path hooks)"` xem hook có push/webhook không. Không gõ đường dẫn thư
   mục git trực tiếp — plugin hook của Human có thể chặn Bash chạm path đó (Lab 7); bị chặn thì
   ghi vào `Unknown / risk`, không lách.

2. **Đọc diff** đủ để hiểu ý định: staged, unstaged, untracked, deleted, renamed.

3. **Chia nhóm theo ý định sản phẩm**, không theo loại file:
   - nền tảng/config trước feature phụ thuộc;
   - source + test trực tiếp chứng minh cùng một hành vi đi chung;
   - docs tách riêng chỉ khi tự nó có nghĩa;
   - generated artifact chỉ khi là deliverable được yêu cầu;
   - một nhóm không được kéo path ngoài owned scope.

4. **Quality gate một lần** trước commit đầu, dùng lệnh fast/unit trong `CLAUDE.md`. Lệnh
   không có, quá đắt, hoặc đã biết hỏng → ghi vào báo cáo, không giả vờ đã chạy. Không chạy lane
   chiếm tài nguyên độc quyền (port, DB, full suite) nếu brief không cấp.

5. **Commit từng nhóm**, kiểm return code trước khi lấy SHA:

   ```bash
   git add <path-cụ-thể>...
   git commit -m "<type>(<scope>): <subject>" -m "<vì sao nhóm này đi cùng>" || { echo COMMIT_FAILED; exit 1; }
   git show --stat HEAD                       # chỉ path hợp lệ
   git status --porcelain=v1                  # còn gì trong scope → nhóm tiếp
   ```

6. **Chốt candidate**:

   ```bash
   git merge-base --is-ancestor "$base" HEAD && echo base-ok
   git log --oneline "$base"..HEAD
   git diff --stat "$base" HEAD
   ```

7. **Push** — chỉ khi có authority (luật cứng ở trên). Branch chưa có upstream → `git push -u
   origin <branch>` chỉ khi remote và tên nhánh chắc chắn đúng.

## Nhóm tốt / xấu

Tốt:

1. `refactor(auth): extract token validation helper`
2. `feat(users): add email verification endpoint`
3. `test(users): cover email verification flow`

Xấu:

1. `chore: update files`
2. `docs: update docs and app code`
3. `test: update tests` — khi test chứng minh nhiều feature không liên quan

## Output — đổ vào handoff

```text
Candidate      <head sha> (base <base sha>, branch <name>, root <abs path>)
Commits        <sha1> type(scope): subject
               <sha2> type(scope): subject
Scope          <path đã đổi>
Verification   <lệnh quality gate + output thật, hoặc: skipped — <lý do>>
Push           not pushed — no authority | pushed to <remote>/<branch> (authority: <brief/Human>)
Out of scope   <path chưa commit và vì sao>, hoặc: none
```

Peer đưa block này vào handoff 6 ô. Lead chấm bằng `git diff base head`, không bằng danh sách
commit message.

Working tree đã sạch khi được gọi → kiểm commit gần nhất liên quan, nói *không cần commit mới*,
không tạo commit rỗng.

## Anti-pattern

- Gộp cả tree thành một `chore` để xong nhanh.
- Chạy full suite chiếm DB khi brief chỉ cấp unit.
- "Tiện tay" format file ngoài scope rồi stage luôn.
- Push vì có remote — remote không phải authority.
- Amend SHA đã gửi Lead vì "chỉ sửa typo".
