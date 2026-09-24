import assert from "node:assert/strict";
import { test } from "node:test";
import {
  counterpartSeat,
  formatRoster,
  leadAnnouncement,
  selectSeatAgents,
  supervisorsRegisteredIn,
} from "./discovery.ts";

const entries = [
  { agent: { id: "L1", provider: "claude-lead", cwd: "/r/a", status: "idle", title: "lead-a" } },
  { agent: { id: "L2", provider: "claude-lead", cwd: "/r/b", status: "running", title: null, archivedAt: "2026-09-24" } },
  { agent: { id: "L3", provider: "claude-lead", cwd: "/r/c", status: "closed" } },
  { agent: { id: "S1", provider: "claude-supervisor", cwd: "/sup", status: "idle", title: "sup" } },
  { agent: { id: "P1", provider: "claude-peer", cwd: "/r/a/wt", status: "running" } },
  { agent: { id: "X1", provider: "claude", cwd: "/x", status: "idle" } },
];

test("selectSeatAgents: đúng ghế, bỏ archive/closed/chính mình", () => {
  assert.deepEqual(selectSeatAgents(entries, "lead").map((a) => a.id), ["L1"]);
  assert.deepEqual(selectSeatAgents(entries, "supervisor").map((a) => a.id), ["S1"]);
  assert.deepEqual(selectSeatAgents(entries, "lead", "L1"), []);
});

test("counterpartSeat: lead↔supervisor, peer không có", () => {
  assert.equal(counterpartSeat("lead"), "supervisor");
  assert.equal(counterpartSeat("supervisor"), "lead");
  assert.equal(counterpartSeat("peer"), null);
});

test("formatRoster: trống khi không có ai, có id/cwd/status khi có", () => {
  assert.equal(formatRoster("lead", []), "");
  const text = formatRoster("supervisor", selectSeatAgents(entries, "supervisor"));
  assert.match(text, /^## Supervisor hiện có/);
  assert.match(text, /`S1`.*`\/sup`.*status idle/);
  assert.match(text, /get_agent_status/);
});

test("supervisorsRegisteredIn: chỉ tính tool_call send_agent_prompt tới đúng id, không dò chuỗi", () => {
  const call = (name: string, input: unknown, error: unknown = null) => ({
    type: "tool_call",
    callId: "x",
    name,
    detail: { type: "unknown", input, output: { hint: "use send_agent_prompt", agentId: "S2" } },
    status: "completed",
    error,
  });
  const timeline = [
    call("ToolSearch", { query: "select:mcp__paseo__send_agent_prompt" }),
    call("mcp__paseo__get_agent_status", { agentId: "S1" }),
    { type: "assistant_message", text: 'Sẽ send_agent_prompt {"agentId":"S2"} sau.' },
    call("mcp__paseo__send_agent_prompt", { agentId: "S1", prompt: "SLP-REGISTER …" }),
    call("mcp__paseo__send_agent_prompt", { agentId: "S3" }, { message: "not found" }),
  ];
  assert.deepEqual([...supervisorsRegisteredIn(timeline, ["S1", "S2", "S3"])], ["S1"]);
  assert.equal(supervisorsRegisteredIn(undefined, ["S1"]).size, 0);
});

test("leadAnnouncement: có id, Root, ghi rõ không phải Human", () => {
  const text = leadAnnouncement({ id: "L9", seat: "lead", title: "lead-x", cwd: "/r/x", status: "idle" });
  assert.match(text, /\[plugin slp-paseo\] Lead mới/);
  assert.match(text, /`L9`.*Root `\/r\/x`/);
  assert.match(text, /không phải Human/);
});
