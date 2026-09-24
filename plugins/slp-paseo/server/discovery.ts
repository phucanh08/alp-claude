import type { PluginHookContext } from "@getpaseo/plugin/server";
import { seatOf, type Seat } from "./seat.ts";

type PaseoApi = PluginHookContext["paseo"];

/** Agent cùng host, rút gọn cho roster trong system prompt. */
export interface SeatAgent {
  id: string;
  seat: Seat;
  title: string | null;
  cwd: string;
  status: string;
}

/** Hình dạng tối thiểu của một entry `agents.list()`; giữ hẹp để test không cần SDK. */
export interface AgentEntryLike {
  agent: {
    id: string;
    provider: string;
    cwd: string;
    status: string;
    title?: string | null;
    archivedAt?: string | null;
  };
}

/** Lọc entry theo ghế: đúng provider SLP, chưa archive, chưa đóng; loại chính agent đang tạo. */
export function selectSeatAgents(entries: AgentEntryLike[], seat: Seat, excludeId?: string): SeatAgent[] {
  const out: SeatAgent[] = [];
  for (const { agent } of entries) {
    if (agent.id === excludeId || agent.archivedAt || agent.status === "closed") continue;
    if (seatOf(agent.provider) !== seat) continue;
    out.push({ id: agent.id, seat, title: agent.title ?? null, cwd: agent.cwd, status: agent.status });
  }
  return out;
}

/** Ghế đối ứng cần biết nhau: Lead ↔ Supervisor. Peer không có roster. */
export function counterpartSeat(seat: Seat): Seat | null {
  return seat === "lead" ? "supervisor" : seat === "supervisor" ? "lead" : null;
}

export async function findSeatAgents(paseo: PaseoApi, seat: Seat, excludeId?: string): Promise<SeatAgent[]> {
  const page = await paseo.agents.list({ filter: { includeArchived: false }, page: { limit: 200 } });
  return selectSeatAgents(page.entries, seat, excludeId);
}

/** Khối roster nối vào cuối system prompt; trống nếu không có ai. */
export function formatRoster(seat: Seat, agents: SeatAgent[]): string {
  if (agents.length === 0) return "";
  const title = seat === "supervisor" ? "Supervisor hiện có" : "Lead hiện có";
  const rows = agents.map(
    (a) => `- id \`${a.id}\` · title \`${a.title ?? "-"}\` · cwd \`${a.cwd}\` · status ${a.status} (lúc bạn được tạo)`,
  );
  return `## ${title} (plugin slp-paseo liệt kê lúc tạo bạn)\n${rows.join("\n")}\nTrạng thái ở trên là ảnh chụp; kiểm lại bằng \`get_agent_status\` trước khi nhắn.`;
}

/**
 * Supervisor nào đã được Lead `send_agent_prompt` (theo timeline của `agent.turn_ended` — đó là toàn
 * bộ hội thoại tới lúc đó). Chỉ tính item `tool_call` tên `…send_agent_prompt` có `detail.input.agentId`
 * = Supervisor và không lỗi. Không dò chuỗi: output của `get_agent_status`/`ToolSearch` cũng chứa chữ
 * `send_agent_prompt` (dương tính giả đo 24/9/2026).
 */
export function supervisorsRegisteredIn(timeline: unknown, supervisorIds: string[]): Set<string> {
  const found = new Set<string>();
  if (!Array.isArray(timeline)) return found;
  for (const item of timeline) {
    if (!item || typeof item !== "object") continue;
    const { type, name, detail, error } = item as { type?: unknown; name?: unknown; detail?: unknown; error?: unknown };
    if (type !== "tool_call" || typeof name !== "string" || !name.endsWith("send_agent_prompt") || error) continue;
    const input = (detail as { input?: { agentId?: unknown } } | undefined)?.input;
    const target = input?.agentId;
    if (typeof target === "string" && supervisorIds.includes(target)) found.add(target);
  }
  return found;
}

/**
 * Tin plugin gửi Supervisor khi Lead mới vừa kết thúc lượt đầu mà chưa đăng ký (Lead lúc đó idle).
 * Chỉ thông tin, không authority.
 */
export function leadAnnouncement(lead: SeatAgent): string {
  return `[plugin slp-paseo] Lead mới trên host: id \`${lead.id}\` · title \`${lead.title ?? "-"}\` · Root \`${lead.cwd}\`. Lead vừa kết thúc lượt đầu mà chưa gửi SLP-REGISTER (lúc đó bạn đang chạy) — nó không tự thử lại; kiểm \`get_agent_status\`, idle thì mở phiên ngay bằng \`send_agent_prompt\`. Tin này từ plugin, không phải Human.`;
}
