import type { PluginBeforeRequests } from "@getpaseo/plugin/server";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import { runtimeBlock } from "./runtime-block.ts";

export type Seat = "lead" | "peer" | "supervisor";
/** providerOptions của agent config (Record<string, JsonValue>), lấy từ type hook để không thêm dep. */
export type ProviderOptions = PluginBeforeRequests["agent.create"]["config"]["providerOptions"];

/** Provider profile (extends: claude, khai trong ~/.paseo/config.json) → ghế SLP. */
const SEAT_BY_PROVIDER: Record<string, Seat> = {
  "claude-lead": "lead",
  "claude-peer": "peer",
  "claude-supervisor": "supervisor",
};

/** Tool Paseo Lead được gọi không cần hỏi; wildcard là cú pháp allowedTools của Claude Code. */
export const LEAD_ALLOWED_TOOLS = ["mcp__paseo__*"] as const;

/**
 * Supervisor: bất biến 1 và 6 — không viết code, không spawn. Tool Paseo của nó bị cắt ở profile
 * (`paseoTools.disabledTools`, chỉ còn list/get/send); phía Claude cắt ở đây. Bash vẫn có để đọc Git
 * và ghi memory trong cwd (sandbox qua `.claude/settings.json` của cwd Supervisor).
 */
export const SUPERVISOR_DISALLOWED_TOOLS = [
  "Write",
  "Edit",
  "MultiEdit",
  "NotebookEdit",
  "Agent",
  "Task",
] as const;

export function seatOf(provider: string): Seat | null {
  return SEAT_BY_PROVIDER[provider] ?? null;
}

/** Bỏ YAML frontmatter (`---` … `---`) của agent definition; giữ nguyên phần thân. */
export function stripFrontmatter(text: string): string {
  const match = /^---\r?\n[\s\S]*?\r?\n---\r?\n?/.exec(text);
  return match ? text.slice(match[0].length) : text;
}

export interface Definition {
  path: string;
  body: string;
}

/** Tìm `.claude/agents/<seat>.md` trong cwd của agent trước, rồi bản global `~/.claude/agents/`. */
export async function readDefinition(cwd: string, seat: Seat): Promise<Definition | null> {
  const candidates = [
    path.join(cwd, ".claude", "agents", `${seat}.md`),
    path.join(homedir(), ".claude", "agents", `${seat}.md`),
  ];
  for (const file of candidates) {
    try {
      const text = await readFile(file, "utf8");
      return { path: file, body: stripFrontmatter(text).trim() };
    } catch {
      // thử ứng viên kế
    }
  }
  return null;
}

/** System prompt của ghế = prompt sẵn có (nếu Human/SDK đặt) + definition + khối SLP-RUNTIME. */
export function buildSystemPrompt(
  seat: Seat,
  definitionBody: string,
  existing: string | null | undefined,
): string {
  const parts = [existing?.trim(), `# Ghế SLP: ${seat}\n\n${definitionBody}`, runtimeBlock(seat)];
  return parts.filter((part): part is string => Boolean(part)).join("\n\n");
}

function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((t): t is string => typeof t === "string") : [];
}

/** Thêm wildcard tool Paseo vào allowedTools của providerOptions (Claude), không trùng. */
export function withLeadAllowedTools(providerOptions: ProviderOptions): NonNullable<ProviderOptions> {
  const current = stringList(providerOptions?.allowedTools);
  return { ...(providerOptions ?? {}), allowedTools: [...new Set([...current, ...LEAD_ALLOWED_TOOLS])] };
}

/**
 * Supervisor: cắt tool ghi/spawn phía Claude, giữ disallowedTools sẵn có; tool Paseo còn lại (đã
 * cắt ở profile) gọi không cần hỏi — cùng lý do với Lead (card bị steer huỷ).
 */
export function withSupervisorTools(providerOptions: ProviderOptions): NonNullable<ProviderOptions> {
  const current = stringList(providerOptions?.disallowedTools);
  return {
    ...withLeadAllowedTools(providerOptions),
    disallowedTools: [...new Set([...current, ...SUPERVISOR_DISALLOWED_TOOLS])],
  };
}

/** providerOptions theo ghế; peer không đổi gì (ranh giới peer nằm ở profile). */
export function providerOptionsFor(seat: Seat, providerOptions: ProviderOptions): ProviderOptions {
  switch (seat) {
    case "lead":
      return withLeadAllowedTools(providerOptions);
    case "supervisor":
      return withSupervisorTools(providerOptions);
    default:
      return providerOptions;
  }
}
