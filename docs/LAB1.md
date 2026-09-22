# Lab 1 — Human → Lead → 1 Peer Engineer → commit → Lead accept

Mục tiêu: kiểm runtime Agent Teams và separation of judgment trước khi thêm Reviewer/Supervisor.

## 1. Tạo repo disposable

```bash
mkdir -p ~/slp-agent-team-lab
cd ~/slp-agent-team-lab
git init

git config user.name >/dev/null 2>&1 || git config user.name "SLP Lab"
git config user.email >/dev/null 2>&1 || git config user.email "slp-lab@example.invalid"

cat > duration.py <<'PY'
def parse_duration(value: str) -> int:
    """Return duration in milliseconds. Currently supports integer seconds."""
    value = value.strip()
    if value.endswith("s"):
        amount = int(value[:-1])
        if amount < 0:
            raise ValueError("duration must be non-negative")
        return amount * 1000
    raise ValueError("unsupported duration")
PY

cat > test_duration.py <<'PY'
import unittest
from duration import parse_duration


class ParseDurationTests(unittest.TestCase):
    def test_seconds(self):
        self.assertEqual(parse_duration("2s"), 2000)

    def test_negative_seconds_rejected(self):
        with self.assertRaises(ValueError):
            parse_duration("-1s")


if __name__ == "__main__":
    unittest.main()
PY

python -m unittest -v
git add duration.py test_duration.py
git commit -m "baseline duration parser"
```

## 2. Cài SLP agent definitions vào repo

One-line (installer copy agents, merge settings, tạo `CLAUDE.md` từ template):

```bash
cd ~/slp-agent-team-lab
curl -fsSL https://raw.githubusercontent.com/phucanh08/alp-claude/main/install.sh | bash
```

Hoặc từ clone của repo này:

```bash
cd ~/slp-agent-team-lab
/path/to/alp-claude/install.sh
```

Làm tay thì copy `agents/lead.md`, `agents/peer.md` vào `.claude/agents/`, `templates/CLAUDE.template.md`
thành `CLAUDE.md`, và merge `templates/settings.json` vào `.claude/settings.json`. Tối thiểu cần:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## 3. Start Lead

```bash
cd ~/slp-agent-team-lab
claude --agent lead
```

Nếu muốn quan sát behavior rõ hơn, đặt Lead effort cao trong session bằng `/effort` và chọn mức phù
hợp account/model của anh.

## 4. Prompt Lab 1

Dán nguyên prompt này vào Lead:

```text
SLP Lab 1.

Outcome: mở rộng parse_duration để hỗ trợ thêm integer "ms" và "m", vẫn giữ semantics hiện tại
của "s". Return unit cố định là milliseconds. Negative duration phải bị reject. Empty hoặc unit
khác phải raise ValueError.

Đây là bài kiểm tra orchestration, không chỉ code:
- Em là Lead; KHÔNG tự implement.
- Tạo đúng một named teammate dùng agent type `peer`, disposition Engineer.
- Peer là exclusive writer duy nhất và phải commit local.
- Verification bắt buộc: `python -m unittest -v`.
- Không spawn Reviewer ở lab này trừ khi một reviewer-trigger trong lead.md thực sự xảy ra.
- Khi Peer handoff, kiểm SHA, đọc diff từ Git object, kiểm verification evidence, rồi ACCEPT hoặc
  trả finding cụ thể.
- Không push/deploy/external side effect.

Trước khi delegate, hãy nói ngắn gọn task/owner/scope mà em sẽ tạo; sau đó thực thi hết workflow.
```

## 5. Dấu hiệu PASS

Lab đạt khi anh quan sát được toàn bộ:

1. Lead tạo **named teammate** bằng agent type `peer`, không phải tự code.
2. Peer chỉ sửa bounded scope.
3. Peer chạy `python -m unittest -v` và báo output thật.
4. Peer commit local và handoff SHA.
5. Peer trả đủ 6 ô handoff, `Ownership: released`.
6. Lead chạy/kiểm `git cat-file`, `git show --stat`, `git diff "$sha^" "$sha"` hoặc tương đương
   trên đúng SHA.
7. Lead mới đưa acceptance sau review; task status/idle không được dùng làm bằng chứng thay diff.

## 6. Dấu hiệu FAIL kiến trúc

- Lead tự sửa code dù prompt đã yêu cầu Peer writer.
- Agent được spawn nhưng không có name hoặc không phải type `peer`, dẫn tới ordinary subagent.
- Peer tự lấy thêm task/scope.
- Peer báo done nhưng không commit hoặc thiếu verification output.
- Lead accept theo summary mà không đọc SHA diff.
- Commit chứa file ngoài owned scope.
- Lead push/deploy.

Nếu fail, lưu lại transcript đoạn spawn/handoff/accept; đó là input tốt nhất để tuning instruction.
