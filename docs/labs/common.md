# Quy ước chung cho mọi lab

[← Mục lục lab](README.md)

Lab 1 và Lab 7 chạy trên repo disposable dựng sẵn. Từ Lab 2 chạy trên repo thật đã có `CLAUDE.md` điền
đủ contract. Mỗi lab dưới đây gồm: mục tiêu, prompt mẫu (đã chạy thật trên một repo static-site
nginx + Cloudflare Pages — thay phần nghiệp vụ cho repo của anh), dấu hiệu PASS/FAIL, và ghi chú
từ lần chạy tham chiếu.

Quy ước chung cho mọi lab:

- Lead là main session `claude --agent lead`. Human dán prompt trực tiếp, hoặc một session Claude
  Code khác gửi qua cross-session messaging (Lab 5).
- Mọi lab đều có ràng buộc cứng: **được tạo nhánh mới; không thay đổi nhánh chính** (main/dev/uat…);
  không push, không deploy, không gọi domain thật.
- Kiểm kết quả **không** bằng lời Lead kể, mà bằng: Git object (`git show`, `git diff sha^ sha`),
  transcript (`~/.claude/projects/<slug>/<session>.jsonl` + `subagents/*.jsonl`), và tự chạy lại
  verification trọng yếu.

Cách đọc transcript nhanh (Python stdlib):

```python
import json
lines=[json.loads(l) for l in open('<session>.jsonl') if l.strip()]
for d in lines:
    if d.get('type')!='assistant': continue
    for b in d['message'].get('content',[]):
        if b.get('type')=='tool_use' and b['name']=='Agent':
            i=b['input']; print(i.get('name'), i.get('subagent_type'), i.get('isolation'))
```

---

## Chạy headless (Lab 7c trở đi)

Lab dài chạy các session bằng `claude -p … --input-format stream-json --output-format stream-json
--verbose`, Human (hoặc một session Claude khác) đẩy message vào stdin qua `tail -f <name>.in`:

```bash
# start.sh <name> <agent> <cwd> <settings>
cd "$cwd" && tail -n +1 -f "$R/$name.in" | claude -p --agent "$agent" --name "$name" \
  --settings "$settings" --input-format stream-json --output-format stream-json --verbose > "$R/$name.out"
# say.sh <name> <text> — một dòng {"type":"user","message":{"role":"user","content":"…"}} vào $R/$name.in
```

- **Permission class:** mọi session cùng class. Supervisor chạy mode thường + sandbox → Lead cũng
  mode thường (allow rule qua `--settings`), không `--dangerously-skip-permissions`, nếu không
  message giữa hai bên bị hold. `-p` bỏ qua allow rule trong `.claude/settings.json` của project
  chưa trust — đưa allow rule vào file `--settings`.
- **Lệnh Bash nhiều bước** (`for`, `$(…)`, biến) bị harness từ chối ở `-p` ("cannot be statically
  analyzed"); interactive thì thành prompt cho Human. Agent tự đổi cách; không phải drift.
- **Audit skill call** bằng file transcript `~/.claude/projects/<slug>/<session>/subagents/*.jsonl`,
  không bằng stdout stream: event của teammate in-process trộn vào stream của Lead.
- **Fixture không để dưới `/tmp/claude*`**: sandbox luôn cho ghi vùng đó (Lab 8b).
- Prompt dán vào terminal interactive: **một đoạn, không dòng trống** — terminal cắt paste ở dòng
  trống (Lab 6).
