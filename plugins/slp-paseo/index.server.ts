import type { PluginServerContext } from "@getpaseo/plugin/server";
import { buildSystemPrompt, providerOptionsFor, readDefinition, seatOf } from "./server/seat.ts";

/**
 * slp-paseo — đưa SLP (Supervisor/Lead/Peer) lên Paseo mà không cần fork.
 *
 * 1. `agent.create`: agent tạo bằng provider `claude-lead`/`claude-peer`/`claude-supervisor` nhận
 *    system prompt = `.claude/agents/<ghế>.md` + khối SLP-RUNTIME (thay cho `claude --agent <ghế>`
 *    của bản native). Lead thêm `allowedTools: mcp__paseo__*` để card permission của Lead không bao
 *    giờ hiện — Lab 12 M7: steer tới đúng lúc card đang chờ thì runtime huỷ card, Lead tưởng Human
 *    từ chối. Supervisor bị cắt `Write`/`Edit`/`Agent`/`Task` phía Claude.
 * 2. `agent.permission_requested`: lưới an toàn — nếu card tool Paseo của Lead vẫn hiện (mode không
 *    đọc allowedTools), plugin allow ngay.
 *
 * Ranh giới tool Paseo của Peer/Supervisor (`paseoTools.disabledTools`) và `disallowedTools` của Peer
 * vẫn nằm ở provider profile trong ~/.paseo/config.json (docs/PASEO.md §2).
 */
export default function contribute(server: PluginServerContext) {
  const removeCreate = server.before("agent.create", async ({ request }) => {
    const seat = seatOf(request.config.provider);
    if (!seat) return;
    const definition = await readDefinition(request.config.cwd, seat);
    if (!definition) {
      console.error(`slp-paseo: không thấy .claude/agents/${seat}.md trong ${request.config.cwd} hay ~/.claude — bỏ qua`);
      return;
    }
    const providerOptions = providerOptionsFor(seat, request.config.providerOptions);
    const config = {
      ...request.config,
      systemPrompt: buildSystemPrompt(seat, definition.body, request.config.systemPrompt),
      ...(providerOptions === request.config.providerOptions ? {} : { providerOptions }),
    };
    console.log(`slp-paseo: ${seat} ← ${definition.path}${providerOptions === request.config.providerOptions ? "" : ` (providerOptions: ${JSON.stringify(providerOptions)})`}`);
    return { ...request, config };
  });

  const removePermission = server.on("agent.permission_requested", async (event, context) => {
    if (seatOf(event.agent.provider) !== "lead") return;
    if (event.request.kind !== "tool" || !event.request.name.startsWith("mcp__paseo__")) return;
    await context.paseo.agents.ref(event.agent.id).respondToPermission({
      requestId: event.request.id,
      response: { behavior: "allow" },
    });
    console.log(`slp-paseo: allow ${event.request.name} cho lead ${event.agent.id}`);
  });

  return () => {
    removeCreate();
    removePermission();
  };
}
