#!/usr/bin/env python3
"""ALP → Claude Code adapter của SLP.

Nguồn sự thật là layout kiểu alp-paseo trong project:

    ALP.md                              contract của repo (CLAUDE.md chỉ chứa `@ALP.md`)
    .alp/settings.json                  defaultAgent, workflow.mode, workflow.maxPeers
    .alp/WORKFLOW.md                    luồng phase, ghế, bảng cấm
    .alp/agents/<ghế>/AGENT.md          định nghĩa ghế (frontmatter Claude Code + prompt)
    .alp/agents/<ghế>/skills/<skill>/   bộ skill của ghế
    .alp/agents/<ghế>/hooks/<Event>[.*] hook riêng của ghế (dispatcher bên dưới gọi)
    .alp/agents/<ghế>/.mcp.json         MCP server riêng của ghế (→ frontmatter mcpServers)

Claude Code chỉ đọc `.claude/agents/*.md` và `.claude/skills/`, nên adapter sinh hai thứ đó từ
`.alp/` (`sync`) và gắn một dispatcher vào hook của `.claude/settings.json` (`hook <Event>`):

    PreToolUse(Skill)  chặn ghế gọi skill SLP không có trong `.alp/agents/<ghế>/skills/`
    mọi event đã đăng ký → chạy `.alp/agents/<agent_type>/hooks/<Event>*` của đúng ghế đang chạy
    SessionStart       đồng bộ `.alp/` → `.claude/` trước (sửa AGENT.md có hiệu lực từ session sau)

Lệnh:
    alp.py install --src <bundle> [--dir <root> | --global] [--force]
    alp.py sync [--dir <root> | --global] [--quiet]
    alp.py hook <Event>                (stdin: JSON hook input của Claude Code)
    alp.py uninstall [--dir <root> | --global] [--force]

Chỉ dùng thư viện chuẩn (Python 3.8+).
"""
import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys

APP = "alp-claude-slp"
SCHEMA = 2
HOOK_EVENTS = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop"]
HOOK_MARK = "slp/alp.py"  # nhận diện hook entry do SLP thêm
DEFAULT_ALP_SETTINGS = {"defaultAgent": "main", "workflow": {"mode": "smart", "maxPeers": 2}}
LEGACY_FILES = ["slp-role-skills.json", "slp-workflow.md"]  # bản dev 0.10.0 trước layout .alp
ADAPTER_FILES = {
    # đích trong .claude/        nguồn trong bundle
    "slp/alp.py": "adapters/claude/alp.py",
    "slp-supervisor.settings.json": "adapters/claude/supervisor.settings.json",
    "slp-mail.settings.json": "adapters/claude/slp-mail.settings.json",
    "slp-mail/slp_mail.py": "mcp/slp-mail/slp_mail.py",
}
for _s in (sys.stdout, sys.stderr):  # console Windows (cp1252) không in được tiếng Việt / ✔
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
TTY = sys.stdout.isatty()


def ok(msg):
    sys.stderr.flush()
    print(("\033[32m✔\033[0m " if TTY else "✔ ") + msg)


def warn(msg):
    sys.stdout.flush()
    print(("\033[33m!\033[0m " if TTY else "! ") + msg, file=sys.stderr)


def log(msg):
    sys.stderr.flush()
    print("  " + msg)


def die(msg):
    print(("\033[31m✘\033[0m " if TTY else "✘ ") + msg, file=sys.stderr)
    sys.exit(1)


# ---- fs helpers -----------------------------------------------------------------------


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha_file(path):
    with open(path, "rb") as fh:
        return sha_bytes(fh.read())


def read_bytes(path):
    with open(path, "rb") as fh:
        return fh.read()


def write_bytes(path, data):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(data)


def load_json(path, default=None):
    if not os.path.exists(path):
        return default
    raw = open(path, encoding="utf-8").read().strip()
    return json.loads(raw) if raw else default


def dump_json(path, data):
    write_bytes(path, (json.dumps(data, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))


def walk_files(base):
    """{relpath posix: abs path} của mọi file dưới base, bỏ __pycache__ và .DS_Store."""
    out = {}
    if not os.path.isdir(base):
        return out
    for d, dirs, files in os.walk(base):
        dirs[:] = sorted(x for x in dirs if x != "__pycache__")
        for f in sorted(files):
            if f == ".DS_Store" or f.endswith(".pyc"):
                continue
            p = os.path.join(d, f)
            out[os.path.relpath(p, base).replace(os.sep, "/")] = p
    return out


def dir_sig(base):
    return {rel: sha_file(p) for rel, p in walk_files(base).items()}


def copy_tree(src, dst):
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", ".DS_Store"))


def prune_empty(path, stop):
    """Xóa thư mục rỗng từ path lên tới (không gồm) stop."""
    path, stop = os.path.abspath(path), os.path.abspath(stop)
    while path.startswith(stop + os.sep):
        try:
            os.rmdir(path)
        except OSError:
            return
        path = os.path.dirname(path)


# ---- layout ---------------------------------------------------------------------------


class Layout:
    def __init__(self, root, is_global):
        self.is_global = is_global
        self.root = os.path.abspath(root)
        self.alp = os.path.join(self.root, ".alp")
        self.claude = os.path.join(self.root, ".claude")
        self.manifest = os.path.join(self.claude, "slp-manifest.json")
        self.generated = os.path.join(self.claude, "slp", "generated.json")
        self.settings = os.path.join(self.claude, "settings.json")

    def alp_settings(self):
        data = load_json(os.path.join(self.alp, "settings.json"), {}) or {}
        return data if isinstance(data, dict) else {}

    def default_agent(self):
        return self.alp_settings().get("defaultAgent") or "main"

    def agents(self):
        base = os.path.join(self.alp, "agents")
        if not os.path.isdir(base):
            return []
        return sorted(n for n in os.listdir(base) if os.path.isfile(os.path.join(base, n, "AGENT.md")))

    def agent_dir(self, name):
        return os.path.join(self.alp, "agents", name)

    def agent_skills(self, name):
        base = os.path.join(self.agent_dir(name), "skills")
        if not os.path.isdir(base):
            return []
        return sorted(n for n in os.listdir(base) if os.path.isfile(os.path.join(base, n, "SKILL.md")))


def layout_from_args(args):
    if getattr(args, "global_", False):
        return Layout(os.path.expanduser("~"), True)
    return Layout(args.dir or os.getcwd(), False)


def hook_layout(data):
    """Root cho hook: project chứa .alp (CLAUDE_PROJECT_DIR / cwd, đi lên), không có → ~/.alp."""
    start = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    d = os.path.abspath(start)
    while True:
        if os.path.isdir(os.path.join(d, ".alp", "agents")):
            return Layout(d, d == os.path.expanduser("~"))
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    home = os.path.expanduser("~")
    if os.path.isdir(os.path.join(home, ".alp", "agents")):
        return Layout(home, True)
    return None


# ---- sinh .claude/ từ .alp/ -------------------------------------------------------------


def yaml_lines(value, indent):
    """JSON → YAML block (chỉ object/array/scalar JSON; scalar dùng json.dumps, là YAML hợp lệ)."""
    pad = "  " * indent
    out = []
    if isinstance(value, dict):
        for k, v in value.items():
            key = json.dumps(str(k), ensure_ascii=False)
            if isinstance(v, (dict, list)) and v:
                out.append("%s%s:" % (pad, key))
                out.extend(yaml_lines(v, indent + 1))
            else:
                out.append("%s%s: %s" % (pad, key, json.dumps(v, ensure_ascii=False)))
    elif isinstance(value, list):
        for v in value:
            if isinstance(v, (dict, list)) and v:
                sub = yaml_lines(v, indent + 1)
                out.append("%s- %s" % (pad, sub[0].lstrip()))
                out.extend(sub[1:])
            else:
                out.append("%s- %s" % (pad, json.dumps(v, ensure_ascii=False)))
    return out


def render_agent(lay, name):
    """Nội dung .claude/agents/<name>.md: AGENT.md + mcpServers từ .mcp.json (nếu có server)."""
    text = open(os.path.join(lay.agent_dir(name), "AGENT.md"), encoding="utf-8").read()
    mcp = load_json(os.path.join(lay.agent_dir(name), ".mcp.json"), {}) or {}
    servers = mcp.get("mcpServers") if isinstance(mcp, dict) else None
    if servers and text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            front = text[4:end]
            if not any(l.startswith("mcpServers:") for l in front.splitlines()):
                block = "\n".join(["mcpServers:"] + yaml_lines(servers, 1))
                text = "---\n" + front.rstrip("\n") + "\n" + block + text[end:]
    return text.encode("utf-8")


def skill_sources(lay):
    """{skill: [ghế có skill đó]}; ghế mặc định đứng đầu, rồi lead, peer, còn lại theo tên."""
    order = [lay.default_agent(), "lead", "peer"] + lay.agents()
    seen, ranked = set(), []
    for a in order:
        if a in lay.agents() and a not in seen:
            seen.add(a)
            ranked.append(a)
    out = {}
    for a in ranked:
        for s in lay.agent_skills(a):
            out.setdefault(s, []).append(a)
    return out


def sync(lay, adopt=(), backup_dir=None, quiet=False):
    """Sinh .claude/agents/*.md và .claude/skills/<s>/ từ .alp/. Trả về list thay đổi.

    Chỉ ghi đè file/thư mục adapter đã sinh trước đó (generated.json) hoặc nằm trong `adopt`
    (bản SLP cũ ghi trong manifest — backup nếu khác). Thứ của người dùng trùng tên → bỏ qua, cảnh báo.
    """
    if not lay.agents():
        if not quiet:
            warn("không có %s — chưa cài ALP? bỏ qua sync" % os.path.join(lay.alp, "agents"))
        return []
    gen = load_json(lay.generated, {}) or {}
    prev_agents = set(gen.get("agents", []))
    prev_skills = set(gen.get("skills", {}))
    adopt = set(adopt)
    changes = []

    def claim(target, owned, kind, rel):
        """Được phép ghi target? owned = adapter đã sinh trước đó."""
        if not os.path.exists(target) or owned:
            return True
        if rel in adopt:
            if backup_dir:
                dst = os.path.join(backup_dir, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                (copy_tree if os.path.isdir(target) else shutil.copy2)(target, dst)
                warn("%s (bản SLP cũ) → backup %s" % (rel, dst))
            return True
        warn("%s đã có và không do adapter sinh → giữ nguyên, bỏ qua %s" % (rel, kind))
        return False

    # agents
    agents_out = []
    for name in lay.agents():
        rel = "agents/%s.md" % name
        target = os.path.join(lay.claude, rel)
        data = render_agent(lay, name)
        if os.path.isfile(target) and read_bytes(target) == data:
            agents_out.append(name)
            continue
        if not claim(target, name in prev_agents, "agent", rel):
            continue
        write_bytes(target, data)
        agents_out.append(name)
        changes.append(rel)
    for name in sorted(prev_agents - set(agents_out)):
        target = os.path.join(lay.claude, "agents", name + ".md")
        if os.path.isfile(target) and name not in lay.agents():
            os.remove(target)
            changes.append("-agents/%s.md" % name)

    # skills: hợp bộ skill của mọi ghế
    skills_out = {}
    for skill, owners in skill_sources(lay).items():
        src = os.path.join(lay.agent_dir(owners[0]), "skills", skill)
        sig = dir_sig(src)
        diverged = [a for a in owners[1:] if dir_sig(os.path.join(lay.agent_dir(a), "skills", skill)) != sig]
        if diverged and not quiet:
            warn("skill %s: bản của %s khác bản của %s — Claude Code chỉ có một bản mỗi tên, dùng bản %s"
                 % (skill, ", ".join(diverged), owners[0], owners[0]))
        rel = "skills/" + skill
        target = os.path.join(lay.claude, rel)
        if os.path.isdir(target) and dir_sig(target) == sig:
            skills_out[skill] = owners[0]
            continue
        if not claim(target, skill in prev_skills, "skill", rel):
            continue
        copy_tree(src, target)
        skills_out[skill] = owners[0]
        changes.append(rel)
    for skill in sorted(prev_skills - set(skills_out)):
        target = os.path.join(lay.claude, "skills", skill)
        if os.path.isdir(target) and skill not in skill_sources(lay):
            shutil.rmtree(target)
            changes.append("-skills/" + skill)

    # ghế mặc định của session thường (chỉ khi key `agent` do SLP quản)
    man = load_json(lay.manifest, {}) or {}
    if "agent" in (man.get("settings") or {}).get("keys", []):
        st = load_json(lay.settings, {}) or {}
        if st.get("agent") != lay.default_agent():
            st["agent"] = lay.default_agent()
            dump_json(lay.settings, st)
            changes.append("settings.json:agent=" + lay.default_agent())

    dump_json(lay.generated, {"agents": agents_out, "skills": skills_out})
    return changes


# ---- hook dispatcher --------------------------------------------------------------------


def guard_skill(lay, agent, data):
    """PreToolUse(Skill): skill SLP ngoài bộ của ghế → lý do chặn; còn lại None."""
    if os.environ.get("ALP_SKILL_GUARD", "1") in ("0", "off", "false"):
        return None
    skill = str((data.get("tool_input") or {}).get("skill") or "").lstrip("/")
    if not skill or ":" in skill:  # skill plugin (plugin:skill) không thuộc SLP
        return None
    managed = skill_sources(lay)
    if skill not in managed or agent not in lay.agents():
        return None  # skill ngoài SLP, hoặc agent không phải ghế ALP (Explore, general-purpose…)
    own = lay.agent_skills(agent)
    if skill in own:
        return None
    rel = os.path.relpath(os.path.join(lay.agent_dir(agent), "skills"), lay.root)
    return ("SLP: ghế `%s` không có skill `%s` (%s/: %s). Skill không cấp authority và mỗi ghế chỉ "
            "dùng bộ của mình — xem .alp/WORKFLOW.md § Ghế nào cấm skill nào. Cần skill này: "
            "người nhận việc → BLOCKED về người giao việc; người giao việc → giao đúng ghế."
            % (agent, skill, rel, ", ".join(own) or "rỗng"))


def agent_hooks(lay, agent, event):
    base = os.path.join(lay.agent_dir(agent), "hooks")
    if not os.path.isdir(base):
        return []
    out = []
    for f in sorted(os.listdir(base)):
        p = os.path.join(base, f)
        if not os.path.isfile(p) or f.startswith(".") or f.endswith((".md", ".json", ".txt")):
            continue
        if f == event or f.startswith(event + "."):
            out.append(p)
    return out


def hook_cmd(path):
    if path.endswith(".py"):
        return [sys.executable, path]
    if path.endswith(".sh"):
        return ["bash", path]
    if path.endswith(".js") or path.endswith(".mjs"):
        return ["node", path]
    if path.endswith(".ps1"):
        return ["pwsh", "-NoProfile", "-File", path]
    return [path]


def cmd_hook(args):
    raw = sys.stdin.buffer.read().decode("utf-8", "replace")  # JSON hook là UTF-8, không theo locale
    try:
        data = json.loads(raw) if raw.strip() else {}
    except ValueError:
        return 0
    event = args.event
    lay = hook_layout(data)
    if lay is None:
        return 0
    # project tự có adapter → bản global nhường, tránh chạy hook hai lần
    me = os.path.realpath(os.path.abspath(__file__))
    own = os.path.join(lay.claude, "slp", "alp.py")
    if os.path.isfile(own) and os.path.realpath(own) != me:
        return 0
    if event == "SessionStart":
        try:
            changes = sync(lay, quiet=True)
        except Exception as exc:  # hook không được làm hỏng session
            print("SLP: sync .alp → .claude lỗi: %s" % exc, file=sys.stderr)
            changes = []
        if changes:
            print("SLP: đã đồng bộ .alp → .claude (%s). Định nghĩa agent mới có hiệu lực từ session sau."
                  % ", ".join(changes))
    agent = data.get("agent_type") or lay.default_agent()
    if event == "PreToolUse" and data.get("tool_name") == "Skill":
        reason = guard_skill(lay, agent, data)
        if reason:
            print(reason, file=sys.stderr)
            return 2
    for path in agent_hooks(lay, agent, event):
        try:
            r = subprocess.run(hook_cmd(path), input=raw.encode("utf-8"), capture_output=True,
                               cwd=lay.root, timeout=60)
        except Exception as exc:
            print("SLP hook %s: %s" % (path, exc), file=sys.stderr)
            continue
        if r.stdout:
            sys.stdout.write(r.stdout.decode("utf-8", "replace"))
        if r.returncode == 2:
            sys.stderr.write(r.stderr.decode("utf-8", "replace"))
            return 2
        if r.returncode != 0:
            sys.stderr.write("SLP hook %s exit %d: %s" % (path, r.returncode, r.stderr.decode("utf-8", "replace")))
    return 0


# ---- install -----------------------------------------------------------------------------


def hook_command(lay, event):
    base = "$HOME/.claude" if lay.is_global else "$CLAUDE_PROJECT_DIR/.claude"
    return 'python3 "%s/slp/alp.py" hook %s' % (base, event)


def merge_settings(lay):
    """Thêm env, teammateMode, agent (project), hook dispatcher. Trả về (created, keys)."""
    created = not os.path.exists(lay.settings)
    data = load_json(lay.settings, {}) or {}
    if not isinstance(data, dict):
        die("settings.json không phải object JSON")
    keys = []
    env = data.setdefault("env", {})
    if "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" not in env:
        env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
        keys.append("env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS")
    if "teammateMode" not in data:
        data["teammateMode"] = "in-process"
        keys.append("teammateMode")
    if not lay.is_global and "agent" not in data:
        data["agent"] = lay.default_agent()
        keys.append("agent")
    hooks = data.setdefault("hooks", {})
    for event in HOOK_EVENTS:
        entries = hooks.setdefault(event, [])
        entries[:] = [e for e in entries if not any(HOOK_MARK in (h.get("command") or "") for h in e.get("hooks", []))]
        entry = {"hooks": [{"type": "command", "command": hook_command(lay, event)}]}
        if event in ("PreToolUse", "PostToolUse"):
            entry = dict({"matcher": "*"}, **entry)
        entries.append(entry)
    keys.append("hooks")
    dump_json(lay.settings, data)
    return created, keys


def unmerge_settings(lay, created, keys):
    if not os.path.exists(lay.settings):
        return "missing"
    data = load_json(lay.settings, {}) or {}
    for k in keys:
        if k.startswith("env."):
            (data.get("env") or {}).pop(k[4:], None)
        elif k == "hooks":
            hooks = data.get("hooks") or {}
            for event in list(hooks):
                hooks[event] = [e for e in hooks[event]
                                if not any(HOOK_MARK in (h.get("command") or "") for h in e.get("hooks", []))]
                if not hooks[event]:
                    hooks.pop(event)
            if not hooks:
                data.pop("hooks", None)
        else:
            data.pop(k, None)
    if isinstance(data.get("env"), dict) and not data["env"]:
        data.pop("env")
    if created and not data:
        os.remove(lay.settings)
        return "deleted"
    dump_json(lay.settings, data)
    return "updated"


def scaffold(src):
    """{relpath trong .alp: bytes} theo templates/ của bundle — giống initProject của alp-paseo."""
    t = os.path.join(src, "templates")
    role_skills = load_json(os.path.join(t, "role-skills.json"))
    files = {"WORKFLOW.md": read_bytes(os.path.join(t, "WORKFLOW.md"))}
    dirs = []
    for name in sorted(os.listdir(os.path.join(t, "agents"))):
        agent_md = os.path.join(t, "agents", name, "AGENT.md")
        if not os.path.isfile(agent_md):
            continue
        if name not in role_skills:
            die("templates/role-skills.json thiếu ghế %s" % name)
        base = "agents/%s" % name
        dirs += [base + "/skills", base + "/hooks"]
        files[base + "/AGENT.md"] = read_bytes(agent_md)
        files[base + "/.mcp.json"] = b'{\n  "mcpServers": {}\n}\n'
        for skill in role_skills[name]:
            sdir = os.path.join(t, "skills", skill)
            if not os.path.isfile(os.path.join(sdir, "SKILL.md")):
                die("bundle thiếu templates/skills/%s/SKILL.md" % skill)
            for rel, p in walk_files(sdir).items():
                files["%s/skills/%s/%s" % (base, skill, rel)] = read_bytes(p)
    return files, dirs


def cmd_install(args):
    src = os.path.abspath(args.src)
    for need in ["templates/ALP.md", "templates/WORKFLOW.md", "templates/role-skills.json",
                 "adapters/claude/CLAUDE.md"] + list(ADAPTER_FILES.values()):
        if not os.path.isfile(os.path.join(src, need)):
            die("bundle thiếu " + need)
    lay = layout_from_args(args)
    version = open(os.path.join(src, "VERSION"), encoding="utf-8").read().strip() if os.path.exists(os.path.join(src, "VERSION")) else "unknown"
    stamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    backup = os.path.join(lay.claude, "backups", "slp-" + stamp)
    old = load_json(lay.manifest, {}) or {}
    print("\nSLP %s → %s (%s)\n" % (version, lay.root, "global" if lay.is_global else "project"))
    if old:
        warn("đã có %s — cài đè lên bản %s (uninstall trước nếu muốn sạch)." % (lay.manifest, old.get("version", "?")))
    if not lay.is_global and not os.path.isdir(os.path.join(lay.root, ".git")):
        if subprocess.run(["git", "-C", lay.root, "rev-parse", "--show-toplevel"], capture_output=True).returncode != 0:
            warn("%s không phải git repo — Lead cần Git để Peer commit/handoff SHA (bình thường nếu là gốc workspace chỉ cho Supervisor)." % lay.root)

    # 1. .alp/ — điền file thiếu; file SLP đã ship mà chưa ai sửa → cập nhật; đã sửa → giữ
    files, dirs = scaffold(src)
    shipped_old = old.get("alp", {}) if old.get("schemaVersion", 1) >= 2 else {}
    shipped = {}
    counts = {"created": 0, "updated": 0, "unchanged": 0, "kept": 0}
    for d in [""] + dirs:
        os.makedirs(os.path.join(lay.alp, d), exist_ok=True)
    for rel, data in sorted(files.items()):
        target = os.path.join(lay.alp, rel)
        new_sha = sha_bytes(data)
        shipped[rel] = new_sha
        if not os.path.exists(target):
            write_bytes(target, data)
            counts["created"] += 1
            continue
        cur = sha_file(target)
        if cur == new_sha:
            counts["unchanged"] += 1
        elif cur == shipped_old.get(rel) or args.force:
            if args.force and cur != shipped_old.get(rel):
                write_bytes(os.path.join(backup, "alp", rel), read_bytes(target))
            write_bytes(target, data)
            counts["updated"] += 1
        else:
            counts["kept"] += 1
            if new_sha != shipped_old.get(rel):  # upstream đổi từ lần cài trước → để bản mới cạnh backup
                write_bytes(os.path.join(backup, "upstream", "alp", rel), data)
                warn(".alp/%s đã sửa → giữ; bản mới để tham khảo: %s" % (rel, os.path.join(backup, "upstream", "alp", rel)))
    alp_settings_created = False
    st_path = os.path.join(lay.alp, "settings.json")
    if not os.path.exists(st_path):
        dump_json(st_path, DEFAULT_ALP_SETTINGS)
        alp_settings_created = True
    ok(".alp/: tạo %(created)d, cập nhật %(updated)d, giữ bản đã sửa %(kept)d, không đổi %(unchanged)d" % counts)

    # 2. ALP.md + CLAUDE.md (project)
    docs = {}
    if not lay.is_global:
        claude_md = os.path.join(lay.root, "CLAUDE.md")
        alp_md = os.path.join(lay.root, "ALP.md")
        main_root = ""
        common = subprocess.run(["git", "-C", lay.root, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                                capture_output=True, text=True).stdout.strip()
        if common and os.path.abspath(common) != os.path.join(lay.root, ".git"):
            main_root = os.path.dirname(common)  # linked worktree: lấy bản thật chưa commit từ main worktree
        legacy = os.path.exists(claude_md) and "@ALP.md" not in open(claude_md, encoding="utf-8").read()
        if os.path.exists(alp_md):
            log("ALP.md đã có — giữ nguyên.")
        elif legacy:
            warn("CLAUDE.md cũ (không import @ALP.md) → giữ làm contract, không tạo ALP.md. Muốn theo layout ALP: "
                 "dời nội dung sang ALP.md và để CLAUDE.md chỉ còn dòng `@ALP.md`.")
        else:
            seed = os.path.join(main_root, "ALP.md") if main_root else ""
            data = read_bytes(seed) if seed and os.path.isfile(seed) else read_bytes(os.path.join(src, "templates", "ALP.md"))
            write_bytes(alp_md, data)
            docs["ALP.md"] = sha_bytes(data)
            ok("ALP.md tạo %s — ĐIỀN contract của repo trước khi giao writer" % ("từ main worktree" if seed and os.path.isfile(seed) else "từ template"))
        if not os.path.exists(claude_md):
            seed = os.path.join(main_root, "CLAUDE.md") if main_root else ""
            data = read_bytes(seed) if seed and os.path.isfile(seed) else read_bytes(os.path.join(src, "adapters", "claude", "CLAUDE.md"))
            write_bytes(claude_md, data)
            docs["CLAUDE.md"] = sha_bytes(data)
            ok("CLAUDE.md tạo (import @ALP.md)")
        elif not legacy:
            log("CLAUDE.md đã import @ALP.md — giữ nguyên.")
    # giữ dấu tài liệu do bản trước tạo (để uninstall còn biết)
    for k, v in (old.get("docs") or {}).items():
        docs.setdefault(k, v)
    if old.get("schemaVersion", 1) < 2 and (old.get("claudeMd") or {}).get("created"):
        docs.setdefault("CLAUDE.md", old["claudeMd"].get("sha256", ""))

    # 3. file adapter trong .claude/
    for dst_rel, src_rel in ADAPTER_FILES.items():
        dst = os.path.join(lay.claude, dst_rel)
        data = read_bytes(os.path.join(src, src_rel))
        if dst_rel == "slp-supervisor.settings.json" and os.path.exists(dst) and read_bytes(dst) != data and not args.force:
            write_bytes(os.path.join(backup, dst_rel), read_bytes(dst))
            warn("%s khác bản mới → backup %s" % (dst_rel, os.path.join(backup, dst_rel)))
        write_bytes(dst, data)
        if dst_rel.endswith(".py"):
            os.chmod(dst, 0o755)
    ok("adapter: " + ", ".join(sorted(ADAPTER_FILES)))

    # 4. dọn bản cũ: router ask-alp (< 0.10.0), file rời của bản dev 0.10.0
    legacy_router = os.path.join(lay.claude, "skills", "ask-alp")
    if os.path.isfile(os.path.join(legacy_router, "SKILL.md")) and "name: ask-alp" in open(os.path.join(legacy_router, "SKILL.md"), encoding="utf-8").read():
        os.makedirs(os.path.join(backup, "skills"), exist_ok=True)
        shutil.move(legacy_router, os.path.join(backup, "skills", "ask-alp"))
        warn("router cũ skills/ask-alp → %s" % os.path.join(backup, "skills", "ask-alp"))
    for f in LEGACY_FILES:
        if os.path.isfile(os.path.join(lay.claude, f)):
            os.remove(os.path.join(lay.claude, f))
            log("xóa .claude/%s (thay bằng .alp/)" % f)

    # 5. settings.json
    s_created, s_keys = merge_settings(lay)
    if old.get("settings"):
        s_created = s_created or old["settings"].get("created", False)
        s_keys = sorted(set(s_keys) | set(old["settings"].get("keys", [])))
    ok("settings.json: env, teammateMode%s, hook dispatcher (%s)" % ("" if lay.is_global else ", agent", ", ".join(HOOK_EVENTS)))

    # 6. manifest trước sync (sync đọc settings.keys để quản key `agent`)
    adopt = list(old.get("agents", [])) + list(old.get("skills", []))  # bản schema 1: file SLP cài thẳng vào .claude
    manifest = {
        "schemaVersion": SCHEMA, "app": APP, "version": version,
        "ref": os.environ.get("SLP_REF", "local"), "mode": "global" if lay.is_global else "project",
        "installedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "alp": shipped, "alpSettingsCreated": alp_settings_created or bool(old.get("alpSettingsCreated")),
        "docs": docs, "files": sorted(ADAPTER_FILES),
        "settings": {"created": s_created, "keys": s_keys},
    }
    dump_json(lay.manifest, manifest)

    # 7. sync .alp → .claude
    changes = sync(lay, adopt=adopt, backup_dir=backup)
    gen = load_json(lay.generated, {}) or {}
    ok("sinh .claude/agents: %s" % ", ".join(gen.get("agents", [])))
    ok("sinh .claude/skills: %s" % ", ".join(sorted(gen.get("skills", {}))))
    if not changes:
        log("(không có gì đổi so với lần sync trước)")
    ok("manifest: " + lay.manifest)

    # 8. validate
    if shutil.which("claude"):
        for d in ("agents", "skills"):
            r = subprocess.run(["claude", "plugin", "validate", os.path.join(lay.claude, d)], capture_output=True)
            (ok if r.returncode == 0 else warn)("claude plugin validate %s: %s" % (d, "passed" if r.returncode == 0 else "lỗi — chạy lại lệnh để xem"))
    return 0


# ---- uninstall ----------------------------------------------------------------------------


def cmd_uninstall(args):
    lay = layout_from_args(args)
    print("\nSLP uninstall ← %s (%s)\n" % (lay.root, "global" if lay.is_global else "project"))
    man = load_json(lay.manifest)
    if man is None:
        if not args.force:
            warn("không thấy %s — không biết SLP đã cài gì ở đây. Dùng --force để gỡ theo generated.json/.alp." % lay.manifest)
            return 1
        # không manifest: gỡ theo tên SLP từng ship (kể cả router ask-alp < 0.10.0)
        man = {"schemaVersion": SCHEMA,
               "agents": ["agents/%s.md" % a for a in ("main", "lead", "peer", "supervisor", "oracle", "reviewer")],
               "skills": ["skills/" + s for s in ("goal-griller", "xia", "sequence-execution-plan", "prompt-leverage",
                                                  "smart-commits", "bug-loop", "ask-alp")]}

    # 1. sinh ra trong .claude/
    gen = load_json(lay.generated, {}) or {}
    rels = ["agents/%s.md" % a for a in gen.get("agents", [])] + ["skills/" + s for s in gen.get("skills", {})]
    rels += list(man.get("agents", [])) + list(man.get("skills", []))  # schema 1
    for rel in sorted(set(rels)):
        if not (rel.startswith("agents/") or rel.startswith("skills/")) or ".." in rel or rel.count("/") != 1:
            warn("path lạ '%s' → bỏ qua" % rel)
            continue
        p = os.path.join(lay.claude, rel)
        if os.path.isdir(p):
            shutil.rmtree(p)
            ok("xóa .claude/" + rel)
        elif os.path.isfile(p):
            os.remove(p)
            ok("xóa .claude/" + rel)
    for d in ("agents", "skills"):
        prune_empty(os.path.join(lay.claude, d), lay.claude)

    # 2. file adapter (giữ alp.py tới cuối: đang chạy chính nó cũng không sao trên POSIX/Windows)
    for rel in sorted(set(man.get("files", [])) | set(ADAPTER_FILES) | set(LEGACY_FILES) | {"slp/generated.json"}):
        p = os.path.join(lay.claude, rel)
        if os.path.isfile(p):
            os.remove(p)
            ok("xóa .claude/" + rel)
            prune_empty(os.path.dirname(p), lay.claude)

    # 3. .alp/: xóa file SLP ship mà chưa sửa; đã sửa → giữ (trừ --force)
    kept = 0
    for rel, want in sorted((man.get("alp") or {}).items()):
        p = os.path.join(lay.alp, rel)
        if not os.path.isfile(p):
            continue
        if sha_file(p) == want or args.force:
            os.remove(p)
            prune_empty(os.path.dirname(p), lay.alp)
        else:
            kept += 1
    st = os.path.join(lay.alp, "settings.json")
    if os.path.isfile(st) and (args.force or (man.get("alpSettingsCreated") and load_json(st) == DEFAULT_ALP_SETTINGS)):
        os.remove(st)
    if args.force and os.path.isdir(lay.alp):
        shutil.rmtree(lay.alp)
    else:
        for d, dirs, files in os.walk(lay.alp, topdown=False):
            if not os.listdir(d):
                os.rmdir(d)
    if os.path.isdir(lay.alp):
        warn("giữ %s (%d file đã sửa hoặc do anh thêm; --force để xóa)" % (lay.alp, kept))
    else:
        ok("xóa .alp/")

    # 4. agent memory — dữ liệu của ghế, chỉ xóa khi --force
    mems = [os.path.join(lay.claude, "agent-memory-local", n) for n in ("lead", "supervisor")]
    if lay.is_global:
        mems.append(os.path.join(lay.claude, "agent-memory", "supervisor"))
    for m in mems:
        if os.path.isdir(m):
            if args.force:
                shutil.rmtree(m)
                ok("xóa " + m)
            else:
                warn("giữ %s (memory của ghế; --force để xóa)" % m)
    prune_empty(os.path.join(lay.claude, "agent-memory-local"), lay.claude)

    # 5. settings.json
    s = man.get("settings") or {}
    if s.get("keys") or s.get("created"):
        r = unmerge_settings(lay, s.get("created", False), s.get("keys", []))
        ok("settings.json: %s" % {"deleted": "SLP tạo và giờ rỗng → xóa", "updated": "gỡ key/hook SLP, key khác giữ nguyên", "missing": "đã không còn"}[r])

    # 6. ALP.md / CLAUDE.md — chỉ khi SLP tạo và chưa sửa
    docs = dict(man.get("docs") or {})
    if man.get("schemaVersion", 1) < 2 and (man.get("claudeMd") or {}).get("created"):
        docs["CLAUDE.md"] = man["claudeMd"].get("sha256", "")
    if not lay.is_global:
        for name, want in docs.items():
            p = os.path.join(lay.root, name)
            if not os.path.isfile(p):
                continue
            same = sha_file(p) == want
            if same or args.force:
                os.remove(p)
                ok("xóa %s (%s)" % (name, "chưa sửa" if same else "--force"))
            else:
                warn("%s do SLP tạo nhưng đã sửa → giữ (--force để xóa)" % name)

    # 7. manifest + thư mục rỗng
    if os.path.isfile(lay.manifest):
        os.remove(lay.manifest)
        ok("xóa manifest")
    prune_empty(os.path.join(lay.claude, "slp"), lay.claude)
    try:
        os.rmdir(lay.claude)
        ok("xóa .claude/ (rỗng)")
    except OSError:
        pass
    print("\nXong. Session đang chạy (nếu có) vẫn giữ definition cũ tới khi thoát.")
    return 0


# ---- CLI ---------------------------------------------------------------------------------


def main(argv=None):
    ap = argparse.ArgumentParser(prog="alp.py", description="ALP → Claude Code adapter của SLP")
    sub = ap.add_subparsers(dest="cmd")
    sub.required = True

    def target(p):
        g = p.add_mutually_exclusive_group()
        g.add_argument("--dir", help="repo root (mặc định: thư mục hiện tại)")
        g.add_argument("--global", dest="global_", action="store_true", help="~/.alp + ~/.claude")

    p = sub.add_parser("install", help="scaffold .alp/, cài adapter, merge settings, sync")
    p.add_argument("--src", required=True, help="thư mục bundle alp-claude")
    p.add_argument("--force", action="store_true", help="ghi đè file .alp/ đã sửa (có backup)")
    target(p)
    p = sub.add_parser("sync", help="sinh .claude/agents + .claude/skills từ .alp/")
    p.add_argument("--quiet", action="store_true")
    target(p)
    p = sub.add_parser("hook", help="dispatcher cho hook Claude Code (stdin JSON)")
    p.add_argument("event")
    p = sub.add_parser("uninstall", help="gỡ đúng những gì manifest ghi")
    p.add_argument("--force", action="store_true")
    target(p)
    args = ap.parse_args(argv)

    if args.cmd == "install":
        return cmd_install(args)
    if args.cmd == "sync":
        lay = layout_from_args(args)
        changes = sync(lay, quiet=args.quiet)
        if not args.quiet:
            ok("sync: " + (", ".join(changes) if changes else "không đổi"))
        return 0
    if args.cmd == "hook":
        return cmd_hook(args)
    return cmd_uninstall(args)


if __name__ == "__main__":
    sys.exit(main())
