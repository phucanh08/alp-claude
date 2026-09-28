#!/usr/bin/env python3
"""slp-mail — hộp thư chung cho các ghế SLP (Human / Supervisor / Lead / Peer).

Một file, không phụ thuộc ngoài stdlib. Hai mặt:

  * MCP server (stdio):   python3 slp_mail.py serve
  * CLI cho Human/lab:    python3 slp_mail.py send|inbox|ack|log|whoami|mcp-config|selftest

Danh tính người gửi lấy từ biến môi trường SLP_SEAT của *process* chạy server — agent không tự
khai được. Teammate chạy trong process của Lead có thể khai thêm `agent`, ghi thành `lead/<agent>`;
phần trước dấu `/` là phần đã kiểm chứng, phần sau là tự khai trong vùng tin cậy của Lead.

Luật cc: tin gửi tới mailbox dạng `<lead>/<peer>` từ seat khác `<lead>` → server tự cc `<lead>`.
Can thiệp vào Peer từ ngoài team luôn quay về trạng thái chung của Lead.

Lưu trữ: một file `log.jsonl` append-only (nguồn sự thật, ai cũng đọc được) + `acks/<mailbox>.txt`.
"""
import fcntl
import json
import os
import re
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

VERSION = "0.1.0"
SEAT_RE = re.compile(r"^[a-z][a-z0-9-]*$")
NAME_RE = re.compile(r"^[a-z][a-z0-9-]*(/[a-z][a-z0-9-]*)?$")
KINDS = ["message", "heartbeat", "ping", "brief", "handoff", "verdict", "ruling",
         "drift", "escalate", "note", "register", "request"]


# ----------------------------------------------------------------------------- storage

def mail_dir() -> Path:
    d = os.environ.get("SLP_MAIL_DIR")
    if not d:
        ws = os.environ.get("SLP_WORKSPACE", "default")
        d = os.path.join(os.path.expanduser("~"), ".slp-mail", ws)
    p = Path(d)
    (p / "acks").mkdir(parents=True, exist_ok=True)
    return p


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def append_line(path: Path, line: str) -> None:
    with open(path, "a", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write(line + "\n")
        f.flush()
        fcntl.flock(f, fcntl.LOCK_UN)


def read_log(d: Path):
    p = d / "log.jsonl"
    if not p.exists():
        return []
    out = []
    with open(p, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if ln:
                try:
                    out.append(json.loads(ln))
                except json.JSONDecodeError:
                    continue
    return out


def read_acks(d: Path, mailbox: str) -> set:
    p = d / "acks" / (mailbox.replace("/", "__") + ".txt")
    if not p.exists():
        return set()
    return {ln.strip() for ln in p.read_text(encoding="utf-8").splitlines() if ln.strip()}


# ----------------------------------------------------------------------------- identity

def seat() -> str:
    s = os.environ.get("SLP_SEAT", "")
    if not SEAT_RE.match(s):
        raise ValueError("SLP_SEAT chưa đặt hoặc sai dạng ([a-z][a-z0-9-]*); server không gửi được. "
                         "Đặt trong env của .mcp.json (xem `mcp-config`).")
    return s


def owner_of(mailbox: str):
    return mailbox.split("/", 1)[0] if "/" in mailbox else None


def owns(s: str, mailbox: str) -> bool:
    return mailbox == s or mailbox.startswith(s + "/")


# ----------------------------------------------------------------------------- operations

def op_send(to: str, body: str, kind: str = "message", cc=None, agent: str = None):
    s = seat()
    if not NAME_RE.match(to or ""):
        raise ValueError(f"to sai dạng: {to!r} (vd. lead, supervisor, human, lead/peer-a)")
    if not body or not body.strip():
        raise ValueError("body rỗng")
    kind = kind or "message"
    if agent is not None:
        if not SEAT_RE.match(agent):
            raise ValueError(f"agent sai dạng: {agent!r}")
        sender = f"{s}/{agent}"
    else:
        sender = s
    cc = list(cc or [])
    for c in cc:
        if not NAME_RE.match(c):
            raise ValueError(f"cc sai dạng: {c!r}")
    auto_cc = []
    owner = owner_of(to)
    if owner and owner != s and owner not in cc:
        cc.append(owner)
        auto_cc.append(owner)
    msg = {
        "id": uuid.uuid4().hex[:12],
        "ts": now_iso(),
        "from": sender,
        "seat": s,
        "to": to,
        "cc": cc,
        "auto_cc": auto_cc,
        "kind": kind,
        "body": body,
    }
    d = mail_dir()
    append_line(d / "log.jsonl", json.dumps(msg, ensure_ascii=False))
    return msg


def op_inbox(mailbox: str = None, unread_only: bool = True, since: str = None, limit: int = 50):
    d = mail_dir()
    mb = mailbox or seat()
    acks = read_acks(d, mb)
    out = []
    for m in read_log(d):
        if m.get("to") != mb and mb not in m.get("cc", []):
            continue
        if since and m.get("ts", "") < since:
            continue
        m = dict(m)
        m["read"] = m["id"] in acks
        m["role"] = "to" if m["to"] == mb else "cc"
        if unread_only and m["read"]:
            continue
        out.append(m)
    return {"mailbox": mb, "unread": sum(1 for m in out if not m["read"]), "messages": out[-limit:]}


def op_ack(ids, mailbox: str = None):
    s = seat()
    mb = mailbox or s
    if not owns(s, mb):
        raise ValueError(f"{s} không sở hữu mailbox {mb}; chỉ ack được {s} hoặc {s}/<agent>")
    d = mail_dir()
    known = {m["id"] for m in read_log(d)}
    acked = []
    p = d / "acks" / (mb.replace("/", "__") + ".txt")
    for i in ids or []:
        if i in known:
            append_line(p, i)
            acked.append(i)
    return {"mailbox": mb, "acked": acked, "unknown": [i for i in (ids or []) if i not in known]}


def op_log(since: str = None, frm: str = None, to: str = None, kind: str = None, limit: int = 50):
    out = []
    for m in read_log(mail_dir()):
        if since and m.get("ts", "") < since:
            continue
        if frm and not (m.get("from") == frm or m.get("seat") == frm):
            continue
        if to and not (m.get("to") == to or to in m.get("cc", [])):
            continue
        if kind and m.get("kind") != kind:
            continue
        out.append(m)
    return {"count": len(out), "messages": out[-limit:]}


def op_whoami():
    try:
        s = seat()
    except ValueError as e:
        s = None
    d = mail_dir()
    return {"seat": s, "dir": str(d), "workspace": os.environ.get("SLP_WORKSPACE", "default"),
            "version": VERSION}


# ----------------------------------------------------------------------------- MCP

TOOLS = [
    {"name": "send",
     "description": "Gửi một tin vào hộp thư chung. `from` do server gán từ SLP_SEAT của process; "
                    "teammate của Lead khai `agent` để ghi thành lead/<agent>. Gửi tới `<lead>/<peer>` "
                    "từ seat khác lead đó thì server tự cc lead.",
     "inputSchema": {"type": "object", "required": ["to", "body"], "properties": {
         "to": {"type": "string", "description": "mailbox nhận: lead | supervisor | human | lead/peer-a"},
         "body": {"type": "string"},
         "kind": {"type": "string", "enum": KINDS, "default": "message"},
         "cc": {"type": "array", "items": {"type": "string"}},
         "agent": {"type": "string", "description": "tên teammate khi gửi từ process của Lead"}}}},
    {"name": "inbox",
     "description": "Đọc hộp thư (mặc định của chính seat). Đọc mailbox khác được — log là evidence chung.",
     "inputSchema": {"type": "object", "properties": {
         "mailbox": {"type": "string"},
         "unread_only": {"type": "boolean", "default": True},
         "since": {"type": "string", "description": "ISO-8601"},
         "limit": {"type": "integer", "default": 50}}}},
    {"name": "ack",
     "description": "Đánh dấu đã đọc. Chỉ ack được mailbox của seat mình hoặc <seat>/<agent>.",
     "inputSchema": {"type": "object", "required": ["ids"], "properties": {
         "ids": {"type": "array", "items": {"type": "string"}},
         "mailbox": {"type": "string"}}}},
    {"name": "log",
     "description": "Truy vấn log chung: since / from / to / kind / limit.",
     "inputSchema": {"type": "object", "properties": {
         "since": {"type": "string"}, "from": {"type": "string"}, "to": {"type": "string"},
         "kind": {"type": "string"}, "limit": {"type": "integer", "default": 50}}}},
    {"name": "whoami",
     "description": "Seat của process này, thư mục log, workspace.",
     "inputSchema": {"type": "object", "properties": {}}},
]


def call_tool(name: str, args: dict):
    args = args or {}
    if name == "send":
        return op_send(args.get("to"), args.get("body"), args.get("kind", "message"),
                       args.get("cc"), args.get("agent"))
    if name == "inbox":
        return op_inbox(args.get("mailbox"), args.get("unread_only", True), args.get("since"),
                        int(args.get("limit", 50)))
    if name == "ack":
        return op_ack(args.get("ids"), args.get("mailbox"))
    if name == "log":
        return op_log(args.get("since"), args.get("from"), args.get("to"), args.get("kind"),
                      int(args.get("limit", 50)))
    if name == "whoami":
        return op_whoami()
    raise ValueError(f"tool không tồn tại: {name}")


def serve():
    out = sys.stdout

    def reply(obj):
        out.write(json.dumps(obj, ensure_ascii=False) + "\n")
        out.flush()

    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        try:
            req = json.loads(raw)
        except json.JSONDecodeError:
            continue
        rid = req.get("id")
        method = req.get("method", "")
        params = req.get("params") or {}
        if rid is None:  # notification
            continue
        try:
            if method == "initialize":
                result = {"protocolVersion": params.get("protocolVersion", "2025-06-18"),
                          "capabilities": {"tools": {}},
                          "serverInfo": {"name": "slp-mail", "version": VERSION}}
            elif method == "ping":
                result = {}
            elif method == "tools/list":
                result = {"tools": TOOLS}
            elif method == "tools/call":
                try:
                    data = call_tool(params.get("name"), params.get("arguments"))
                    result = {"content": [{"type": "text", "text": json.dumps(data, ensure_ascii=False)}]}
                except Exception as e:  # tool error → isError, không phải JSON-RPC error
                    result = {"content": [{"type": "text", "text": f"slp-mail: {e}"}], "isError": True}
            else:
                reply({"jsonrpc": "2.0", "id": rid,
                       "error": {"code": -32601, "message": f"method not found: {method}"}})
                continue
            reply({"jsonrpc": "2.0", "id": rid, "result": result})
        except Exception as e:
            reply({"jsonrpc": "2.0", "id": rid, "error": {"code": -32603, "message": str(e)}})


# ----------------------------------------------------------------------------- CLI

def mcp_config(seat_name: str, workspace: str = None) -> dict:
    if not SEAT_RE.match(seat_name):
        raise ValueError("seat sai dạng")
    env = {"SLP_SEAT": seat_name}
    if workspace:
        env["SLP_WORKSPACE"] = workspace
    if os.environ.get("SLP_MAIL_DIR"):
        env["SLP_MAIL_DIR"] = os.environ["SLP_MAIL_DIR"]
    return {"mcpServers": {"slp-mail": {"command": "python3",
                                        "args": [str(Path(__file__).resolve()), "serve"],
                                        "env": env}}}


def cli(argv):
    import argparse
    ap = argparse.ArgumentParser(prog="slp_mail.py", description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("serve", help="MCP server qua stdio")
    p = sub.add_parser("send"); p.add_argument("--to", required=True); p.add_argument("--kind", default="message")
    p.add_argument("--cc", default=""); p.add_argument("--agent"); p.add_argument("body", nargs="+")
    p = sub.add_parser("inbox"); p.add_argument("--mailbox"); p.add_argument("--all", action="store_true")
    p.add_argument("--since")
    p = sub.add_parser("ack"); p.add_argument("--mailbox"); p.add_argument("ids", nargs="+")
    p = sub.add_parser("log"); p.add_argument("--since"); p.add_argument("--from", dest="frm")
    p.add_argument("--to"); p.add_argument("--kind"); p.add_argument("--limit", type=int, default=50)
    p.add_argument("--follow", action="store_true")
    sub.add_parser("whoami")
    p = sub.add_parser("mcp-config", help="in .mcp.json cho một seat"); p.add_argument("seat")
    p.add_argument("--workspace")
    sub.add_parser("selftest")
    a = ap.parse_args(argv)

    if a.cmd == "serve":
        return serve()
    if a.cmd == "selftest":
        return selftest()
    if a.cmd == "mcp-config":
        print(json.dumps(mcp_config(a.seat, a.workspace), indent=2)); return 0
    if a.cmd == "send":
        os.environ.setdefault("SLP_SEAT", "human")
        cc = [c for c in a.cc.split(",") if c]
        m = op_send(a.to, " ".join(a.body), a.kind, cc, a.agent)
        print(json.dumps(m, ensure_ascii=False)); return 0
    if a.cmd == "inbox":
        os.environ.setdefault("SLP_SEAT", "human")
        r = op_inbox(a.mailbox, not a.all, a.since)
        for m in r["messages"]:
            flag = " " if m["read"] else "*"
            print(f"{flag} {m['id']} {m['ts']} {m['from']} → {m['to']} [{m['kind']}] {m['body']}")
        print(f"-- {r['mailbox']}: {r['unread']} chưa đọc"); return 0
    if a.cmd == "ack":
        os.environ.setdefault("SLP_SEAT", "human")
        print(json.dumps(op_ack(a.ids, a.mailbox))); return 0
    if a.cmd == "whoami":
        print(json.dumps(op_whoami(), ensure_ascii=False)); return 0
    if a.cmd == "log":
        seen = set()
        while True:
            r = op_log(a.since, a.frm, a.to, a.kind, a.limit)
            for m in r["messages"]:
                if m["id"] in seen:
                    continue
                seen.add(m["id"])
                cc = f" cc {','.join(m['cc'])}" if m.get("cc") else ""
                print(f"{m['ts']} {m['from']} → {m['to']}{cc} [{m['kind']}] {m['body']}", flush=True)
            if not a.follow:
                return 0
            time.sleep(1)


# ----------------------------------------------------------------------------- selftest

def selftest():
    """Kiểm protocol + luật danh tính + luật cc bằng hai server con (supervisor, lead)."""
    import subprocess
    import tempfile
    here = str(Path(__file__).resolve())
    tmp = tempfile.mkdtemp(prefix="slp-mail-selftest-")
    fails = []

    def check(cond, msg):
        print(("PASS " if cond else "FAIL ") + msg)
        if not cond:
            fails.append(msg)

    class Srv:
        def __init__(self, seat_env):
            env = dict(os.environ, SLP_MAIL_DIR=tmp)
            env.pop("SLP_SEAT", None)
            if seat_env:
                env["SLP_SEAT"] = seat_env
            self.p = subprocess.Popen([sys.executable, here, "serve"], stdin=subprocess.PIPE,
                                      stdout=subprocess.PIPE, text=True, env=env)
            self.n = 0

        def rpc(self, method, params=None):
            self.n += 1
            self.p.stdin.write(json.dumps({"jsonrpc": "2.0", "id": self.n, "method": method,
                                           "params": params or {}}) + "\n")
            self.p.stdin.flush()
            return json.loads(self.p.stdout.readline())

        def call(self, name, **args):
            r = self.rpc("tools/call", {"name": name, "arguments": args})["result"]
            txt = r["content"][0]["text"]
            return (json.loads(txt) if not r.get("isError") else None), r.get("isError", False), txt

        def close(self):
            self.p.stdin.close(); self.p.wait(timeout=5)

    sup = Srv("supervisor"); lead = Srv("lead"); anon = Srv(None)
    try:
        init = sup.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                      "clientInfo": {"name": "selftest", "version": "0"}})
        check(init["result"]["serverInfo"]["name"] == "slp-mail", "initialize trả serverInfo")
        tools = sup.rpc("tools/list")["result"]["tools"]
        check({t["name"] for t in tools} == {"send", "inbox", "ack", "log", "whoami"}, "tools/list đủ 5 tool")

        who, err, _ = sup.call("whoami")
        check(not err and who["seat"] == "supervisor", "whoami lấy seat từ env của process")

        # danh tính: tool không nhận `from`; seat của process là nguồn
        m, err, _ = sup.call("send", to="lead/peer-a", body="Vì sao file evidence đứng 12 phút?", kind="ping")
        check(not err and m["from"] == "supervisor" and m["seat"] == "supervisor", "from do server gán, không do agent khai")
        check(m["cc"] == ["lead"] and m["auto_cc"] == ["lead"], "gửi tới lead/peer-a từ supervisor → tự cc lead")

        # process không có SLP_SEAT không gửi được
        _, err, txt = anon.call("send", to="lead", body="giả mạo")
        check(err and "SLP_SEAT" in txt, "process không có SLP_SEAT bị từ chối send")

        # teammate trong process của lead khai agent → lead/peer-a; gửi cho lead của mình thì không cc
        m2, err, _ = lead.call("send", to="lead", body="HEARTBEAT A2 · 5 phút", kind="heartbeat", agent="peer-a")
        check(not err and m2["from"] == "lead/peer-a" and m2["seat"] == "lead" and m2["cc"] == [],
              "teammate ghi lead/<agent>, seat vẫn là lead, không tự cc")

        # lead gửi cho peer của chính nó: không cc
        m3, err, _ = lead.call("send", to="lead/peer-a", body="brief", kind="brief")
        check(not err and m3["auto_cc"] == [], "lead gửi peer của mình → không cc")

        # inbox của lead thấy tin cc từ supervisor + heartbeat của peer
        ib, err, _ = lead.call("inbox")
        ids = {x["id"]: x for x in ib["messages"]}
        check(m["id"] in ids and ids[m["id"]]["role"] == "cc", "inbox lead có tin cc của supervisor")
        check(m2["id"] in ids and ids[m2["id"]]["role"] == "to", "inbox lead có heartbeat của peer")

        # peer đọc inbox lead/peer-a từ process lead
        ibp, err, _ = lead.call("inbox", mailbox="lead/peer-a")
        check({x["id"] for x in ibp["messages"]} == {m["id"], m3["id"]}, "inbox lead/peer-a có ping + brief")

        # ack: lead ack được lead/peer-a; supervisor không ack được mailbox lead
        ak, err, _ = lead.call("ack", ids=[m["id"], m3["id"]], mailbox="lead/peer-a")
        check(not err and set(ak["acked"]) == {m["id"], m3["id"]}, "lead ack mailbox lead/peer-a")
        ibp2, _, _ = lead.call("inbox", mailbox="lead/peer-a")
        check(ibp2["unread"] == 0, "sau ack, inbox lead/peer-a 0 chưa đọc")
        _, err, txt = sup.call("ack", ids=[m2["id"]], mailbox="lead")
        check(err and "không sở hữu" in txt, "supervisor không ack được mailbox lead")

        # log truy vấn
        lg, err, _ = sup.call("log", **{"from": "supervisor"})
        check(not err and lg["count"] == 1, "log lọc theo from")
        lg2, _, _ = sup.call("log", to="lead")
        check(lg2["count"] == 2, "log lọc theo to gồm cả cc (heartbeat to=lead + ping cc=lead; brief tới lead/peer-a không tính)")

        # method lạ → JSON-RPC error, server không chết
        e = sup.rpc("nope/x")
        check("error" in e and e["error"]["code"] == -32601, "method lạ trả -32601")
        check(sup.rpc("ping")["result"] == {}, "ping sau lỗi vẫn sống")
    finally:
        for s in (sup, lead, anon):
            s.close()

    print(f"\n{'PASS' if not fails else 'FAIL'} selftest — log tại {tmp}")
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(cli(sys.argv[1:]) or 0)
