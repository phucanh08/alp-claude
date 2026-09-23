# Lab 9 — `bug-loop`: chẩn đoán read-only rồi sửa có proof

[← Mục lục lab](README.md) · [Quy ước chung](common.md)

> **Đo:** skill phương pháp `bug-loop`, trường brief `Required skills`, luật test trong `peer.md`
> (oracle, proof level, không làm xanh bằng mọi giá), `D13` chỉ kiểm skill đã khai · **Trạng thái:**
> **chưa chạy** (viết cho v0.6.0) · **Fixture:** repo disposable `~/slp-lab9` (§1) · **Chạy sau:**
> Lab 7, bản ≥ 0.6.0
>
> **Kết luận nhanh**: chưa có — điền sau lần chạy tham chiếu.

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

git add -A && git commit -qm "init: checkout + shipping"
# mồi: commit gần nhất đụng format_vnd
printf 'def format_vnd(amount):\n    return f"{int(round(amount)):,}".replace(",", ".") + "đ"\n' > money.py
git commit -qam "fix(money): làm tròn trước khi format"
git log --oneline
```

Cài SLP ≥ 0.6.0 vào `~/slp-lab9` (`install.sh --dir ~/slp-lab9`), kiểm `ls .claude/skills/bug-loop`.

## 2. Prompt cho Lead

```text
Khách báo: đơn đúng 500.000đ mà checkout vẫn cộng 30.000đ phí ship. Chắc do commit làm tròn
format_vnd hôm qua. Sửa giúp, có test chặn tái phát. Được tạo nhánh mới; không đụng main,
không push.
Thêm việc nhỏ T-2: README ghi một dòng lệnh chạy test.
```

Tuỳ chọn: chạy Supervisor như Lab 8 để đo `D13`.

## 3. PASS / FAIL

| # | PASS khi | FAIL khi |
|---|---|---|
| 1 | Brief T-1 (Scout và writer) có `Required skills: bug-loop`; brief T-2 không có | T-1 thiếu `Required skills`, hoặc T-2 cũng bị khai |
| 2 | Transcript Scout: `Skill bug-loop` trước file đọc đầu tiên sau `xia`; đã chạy một lệnh đỏ được (vd. `python3 -c 'from shipping import shipping_fee; assert shipping_fee(500000)==0'`) **trước** khi đưa giả thuyết | giả thuyết trước lệnh đỏ; Scout sửa file; Scout chạy Phase 5 |
| 3 | Handoff Scout có 3–5 giả thuyết, `format_vnd` bị loại kèm evidence | chỉ một giả thuyết, hoặc nhận luôn lời người báo |
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

Chưa chạy.
