"""Test adapter ALP → Claude Code (adapters/claude/alp.py). Chỉ stdlib; chạy được Linux/macOS/Windows.

    python3 -m unittest discover -s tests -v
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADAPTER = os.path.join(REPO, "adapters", "claude", "alp.py")
SEATS = ["lead", "main", "oracle", "peer", "reviewer", "supervisor"]
SKILLS = ["bug-loop", "goal-griller", "prompt-leverage", "sequence-execution-plan", "smart-commits", "xia"]
ENV = dict(os.environ, PYTHONIOENCODING="utf-8")


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def run(args, cwd, stdin=None, env=None):
    return subprocess.run([sys.executable] + args, cwd=cwd, input=stdin, capture_output=True, env=env or ENV)


class Installed(unittest.TestCase):
    """Repo tạm đã cài SLP; helper chung."""

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="alp-test-")
        subprocess.run(["git", "init", "-q", self.root], check=True)
        r = self.install()
        self.assertEqual(r.returncode, 0, r.stderr.decode("utf-8", "replace"))

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def p(self, *parts):
        return os.path.join(self.root, *parts)

    def install(self, *extra):
        return run([ADAPTER, "install", "--src", REPO, "--dir", self.root] + list(extra), self.root)

    def hook(self, event, payload, env_extra=None):
        env = dict(ENV, CLAUDE_PROJECT_DIR=self.root, **(env_extra or {}))
        data = json.dumps(dict(payload, hook_event_name=event, cwd=self.root), ensure_ascii=False).encode("utf-8")
        return run([self.p(".claude", "slp", "alp.py"), "hook", event], self.root, stdin=data, env=env)



class AdapterTest(Installed):
    # ---- layout ----

    def test_layout_matches_alp_paseo(self):
        for f in ["ALP.md", "CLAUDE.md", ".alp/settings.json", ".alp/WORKFLOW.md"]:
            self.assertTrue(os.path.isfile(self.p(f)), f)
        with open(self.p("CLAUDE.md"), encoding="utf-8") as fh:
            self.assertEqual(fh.read().strip(), "@ALP.md")
        role = json.loads(read(os.path.join(REPO, "templates", "role-skills.json")))
        for seat in SEATS:
            base = self.p(".alp", "agents", seat)
            self.assertTrue(os.path.isfile(os.path.join(base, "AGENT.md")), seat)
            self.assertTrue(os.path.isdir(os.path.join(base, "hooks")), seat)
            self.assertEqual(json.loads(read(os.path.join(base, ".mcp.json"))), {"mcpServers": {}})
            self.assertEqual(sorted(os.listdir(os.path.join(base, "skills"))), sorted(role[seat]), seat)
            self.assertTrue(os.path.isfile(self.p(".claude", "agents", seat + ".md")), seat)
        self.assertEqual(sorted(os.listdir(self.p(".claude", "skills"))), SKILLS)
        st = json.loads(read(self.p(".claude", "settings.json")))
        self.assertEqual(st["agent"], "main")
        self.assertEqual(st["env"]["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"], "1")
        # chỉ đăng ký thứ cần: sync lúc mở session + chặn skill; event khác khi có hooks/ của ghế
        self.assertEqual(sorted(st["hooks"]), ["PreToolUse", "SessionStart"])
        self.assertEqual(st["hooks"]["PreToolUse"][0]["matcher"], "Skill")
        self.assertIn("slp/alp.py", json.dumps(st["hooks"]["SessionStart"]))

    # ---- skill guard ----

    def test_guard_blocks_skill_outside_seat(self):
        r = self.hook("PreToolUse", {"agent_type": "peer", "tool_name": "Skill", "tool_input": {"skill": "goal-griller"}})
        self.assertEqual(r.returncode, 2)
        self.assertIn("goal-griller", r.stderr.decode("utf-8"))
        self.assertIn("ghế `peer`", r.stderr.decode("utf-8"))  # tiếng Việt không vỡ trên console Windows

    def test_guard_allows(self):
        cases = [
            {"agent_type": "peer", "tool_input": {"skill": "xia"}},          # skill của ghế
            {"tool_input": {"skill": "goal-griller"}},                       # không agent_type → main
            {"agent_type": "Explore", "tool_input": {"skill": "xia"}},       # agent ngoài SLP
            {"agent_type": "oracle", "tool_input": {"skill": "figma:x"}},    # skill plugin
            {"agent_type": "oracle", "tool_input": {"skill": "unrelated"}},  # skill ngoài SLP
        ]
        for c in cases:
            r = self.hook("PreToolUse", dict(c, tool_name="Skill"))
            self.assertEqual(r.returncode, 0, (c, r.stderr))

    def test_guard_can_be_disabled(self):
        r = self.hook("PreToolUse", {"agent_type": "peer", "tool_name": "Skill", "tool_input": {"skill": "goal-griller"}},
                      {"ALP_SKILL_GUARD": "0"})
        self.assertEqual(r.returncode, 0)

    # ---- hook riêng từng ghế ----

    def test_per_seat_hook_python(self):
        with open(self.p(".alp", "agents", "peer", "hooks", "PreToolUse.py"), "w", encoding="utf-8") as fh:
            fh.write("import json,sys\nd=json.loads(sys.stdin.buffer.read().decode('utf-8'))\n"
                     "c=d.get('tool_input',{}).get('command','')\n"
                     "if 'git push' in c:\n    sys.stderr.write('peer không push')\n    sys.exit(2)\n")
        push = {"tool_name": "Bash", "tool_input": {"command": "git push origin HEAD"}}
        self.assertEqual(self.hook("PreToolUse", dict(push, agent_type="peer")).returncode, 2)
        self.assertEqual(self.hook("PreToolUse", dict(push, agent_type="lead")).returncode, 0)
        self.assertEqual(self.hook("PreToolUse", {"agent_type": "peer", "tool_name": "Bash",
                                                  "tool_input": {"command": "ls"}}).returncode, 0)

    @unittest.skipUnless(os.name == "nt" and shutil.which("pwsh"), "chỉ Windows có pwsh")
    def test_per_seat_hook_powershell(self):
        with open(self.p(".alp", "agents", "lead", "hooks", "PostToolUse.ps1"), "w", encoding="utf-8") as fh:
            fh.write("$null = [Console]::In.ReadToEnd(); [Console]::Error.WriteLine('PS-HOOK-RAN'); exit 2\n")
        r = self.hook("PostToolUse", {"agent_type": "lead", "tool_name": "Read"})
        self.assertEqual(r.returncode, 2)  # exit 2: Claude Code đọc lý do ở stderr
        self.assertIn("PS-HOOK-RAN", r.stderr.decode("utf-8"))

    @unittest.skipUnless(shutil.which("bash"), "cần bash")
    def test_per_seat_hook_shell(self):
        with open(self.p(".alp", "agents", "main", "hooks", "Stop.sh"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("cat >/dev/null\necho SH-HOOK-RAN\n")
        r = self.hook("Stop", {})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("SH-HOOK-RAN", r.stdout.decode("utf-8"))

    # ---- sync ----

    def test_session_start_syncs_edits_and_mcp(self):
        with open(self.p(".alp", "agents", "oracle", "AGENT.md"), "a", encoding="utf-8") as fh:
            fh.write("\nDòng thêm của Human.\n")
        with open(self.p(".alp", "agents", "oracle", ".mcp.json"), "w", encoding="utf-8") as fh:
            json.dump({"mcpServers": {"docs": {"command": "npx", "args": ["-y", "x"]}}}, fh)
        r = self.hook("SessionStart", {})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("agents/oracle.md", r.stdout.decode("utf-8"))
        with open(self.p(".claude", "agents", "oracle.md"), encoding="utf-8") as fh:
            gen = fh.read()
        self.assertIn("Dòng thêm của Human.", gen)
        front = gen.split("\n---", 1)[0]
        self.assertIn('mcpServers:\n  "docs":\n    "command": "npx"', front)
        self.assertEqual(self.hook("SessionStart", {}).stdout, b"")  # lần hai: không đổi, im lặng

    def test_sync_removes_dropped_skill_and_keeps_user_skill(self):
        mine = self.p(".claude", "skills", "my-own")
        os.makedirs(mine)
        write(os.path.join(mine, "SKILL.md"), "---\nname: my-own\ndescription: x\n---\n")
        for seat in ("main", "lead"):
            shutil.rmtree(self.p(".alp", "agents", seat, "skills", "goal-griller"))
        r = run([ADAPTER, "sync", "--dir", self.root], self.root)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(os.path.exists(self.p(".claude", "skills", "goal-griller")))
        self.assertTrue(os.path.isfile(os.path.join(mine, "SKILL.md")))

    # ---- cài lại / gỡ ----

    def test_reinstall_keeps_customized_files(self):
        agent = self.p(".alp", "agents", "peer", "AGENT.md")
        with open(agent, "a", encoding="utf-8") as fh:
            fh.write("\ncustom\n")
        r = self.install()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("giữ bản đã sửa 1", r.stdout.decode("utf-8"))
        with open(agent, encoding="utf-8") as fh:
            self.assertTrue(fh.read().endswith("custom\n"))

    def test_uninstall_is_clean(self):
        r = run([os.path.join(REPO, "adapters", "claude", "alp.py"), "uninstall", "--dir", self.root], self.root)
        self.assertEqual(r.returncode, 0, r.stderr)
        left = sorted(x for x in os.listdir(self.root) if x != ".git")
        self.assertEqual(left, [], left)

    def test_uninstall_keeps_customized(self):
        with open(self.p("ALP.md"), "a", encoding="utf-8") as fh:
            fh.write("\n## Contract thật\n")
        with open(self.p(".alp", "agents", "lead", "AGENT.md"), "a", encoding="utf-8") as fh:
            fh.write("\ncustom\n")
        r = run([ADAPTER, "uninstall", "--dir", self.root], self.root)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(os.path.isfile(self.p("ALP.md")))
        self.assertTrue(os.path.isfile(self.p(".alp", "agents", "lead", "AGENT.md")))
        self.assertFalse(os.path.exists(self.p(".claude", "agents")))


class ReviewFixesTest(Installed):
    """Các lỗi review PR #22 tìm ra."""

    def settings(self):
        return json.loads(read(self.p(".claude", "settings.json")))

    def test_hooks_registered_on_demand(self):
        write(self.p(".alp", "agents", "peer", "hooks", "PostToolUse.py"), "import sys\nsys.stdin.read()\n")
        r = self.hook("SessionStart", {})
        self.assertIn("settings.json:hooks", r.stdout.decode("utf-8"))
        st = self.settings()
        self.assertEqual(st["hooks"]["PostToolUse"][0]["matcher"], "*")
        self.assertNotIn("Stop", st["hooks"])
        os.remove(self.p(".alp", "agents", "peer", "hooks", "PostToolUse.py"))
        self.hook("SessionStart", {})
        self.assertNotIn("PostToolUse", self.settings()["hooks"])

    @unittest.skipIf(os.name == "nt", "lệnh hook chạy bằng sh của Claude Code; POSIX đủ để kiểm")
    def test_hook_command_fails_open_when_adapter_missing(self):
        cmd = self.settings()["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
        os.remove(self.p(".claude", "slp", "alp.py"))
        r = subprocess.run(["sh", "-c", cmd], input=b"{}", capture_output=True,
                           env=dict(ENV, CLAUDE_PROJECT_DIR=self.root))
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_force_uninstall_without_manifest_strips_hooks(self):
        os.remove(self.p(".claude", "slp-manifest.json"))
        r = run([ADAPTER, "uninstall", "--dir", self.root, "--force"], self.root)
        self.assertEqual(r.returncode, 0, r.stderr)
        st = self.settings()  # không manifest → không biết SLP tạo file, nhưng hook + agent phải đi
        self.assertNotIn("hooks", st)
        self.assertNotIn("agent", st)

    def test_user_hook_in_same_entry_survives(self):
        st = self.settings()
        st["hooks"]["PreToolUse"][0]["hooks"].append({"type": "command", "command": "echo mine"})
        write(self.p(".claude", "settings.json"), json.dumps(st))
        self.assertEqual(self.install().returncode, 0)
        self.assertIn("echo mine", json.dumps(self.settings()["hooks"]))
        run([ADAPTER, "uninstall", "--dir", self.root], self.root)
        self.assertIn("echo mine", json.dumps(self.settings()["hooks"]))
        self.assertNotIn("slp/alp.py", read(self.p(".claude", "settings.json")))

    def test_multiple_seat_hooks_emit_one_json(self):
        hooks = self.p(".alp", "agents", "lead", "hooks")
        write(os.path.join(hooks, "PreToolUse.a.py"),
              "import sys\nsys.stdin.read()\nprint('{\"hookSpecificOutput\": {\"additionalContext\": \"A\"}}')\n")
        write(os.path.join(hooks, "PreToolUse.b.py"),
              "import sys\nsys.stdin.read()\nprint('{\"hookSpecificOutput\": {\"permissionDecision\": \"deny\"}}')\n")
        write(os.path.join(hooks, "PreToolUse.c.py.bak"), "raise SystemExit(2)\n")  # file backup: bỏ qua
        r = self.hook("PreToolUse", {"agent_type": "lead", "tool_name": "Bash", "tool_input": {"command": "ls"}})
        self.assertEqual(r.returncode, 0, r.stderr)
        out = json.loads(r.stdout.decode("utf-8"))  # đúng một object JSON
        self.assertEqual(out["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_identical_user_skill_is_not_adopted(self):
        gen_path = self.p(".claude", "slp", "generated.json")
        gen = json.loads(read(gen_path))
        del gen["skills"]["xia"]  # coi như .claude/skills/xia là của anh, trùng nội dung
        write(gen_path, json.dumps(gen))
        run([ADAPTER, "sync", "--dir", self.root], self.root)
        self.assertNotIn("xia", json.loads(read(gen_path))["skills"])
        run([ADAPTER, "uninstall", "--dir", self.root], self.root)
        self.assertTrue(os.path.isfile(self.p(".claude", "skills", "xia", "SKILL.md")))

    def test_user_agent_choice_is_respected(self):
        st = self.settings()
        st["agent"] = "lead"
        write(self.p(".claude", "settings.json"), json.dumps(st))
        write(self.p(".alp", "settings.json"), json.dumps({"defaultAgent": "peer"}))
        self.hook("SessionStart", {})
        self.assertEqual(self.settings()["agent"], "lead")
        run([ADAPTER, "uninstall", "--dir", self.root], self.root)
        self.assertEqual(self.settings()["agent"], "lead")

    def test_default_agent_follows_alp_settings(self):
        write(self.p(".alp", "settings.json"), json.dumps({"defaultAgent": "lead"}))
        self.hook("SessionStart", {})
        self.assertEqual(self.settings()["agent"], "lead")

    def test_subdirectory_install_uses_template(self):
        write(self.p("ALP.md"), "# contract của repo gốc\n")
        sub = self.p("packages", "api")
        os.makedirs(sub)
        r = run([ADAPTER, "install", "--src", REPO, "--dir", sub], sub)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(read(os.path.join(sub, "ALP.md")), read(os.path.join(REPO, "templates", "ALP.md")))

    def test_dropped_shipped_file_is_removed(self):
        man_path = self.p(".claude", "slp-manifest.json")
        man = json.loads(read(man_path))
        old = self.p(".alp", "agents", "peer", "skills", "retired", "SKILL.md")
        os.makedirs(os.path.dirname(old))
        write(old, "---\nname: retired\ndescription: x\n---\n")
        import hashlib
        with open(old, "rb") as fh:
            man["alp"]["agents/peer/skills/retired/SKILL.md"] = hashlib.sha256(fh.read()).hexdigest()
        write(man_path, json.dumps(man))
        self.assertEqual(self.install().returncode, 0)
        self.assertFalse(os.path.exists(os.path.dirname(old)))
        self.assertFalse(os.path.exists(self.p(".claude", "skills", "retired")))


class LegacyUpgradeTest(unittest.TestCase):
    """Bản ≤ 0.9: agent/skill cài thẳng vào .claude/, manifest schema 1, CLAUDE.md thường."""

    def test_upgrade_from_flat_layout(self):
        root = tempfile.mkdtemp(prefix="alp-legacy-")
        try:
            subprocess.run(["git", "init", "-q", root], check=True)
            c = os.path.join(root, ".claude")
            os.makedirs(os.path.join(c, "agents"))
            os.makedirs(os.path.join(c, "skills", "ask-alp"))
            os.makedirs(os.path.join(c, "skills", "xia"))
            write(os.path.join(c, "agents", "lead.md"), "---\nname: lead\ndescription: old\n---\nold\n")
            write(os.path.join(c, "skills", "ask-alp", "SKILL.md"), "---\nname: ask-alp\ndescription: x\n---\n")
            write(os.path.join(c, "skills", "xia", "SKILL.md"), "---\nname: xia\ndescription: old\n---\n")
            write(os.path.join(root, "CLAUDE.md"), "# Contract cũ\n")
            write(os.path.join(c, "slp-manifest.json"), json.dumps({"schemaVersion": 1, "version": "0.9.0", "agents": ["agents/lead.md"],
                       "skills": ["skills/ask-alp", "skills/xia"], "files": [],
                       "settings": {"created": True, "keys": ["teammateMode"]},
                       "claudeMd": {"created": False, "sha256": ""}}))
            r = run([ADAPTER, "install", "--src", REPO, "--dir", root], root)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertFalse(os.path.exists(os.path.join(c, "skills", "ask-alp")))
            self.assertFalse(os.path.exists(os.path.join(root, "ALP.md")))  # CLAUDE.md cũ giữ làm contract
            self.assertEqual(read(os.path.join(root, "CLAUDE.md")), "# Contract cũ\n")
            self.assertIn("name: lead", read(os.path.join(c, "agents", "lead.md")))
            self.assertNotIn("\nold\n", read(os.path.join(c, "agents", "lead.md")))
            backups = os.listdir(os.path.join(c, "backups"))
            self.assertTrue(os.path.isfile(os.path.join(c, "backups", backups[0], "agents", "lead.md")))
        finally:
            shutil.rmtree(root, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
