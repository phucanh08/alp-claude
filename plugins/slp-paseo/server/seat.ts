import type { PluginBeforeRequests } from "@getpaseo/plugin/server";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import { runtimeBlock } from "./runtime-block.ts";

export type Seat = "lead" | "peer";
/** providerOptions của agent config (Record<string, JsonValue>), lấy từ type hook để không thêm dep. */
export type ProviderOptions = PluginBeforeRequests["agent.create"]["config"]["providerOptions"];

/** Provider profile (extends: claude, khai trong ~/.paseo/config.json) → ghế SLP. */
const SEAT_BY_PROVIDER: Record<string, Seat> = {
  "claude-lead": "lead",
  "claude-peer": "peer",
};

/** Tool Paseo Lead được gọi không cần hỏi; wildcard là cú pháp allowedTools của Claude Code. */
export const LEAD_ALLOWED_TOOLS = ["mcp__paseo__*"] as const;

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

/** Thêm wildcard tool Paseo vào allowedTools của providerOptions (Claude), không trùng. */
export function withLeadAllowedTools(providerOptions: ProviderOptions): NonNullable<ProviderOptions> {
  const raw = providerOptions?.allowedTools;
  const current = Array.isArray(raw) ? raw.filter((t): t is string => typeof t === "string") : [];
  return { ...(providerOptions ?? {}), allowedTools: [...new Set([...current, ...LEAD_ALLOWED_TOOLS])] };
}
