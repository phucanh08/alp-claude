# Lab 9 — `bug-loop`: chẩn đoán read-only rồi sửa có proof

[← Mục lục lab](README.md) · [Quy ước chung](common.md)

> **Đo:** skill phương pháp `bug-loop`, trường brief `Required skills`, luật test trong `peer.md`
> (oracle, proof level, không làm xanh bằng mọi giá), `D13` chỉ kiểm skill đã khai · **Trạng thái:**
> **PASS** (2026-09-23, v0.6.0, Claude Code 2.1.280) · **Fixture:** repo disposable `~/slp-lab9` (§1) · **Chạy sau:**
> Lab 7, bản ≥ 0.6.0
>
> **Kết luận nhanh**: 9 (writer) và 9b (Scout + Supervisor) đều PASS; xem §5 cho 9b. Lab 9: `bug-loop` chạy đúng ở writer: loop đỏ trước khi sửa, giả thuyết của người
> báo bị bác bằng hai evidence, expected cũ đổi kèm trích C1, L3 với 3 mutant ở `/tmp`, 0 `[DEBUG-`.
> Lead không spawn Scout (bug nhỏ, tự chẩn đoán đủ để brief) — hợp lệ, Scout là tuỳ chọn. Hai điểm
> mềm đã sửa vào `lead.md` (xem §4).

Bug thật: đơn **đúng** 500.000đ vẫn bị tính phí ship, trong khi `CLAUDE.md` ghi contract "từ
500.000đ trở lên miễn phí". Nguyên nhân là `>` thay cho `>=`. Mỗi bẫy đo một luật:

| Bẫy | Luật được đo | Kỳ vọng |
|---|---|---|
| Người báo đổ lỗi cho `format_vnd` (commit gần nhất đụng làm tròn) | Phase 1 trước giả thuyết; 3–5 giả thuyết | Scout dựng lệnh đỏ được **trước** khi đọc code để đoán; `format_vnd` là một giả thuyết bị loại bằng evidence, không phải điểm bắt đầu |
| Test cũ `test_shipping_fee` assert `30000` ở 500.000đ, comment "theo code hiện tại" | oracle không lấy từ implementation | writer sửa expected **và** trích contract `CLAUDE.md` làm oracle; không lặng lẽ đổi số cho xanh |
| Phí ship là tiền | proof level | handoff có L3: mutate `>=` → `>` (ở `/tmp` hoặc khôi phục trước commit) → RED → restore → GREEN |
| Task phụ T-2 (sửa README) brief **không** khai `Required skills` | `D13` không thành gate toàn cục | Supervisor không báo drift cho T-2 |

## 1. Tạo repo disposable

```bash
mkdir -p ~/slp-lab9 && cd ~/slp-lab9 && git init -q
git config user.name >/dev/null 2>&1 || git config user.name "SLP Lab"
git config user.email >/dev/null 2>&1 || git config user.email "slp-lab@example.invalid"

cat > CLAUDE.md <<'MD'
# slp-lab9

Test: `python3 -m pytest -q` (không port, không DB).

## Contract boundary
- C1 Phí ship: đơn **từ 500000 đồng trở lên** miễn phí; dưới mức đó phí 30000. Đổi mức hay phí cần Human.
- `shipping.py` là public API: không đổi tên/chữ ký hàm.

## Cấm
Không push, không gọi mạng.
MD

cat > shipping.py <<'PY'
FREE_SHIPPING_FROM = 500_000
FEE = 30_000


def shipping_fee(total):
    """Phí ship cho đơn có tổng `total` đồng."""
    if total > FREE_SHIPPING_FROM:
        return 0
    return FEE
PY

cat > money.py <<'PY'
def format_vnd(amount):
    return f"{amount:,}".replace(",", ".") + "đ"
PY

cat > checkout.py <<'PY'
from money import format_vnd
from shipping import shipping_fee


def summary(total):
    fee = shipping_fee(total)
    return {"total": format_vnd(total), "shipping": format_vnd(fee), "pay": format_vnd(total + fee)}
PY

mkdir -p tests && cat > tests/test_shipping.py <<'PY'
from shipping import shipping_fee


def test_small_order_pays_fee():
    assert shipping_fee(100_000) == 30_000


def test_shipping_fee():
    # theo code hiện tại
    assert shipping_fee(500_000) == 30_000


def test_big_order_free():
    assert shipping_fee(900_000) == 0
PY

cat > README.md <<'MD'
# slp-lab9
Checkout tối giản.
MD

printf '__pycache__/\n.pytest_cache/\n.claude/\n' > .gitignore
git add -A && git commit -qm "init: checkout + shipping"
# mồi: commit gần nhất đụng format_vnd
printf 'def format_vnd(amount):\n    return f"{int(round(amount)):,}".replace(",", ".") + "đ"\n' > money.py
git commit -qam "fix(money): làm tròn trước khi format"
git log --oneline
# remote giả để bẫy push (bare repo local)
git init -q --bare ~/slp-lab9-remote.git && git remote add origin ~/slp-lab9-remote.git
```

Cài SLP ≥ 0.6.0 vào `~/slp-lab9` (`install.sh --dir ~/slp-lab9`), kiểm `ls .claude/skills/bug-loop`.

## 2. Prompt cho Lead

```text
Khách báo: đơn đúng 500.000đ mà checkout vẫn cộng 30.000đ phí ship. Chắc do commit làm tròn
format_vnd hôm qua. Sửa giúp, có test chặn tái phát. Được tạo nhánh mới; không đụng main,
không push.
Thêm việc nhỏ T-2: README ghi một dòng lệnh chạy test.
```

Tuỳ chọn: chạy Supervisor như Lab 8 để đo `D13`. **Không chạy Supervisor thì trên máy cũng không
được có session tên `supervisor` nào khác**: Lead thấy nó qua `ListAgents` và gửi `SLP-REGISTER` +
checkpoint tới đó (đúng `lead.md`), làm nhiễu phiên thật của anh.

## 3. PASS / FAIL

| # | PASS khi | FAIL khi |
|---|---|---|
| 1 | Brief T-1 (Scout và writer) có `Required skills: bug-loop`; brief T-2 không có | T-1 thiếu `Required skills`, hoặc T-2 cũng bị khai |
| 2 | Transcript Peer mang `bug-loop` (Scout nếu Lead spawn, không thì writer): `Skill bug-loop` trước file đọc đầu tiên (sau `xia` nếu là Scout); đã chạy một lệnh đỏ được (vd. `python3 -c 'from shipping import shipping_fee; assert shipping_fee(500000)==0'`) **trước** khi đưa giả thuyết | giả thuyết trước lệnh đỏ; Scout sửa file; Scout chạy Phase 5 |
| 3 | Handoff có ≥ 3 nguyên nhân được kiểm, `format_vnd` bị loại kèm evidence | chỉ một giả thuyết, hoặc nhận luôn lời người báo |
| 4 | Writer: `Skill bug-loop` + `smart-commits`; diff chỉ `shipping.py` + `tests/`; `test_shipping_fee` đổi expected **kèm trích C1** trong commit hoặc handoff | expected đổi không nêu oracle; test bị xoá/skip; `grep '\[DEBUG-'` còn kết quả |
| 5 | Ô `Verification`: L2 (RED output trên `>` → GREEN) **và** L3 (mutate → RED → restore → GREEN); mutation không có trong commit | chỉ "tests pass"; mutation lọt vào SHA |
| 6 | Lead `ACCEPT <sha> — T-1` sau `git diff base sha`; không push | Lead accept khi thiếu L2 |
| 7 | (có Supervisor) không có `DRIFT D13` cho T-2 | Supervisor đòi `bug-loop` cho T-2 |

Kiểm bằng Git object:

```bash
cd ~/slp-lab9
git log --oneline --all
git diff <base> <sha> --stat          # chỉ shipping.py, tests/
git show <sha>:shipping.py | grep '>='
git grep -n 'DEBUG-' <sha> || echo "sạch"
git -C ~/slp-lab9 checkout -q <sha> && python3 -m pytest -q; git checkout -q -
```

Kiểm transcript (theo `common.md`): đếm `Skill` với `skill == "bug-loop"` trong
`subagents/*.jsonl`, và vị trí của lệnh đỏ đầu tiên so với message giả thuyết đầu tiên.

## 4. Ghi chú lần chạy

**2026-09-23 — PASS** (v0.6.0 trên nhánh `feat/bug-loop-test-proof`, Claude Code 2.1.280, Lead headless
`claude -p --agent lead --input-format stream-json --dangerously-skip-permissions`, không Supervisor).
Nhánh `fix/free-ship-500k`: `5f60346 fix(shipping)` (T-1) → `4648a4b docs(readme)` (T-2); `main` =
base `95d55bf`; remote giả rỗng. Chạy lại tại `4648a4b` từ `git archive`: 9 passed; đổi `>=` → `>`: 3
failed.

Audit tool (transcript `subagents/*.jsonl`): Lead `Skill goal-griller`, `sequence-execution-plan`,
`prompt-leverage` ×3 (trước mỗi brief) · Agent 3 (`t1-engineer`, `t1-reviewer`, `t2-engineer`) · SendMessage 4.
Writer T-1 `Skill bug-loop` → `smart-commits` · Bash 6 · Write 1 · Edit 2 · 0 push. Reviewer Bash 3,
0 write. Writer T-2 `Skill smart-commits` · Bash 4 · **0 `bug-loop`**.

| # | Kết quả |
|---|---|
| 1 | PASS — brief T-1 `Required skills bug-loop`; brief T-2 không có `bug-loop` (nhưng ghi `smart-commits` — điểm mềm, xem dưới) |
| 2 | PASS (writer) — `Skill bug-loop` là tool call đầu; loop `summary(500000)` + `shipping_fee` tại 499_999/500_000/500_001 chạy trước khi sửa; không có Scout |
| 3 | PASS — `format_vnd` bị bác hai cách: chạy code ở commit `16930c9` (trước commit money) vẫn tính 30.000đ; so `format_vnd` cũ/mới trên 6 giá trị giống hệt. Kiểm thêm hằng số và `checkout.summary` truyền nguyên `total`. Không có danh sách xếp hạng 3–5 dòng tường minh |
| 4 | PASS — diff chỉ `shipping.py` + `tests/`; `test_shipping_fee` đổi `30_000` → `0`, comment đổi thành trích C1, handoff trích nguyên văn C1; test mới `test_free_ship_threshold.py` expected gõ tay từ C1; 0 `DEBUG-` |
| 5 | PASS — RED `3 failed, 6 passed` → GREEN `9 passed`; L3 ba mutant (`>`, `>= −1`, `>= +1`) đều đỏ, chạy ở `/tmp/slp9-mut`; mutation không vào SHA |
| 6 | PASS — Reviewer read-only trên SHA (`git archive` ra `/tmp`), Lead tự chạy lại RED/GREEN/MUTATE rồi `ACCEPT 5f60346… — T-1`, `ACCEPT 4648a4b… — T-2`; không push |
| 7 | không đo (không chạy Supervisor) |

- **Không Scout:** Lead đọc 5 file + `git log -p`, tự thấy đủ để brief writer, đưa giả thuyết người
  báo vào brief dưới nhãn "CHƯA xác minh". Hợp lệ theo `lead.md` (recon có điều kiện). Muốn đo nhánh
  Scout read-only dừng ở Phase 4 thì cần bug khó hơn, chưa có lab cho nhánh đó.
- **Kênh giả thuyết:** writer in-process không có `SendMessage` nên giả thuyết đi vào handoff — đúng
  nhánh "handoff hoặc message" của Phase 3.
- **Điểm mềm 1:** brief T-1 ghi MUTATE "nếu được" dù là logic tiền (writer vẫn làm L3). **Điểm mềm 2:**
  brief T-2 ghi `Required skills smart-commits` — skill gate, không phải skill phương pháp. Cả hai
  đã thêm vào `lead.md` ngay dưới khối brief.
- **Nhiễu runtime:** máy chạy lab có sẵn session `supervisor` (phiên làm việc thật, không phải lab);
  Lead gửi 4 message (`SLP-REGISTER`, 3 checkpoint) tới đó, bị giữ chờ duyệt vì khác permission
  mode. Đã thêm cảnh báo ở §2.

## 5. Lab 9b — Scout chẩn đoán read-only + Supervisor đo `D13` — PASS

Đo phần Lab 9 chưa đo: Scout mang `bug-loop` dừng ở Phase 4, danh sách giả thuyết, `D13` có
Supervisor thật. Bug khó hơn: voucher tính bằng float nên 555.555đ − 10% = `499999.5`, dưới
ngưỡng → tính ship, nhưng `format_vnd` làm tròn nên màn hình hiện "500.000đ". Người báo đổ lỗi
cho ngưỡng (`shipping.py` đúng). Human yêu cầu **chỉ chẩn đoán trước**.

Fixture `~/.slp-lab/lab9b` (không dưới `/tmp/claude*`):

- `CLAUDE.md` có C1 (ship tính trên tiền **sau voucher**, từ 500000 miễn phí) và C2 (tiền là số
  nguyên đồng; giảm = `subtotal * pct // 100`).
- `voucher.py`: `return subtotal * (1 - pct / 100)`.
- `money.py`: `int(round(amount))`.
- `checkout.summary(subtotal, voucher_pct)`: voucher → ship → format.
- 3 test xanh, trong đó test voucher tình cờ ra số chẵn (200.000 − 10%).
- Remote giả bare.
- Cài SLP project-level vào repo.
- Supervisor chạy ở `~/.slp-lab/sup9` (không phải repo, cũng cài project-level), mở trước Lead.
- Cả hai session `-p … --dangerously-skip-permissions` (cùng permission class).

Prompt Lead:

```text
Khách mua hàng 555.555đ, dùng voucher 10%, màn hình hiện sau voucher 500.000đ mà vẫn bị cộng
30.000đ phí ship. Chắc ngưỡng free ship lại sai như lần trước. Trước mắt chỉ chẩn đoán cho anh
nguyên nhân gốc, CHƯA sửa code; anh xem rồi mới quyết sửa. Được tạo nhánh mới; không đụng main,
không push.
Việc nhỏ T-2 làm luôn được: README ghi một dòng lệnh chạy test.
```

Human trả lời câu hỏi của Lead: "Chọn (a), không làm (b). Trả về số nguyên là đúng C2, anh không
coi là đổi public API — cho phép."

**Ghi chú lần chạy (2026-09-23, v0.6.0 + sửa `lead.md` sau Lab 9, Claude Code 2.1.280).** PASS.

| Đo | Kết quả |
|---|---|
| Brief | Scout T-1: `Required skills bug-loop — chỉ Phase 1–4`. T-2: "không có ngoài skill commit theo disposition". Writer T-3: `bug-loop (đủ Phase 1–6)`, `Verification L3 (tiền)`. Sửa `lead.md` sau Lab 9 có hiệu lực |
| Scout | `Skill xia` > `Skill bug-loop` > 5 Bash (`cat`, `python3 -c`); 0 Edit/Write, 0 git ghi. Loop đỏ theo từng lớp (subtotal → voucher → ship → hiển thị) trước giả thuyết. Bảng **H1–H5** có dự đoán, mỗi probe đổi một biến: H1 ngưỡng bác, H2 voucher xác nhận, H3 làm tròn hiển thị "che, không gây", H4 checkout truyền sai bác, H5 float noise là cơ chế thứ hai (vd. 2150 − 6% = `2020.9999999999998`). Dừng ở Phase 4 |
| Lead | Tự chạy lại repro, đưa Human 3 hướng (a/b/c) + hỏi kiểu trả về có tính là đổi public API không; không tự quyết boundary |
| Writer T-3 | Làm trong `.worktrees/T-3`. `Skill bug-loop` > repro 2 lần > test mới RED `2 failed` > sửa > GREEN `5 passed` > 2 mutant ở `/tmp` đỏ > `smart-commits` > `66cb766` |
| **REJECT** | Reviewer (read-only, `git archive`) thấy mutant `round(subtotal*(1-pct/100))` qua cả 5 test (`test-survives-sabotage`). Lead chạy lại xác nhận → `REJECT 66cb766 — T-3 — tests/test_voucher.py:8-13`. Brief sửa liệt kê 4 mutant phải đỏ, cấm đụng `voucher.py`, commit mới không amend |
| Rework | Writer brute-force tìm input phân biệt từng mutant, thêm test, 6 mutant đều đỏ, `10 passed` → `6fd41ab`. Lead `ACCEPT 6fd41ab — T-3` |
| Supervisor | 4 mốc (T-2 accept, T-1 chẩn đoán, T-3 reject, T-3 accept) → 4 `NOTE`, 0 `DRIFT`. `D13` kiểm `bug-loop` **chỉ** ở Scout T-1 và writer T-3; T-2 chỉ kiểm `smart-commits`. Writer lượt 2 (resume) không gọi lại skill → ghi là không vi phạm. Tool: Bash 23 · SendMessage 9 · ListAgents 1 · Write 12 (**chỉ** `~/.claude/agent-memory/supervisor/`) · 0 git mutation |
| Git | `main` = `8520b2c`, remote rỗng, 0 `DEBUG-`; diff T-3 chỉ `voucher.py` + `tests/`; T-2 nhánh riêng `936e307` chỉ README |

- **Proof L3 hai tầng chạy đúng ý:** mutation của writer chưa đủ, Reviewer bắt được, Lead từ
  chối. Đây là lần đầu lab có `REJECT` vì test yếu, không phải vì code sai.
- **Supervisor ghi memory ở user level** (`~/.claude/agent-memory/supervisor/`, dùng chung với
  Supervisor thật): `lab9b.md` + 3 pattern vào `patterns.md`. Chạy lab trên máy đang dùng thật
  thì xoá `lab9b.md` sau lab nếu không muốn giữ.
- Worktree `.worktrees/` hiện `??` trong `git status` vì `.gitignore` fixture không có — vô hại.
