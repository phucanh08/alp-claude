import type { PluginServerContext } from "@getpaseo/plugin/server";
import {
  counterpartSeat,
  findSeatAgents,
  formatRoster,
  leadAnnouncement,
  supervisorsRegisteredIn,
  type SeatAgent,
} from "./server/discovery.ts";
import { buildSystemPrompt, familyOf, providerOptionsFor, readDefinition, seatOf } from "./server/seat.ts";

/**
 * slp-paseo — đưa SLP (Supervisor/Lead/Peer) lên Paseo mà không cần fork.
 *
 * 1. `agent.create`: agent tạo bằng provider `<họ>-<ghế>` (họ claude|codex; ghế lead|peer|supervisor)
 *    nhận system prompt = `.claude/agents/<ghế>.md` + khối SLP-RUNTIME + roster ghế đối ứng đang sống
 *    trên host (Lead thấy Supervisor, Supervisor thấy Lead) — Human không phải đưa id.
 *    Claude: Lead/Supervisor thêm `allowedTools: mcp__paseo__*` để card permission tool Paseo không
 *    bao giờ hiện (Lab 12 M7); Supervisor bị cắt `Write`/`Edit`/`Agent`/`Task`.
 *    Codex: Supervisor chạy sandbox `workspace-write` (chỉ ghi trong cwd trung lập của nó).
 * 2. `agent.turn_ended` của Lead (lượt đầu): Lead đã gửi SLP-REGISTER cho Supervisor nào (thấy trong
 *    timeline) thì thôi; Supervisor còn lại đang idle → nhắn một dòng thông tin; đang chạy → xếp hàng,
 *    gửi khi lượt của Supervisor đó kết thúc. Báo lúc Lead **kết thúc lượt** chứ không lúc tạo, vì
 *    báo lúc tạo làm Supervisor bận đúng lúc Lead kiểm `get_agent_status` → hai bên cùng hoãn, không
 *    ai có cò để tiếp (đo 24/9/2026, issue #16). Plugin đưa thông tin, không cấp authority.
 * 3. `agent.permission_requested`: lưới an toàn — card tool Paseo của Lead/Supervisor (Claude) vẫn
 *    hiện thì allow.
 *
 * Ranh giới tool Paseo của Peer/Supervisor (`paseoTools.disabledTools`) và `disallowedTools` của Peer
 * vẫn nằm ở provider profile trong ~/.paseo/config.json (docs/PASEO.md §2).
 */
export default function contribute(server: PluginServerContext) {
  /** Lead đã qua lượt đầu (đã xét báo Supervisor). */
  const announcedLeads = new Set<string>();
  /** Supervisor đang chạy lúc Lead kết thúc lượt đầu → báo khi lượt của nó kết thúc. */
  const pendingBySupervisor = new Map<string, SeatAgent[]>();

  const removeCreate = server.before("agent.create", async ({ request }, context) => {
    const seat = seatOf(request.config.provider);
    const family = familyOf(request.config.provider);
    if (!seat || !family) return;
    const definition = await readDefinition(request.config.cwd, seat);
    if (!definition) {
      console.error(`slp-paseo: không thấy .claude/agents/${seat}.md trong ${request.config.cwd} hay ~/.claude — bỏ qua`);
      return;
    }
    let roster = "";
    const other = counterpartSeat(seat);
    if (other) {
      try {
        roster = formatRoster(other, await findSeatAgents(context.paseo, other));
      } catch (error) {
        console.error(`slp-paseo: không liệt kê được agent ${other}: ${String(error)}`);
      }
    }
    const providerOptions = providerOptionsFor(seat, family, request.config.providerOptions);
    const systemPrompt = [buildSystemPrompt(seat, definition.body, request.config.systemPrompt), roster]
      .filter(Boolean)
      .join("\n\n");
    const config = {
      ...request.config,
      systemPrompt,
      ...(providerOptions === request.config.providerOptions ? {} : { providerOptions }),
    };
    console.log(
      `slp-paseo: ${seat}/${family} ← ${definition.path}` +
        (roster ? ` (+roster ${other})` : "") +
        (providerOptions === request.config.providerOptions ? "" : ` (providerOptions: ${JSON.stringify(providerOptions)})`),
    );
    return { ...request, config };
  });

  const removeTurnEnded = server.on("agent.turn_ended", async (event, context) => {
    const seat = seatOf(event.agent.provider);
    if (seat === "supervisor") {
      const pending = pendingBySupervisor.get(event.agent.id);
      if (!pending?.length) return;
      pendingBySupervisor.delete(event.agent.id);
      for (const lead of pending) {
        await context.paseo.agents.ref(event.agent.id).send(leadAnnouncement(lead));
        console.log(`slp-paseo: supervisor ${event.agent.id} vừa xong lượt → báo lead ${lead.id} đang chờ`);
      }
      return;
    }
    if (seat !== "lead" || announcedLeads.has(event.agent.id)) return;
    announcedLeads.add(event.agent.id);
    const supervisors = await findSeatAgents(context.paseo, "supervisor", event.agent.id);
    if (supervisors.length === 0) return;
    const registered = supervisorsRegisteredIn(event.timeline, supervisors.map((s) => s.id));
    const lead: SeatAgent = { id: event.agent.id, seat: "lead", title: event.agent.title, cwd: event.agent.cwd, status: "idle" };
    for (const sup of supervisors) {
      if (registered.has(sup.id)) {
        console.log(`slp-paseo: lead ${lead.id} đã tự gửi SLP-REGISTER cho supervisor ${sup.id}`);
        continue;
      }
      if (sup.status !== "idle") {
        pendingBySupervisor.set(sup.id, [...(pendingBySupervisor.get(sup.id) ?? []), lead]);
        console.log(`slp-paseo: supervisor ${sup.id} đang ${sup.status} → báo lead ${lead.id} khi nó xong lượt`);
        continue;
      }
      await context.paseo.agents.ref(sup.id).send(leadAnnouncement(lead));
      console.log(`slp-paseo: báo supervisor ${sup.id} có lead mới ${lead.id} (chưa đăng ký)`);
    }
  });

  const removePermission = server.on("agent.permission_requested", async (event, context) => {
    const seat = seatOf(event.agent.provider);
    if (seat !== "lead" && seat !== "supervisor") return;
    if (event.request.kind !== "tool" || !event.request.name.startsWith("mcp__paseo__")) return;
    await context.paseo.agents.ref(event.agent.id).respondToPermission({
      requestId: event.request.id,
      response: { behavior: "allow" },
    });
    console.log(`slp-paseo: allow ${event.request.name} cho ${seat} ${event.agent.id}`);
  });

  return () => {
    removeCreate();
    removeTurnEnded();
    removePermission();
  };
}
