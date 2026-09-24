import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";
import {
  buildSystemPrompt,
  familyOf,
  providerOptionsFor,
  readDefinition,
  seatOf,
  stripFrontmatter,
  withLeadAllowedTools,
} from "./seat.ts";

test("seatOf: chỉ hai profile SLP", () => {
  assert.equal(seatOf("claude-lead"), "lead");
  assert.equal(seatOf("claude-peer"), "peer");
  assert.equal(seatOf("claude"), null);
  assert.equal(seatOf("codex"), null);
});

test("stripFrontmatter: bỏ YAML đầu file, giữ thân", () => {
  const md = "---\nname: lead\ntools: Agent(peer)\n---\n# Lead\n\nThân.";
  assert.equal(stripFrontmatter(md), "# Lead\n\nThân.");
  assert.equal(stripFrontmatter("# Không frontmatter\n---\nx"), "# Không frontmatter\n---\nx");
});

test("readDefinition: ưu tiên .claude/agents trong cwd", async () => {
  const cwd = await mkdtemp(path.join(tmpdir(), "slp-paseo-"));
  await mkdir(path.join(cwd, ".claude", "agents"), { recursive: true });
  await writeFile(path.join(cwd, ".claude", "agents", "peer.md"), "---\nname: peer\n---\nPEER BODY\n");
  const def = await readDefinition(cwd, "peer");
  assert.ok(def);
  assert.equal(def.body, "PEER BODY");
  assert.equal(def.path, path.join(cwd, ".claude", "agents", "peer.md"));
});

test("buildSystemPrompt: prompt sẵn có + definition + SLP-RUNTIME đúng ghế", () => {
  const lead = buildSystemPrompt("lead", "BODY", "EXISTING");
  assert.ok(lead.startsWith("EXISTING\n\n# Ghế SLP: lead\n\nBODY"));
  assert.match(lead, /## SLP-RUNTIME: paseo/);
  assert.match(lead, /create_agent/);
  const peer = buildSystemPrompt("peer", "BODY", null);
  assert.ok(peer.startsWith("# Ghế SLP: peer"));
  assert.match(peer, /Runtime: paseo/);
  assert.doesNotMatch(peer, /Spawn peer/);
});

test("withLeadAllowedTools: thêm wildcard, giữ tool cũ, không trùng", () => {
  assert.deepEqual(withLeadAllowedTools(undefined), { allowedTools: ["mcp__paseo__*"] });
  const merged = withLeadAllowedTools({ allowedTools: ["Bash", "mcp__paseo__*"], model: "x" });
  assert.deepEqual(merged, { allowedTools: ["Bash", "mcp__paseo__*"], model: "x" });
});

test("supervisor: seat, disallowedTools ghi/spawn, runtime block đúng ghế", () => {
  assert.equal(seatOf("claude-supervisor"), "supervisor");
  const opts = providerOptionsFor("supervisor", "claude", { disallowedTools: ["WebSearch"] });
  assert.deepEqual(opts, {
    allowedTools: ["mcp__paseo__*"],
    disallowedTools: ["WebSearch", "Write", "Edit", "MultiEdit", "NotebookEdit", "Agent", "Task"],
  });
  const prompt = buildSystemPrompt("supervisor", "BODY", null);
  assert.match(prompt, /Không bao giờ.*send_agent_prompt.*tới peer/);
  assert.match(prompt, /D15 trên Paseo/);
  assert.doesNotMatch(prompt, /Spawn peer/);
});

test("providerOptionsFor: peer giữ nguyên tham chiếu", () => {
  const opts = { allowedTools: ["Bash"] };
  assert.equal(providerOptionsFor("peer", "claude", opts), opts);
  assert.equal(providerOptionsFor("peer", "claude", undefined), undefined);
});

test("codex: profile codex-* đúng ghế/họ; supervisor sandbox workspace-write, lead/peer không đổi", () => {
  assert.equal(seatOf("codex-lead"), "lead");
  assert.equal(seatOf("codex-supervisor"), "supervisor");
  assert.equal(familyOf("codex-peer"), "codex");
  assert.equal(familyOf("claude-peer"), "claude");
  assert.equal(familyOf("codex"), null);
  assert.deepEqual(providerOptionsFor("supervisor", "codex", { approval_policy: "never" }), {
    approval_policy: "never",
    sandbox_mode: "workspace-write",
  });
  const opts = { approval_policy: "on-request" };
  assert.equal(providerOptionsFor("lead", "codex", opts), opts);
  assert.equal(providerOptionsFor("peer", "codex", undefined), undefined);
});
