# Test proof — test có bắt được code sai không

Câu hỏi không phải *"test có pass không?"* mà *"nếu tôi phá hành vi này, test nào đỏ?"*. Không chỉ
ra được test cụ thể → hành vi chưa được test chứng minh.

Rút từ `phucanh08/alp-code` `skills/test-quality-guard`; chỉnh cho SLP: shared checkout, commit
gate, không tự accept.

## 1. Oracle — expected lấy từ đâu

Theo thứ tự ưu tiên:

```text
ruling trong brief → Task Contract / acceptance criteria → contract trong CLAUDE.md → bug report
→ spec / docs → invariant của domain
```

Không bao giờ: *"code đang trả X nên test assert X"*. Không nguồn nào ở trên chốt expected →
`BLOCKED` về người giao việc, không biến implementation hiện tại thành spec (đây là False RED ở
chiều ngược lại).

Expected phải là giá trị độc lập: literal đã biết, ví dụ tính tay, trích spec. Magic number không
nói được nguồn (`assertEquals(34782, r)`) là finding.

## 2. Mutation proof an toàn trên checkout dùng chung

```text
GREEN → MUTATE (phá đúng hành vi) → RED → RESTORE → GREEN
```

Mutation phải chạm **đúng claim**: `>=` → `>`, `ALLOW` → `DENY`, `&&` → `||`, bỏ validation, bỏ
guard auth, bỏ giới hạn retry, `return true`, hoặc revert đúng hunk fix. Đổi tên biến, thêm
whitespace không phải mutation.

Cách làm trong SLP, chọn một:

- **Bản copy ở `/tmp`** (ưu tiên): `git worktree add /tmp/<id> <sha>` hoặc copy owned paths ra
  `/tmp`, mutate và chạy test ở đó, xoá sau. Checkout dùng chung không bị chạm.
- **Tại chỗ, trong owned scope**, khi chưa commit: mutate → chạy → khôi phục bằng tay, rồi
  `git diff -- <owned paths>` phải chỉ còn fix + test. Không `git stash` / `git checkout --` trên
  checkout dùng chung.

Mutation không bao giờ vào commit. Bỏ qua mutation khi: đổi docs, refactor không đổi hành vi,
generated code không sở hữu, mutation có side effect nguy hiểm hoặc không khôi phục an toàn — ghi
proof level thật.

## 3. Proof level — ghi vào ô `Verification`

| Level | Nghĩa | Dùng cho |
|---|---|---|
| 0 | test chưa chạy | không đủ để handoff `complete` |
| 1 | chỉ GREEN | đổi nhỏ, không có claim hành vi mới |
| 2 | RED → GREEN (RED trên code lỗi/chưa làm, output đã chép) | **tối thiểu** cho regression test và feature có contract |
| 3 | + MUTATE → RED → RESTORE → GREEN | auth, tiền, state machine, security, bug từng tái phát |

Mẫu ô `Verification`:

```text
Behavior        <hành vi được bảo vệ, một câu>
Oracle          <ruling / contract / bug report — trích>
Proof           L2: RED <lệnh + dòng fail> → GREEN <lệnh + dòng pass>
                L3: mutate <đổi gì, ở đâu (/tmp/…)> → RED <dòng fail> → restore → GREEN
Tests           <tên test>
Bỏ qua          <mutation / suite nào không chạy, vì sao>
```

## 4. Finding cho test

**BLOCKING** — handoff không được ghi `complete`; người giao việc gặp thì `REJECT`:

| Finding | Dấu hiệu |
|---|---|
| `test-survives-sabotage` | phá hành vi mục tiêu, test vẫn pass |
| `unproven-regression-test` | test cho bug fix chưa từng đỏ trên code lỗi |
| `assertion-weakened-to-green` | assertion bị nới (`assertEquals(X)` → `assertNotNull`) mà requirement không đổi |
| `test-removed-to-green` | test đỏ bị xoá |
| `test-disabled-to-green` | `skip`/`@Disabled`/`xfail`/TODO chỉ để né đỏ |
| `implementation-derived-oracle` | expected tính lại bằng chính code/thuật toán đang test |

**HIGH** — ghi finding, người giao việc quyết:

- `tautological-test`: test chỉ chứng minh setup/mock của chính nó.
- `over-mocking`: mock mất decision logic, validator, mapper, auth. Phép thử: thay implementation
  bằng `return <hằng số>`, test có đỏ không?
- `happy-path-bias`: chỉ test đường thành công trong khi rủi ro nằm ở empty, invalid, expired,
  timeout, retry, duplicate, biên, exception, concurrency, authorization.
- `coverage-gaming`: test chạy code mà không có assertion có nghĩa.
- `snapshot-rubber-stamping`: snapshot đỏ → update → xanh, không đối chiếu requirement.

**MEDIUM**: coupling với implementation (private method, thứ tự gọi, đếm số lần gọi); test trùng
(cùng input, cùng path, cùng assertion); fixture quá lớn so với điều kiện đang kiểm.

Assertion yếu khi đứng một mình: `assertNotNull`, `size > 0`, `status != 500`,
`assertDoesNotThrow`. Mock chỉ ở rìa hệ thống: network, API ngoài, clock, randomness, file system,
hạ tầng đắt — không mock phần mình sở hữu.

## 5. Gợi ý test theo loại logic

| Code có | Xét |
|---|---|
| `<`, `<=`, range, limit, timeout, retry, threshold | biên − 1, biên, biên + 1 |
| `&&`, `\|\|`, `!` | đảo toán tử, bỏ `!` |
| trả boolean / enum / status / result | `SUCCESS` ↔ `ERROR`, `ALLOW` ↔ `DENY`, value → null |
| try/catch, Result, retry, fallback | có test cho đường lỗi |
| async, thread, queue, worker | race, chạy trùng, cancel, timeout, thứ tự, lỗi một phần |
| auth, permission, token, signature | allowed, denied, missing, invalid, expired, tampered — test auth phải chứng minh được đường deny |
