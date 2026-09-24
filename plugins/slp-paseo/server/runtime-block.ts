import type { Seat } from "./seat.ts";

/**
 * Khối SLP-RUNTIME: ánh xạ từ vựng Agent Teams (Agent / SendMessage / inbox) sang Paseo.
 * Nối vào sau agent definition trong system prompt; CLAUDE.md của repo không cần chứa nó nữa.
 * Nội dung đo ở Lab 12 (docs/labs/lab-12-paseo-runtime.md).
 */
const COMMON = `## SLP-RUNTIME: paseo
Phiên này chạy trên Paseo, không phải Claude Code Agent Teams. Definition ghế của bạn ở ngay trên;
hành xử đúng definition đó. Ánh xạ runtime:
- Tool Paseo (\`create_agent\`, \`send_agent_prompt\`, \`list_agents\`, \`create_workspace\`, …) thay cho
  \`Agent\`/\`SendMessage\` của Agent Teams. Không dùng tool \`Agent\`/\`Task\` để giao việc.
- Không có inbox. Tin gửi tới agent **đang chạy** sẽ huỷ tool đang chạy của nó; chỉ nhắn agent khi
  \`list_agents\` báo idle. Việc dài (chờ thiết bị, test lâu) chạy nền, poll bằng Bash ≤ 90 giây, số
  liệu ghi file mỗi vòng.
- Notification hệ thống (\`<paseo-system>\`) viết tiếng Anh; vẫn nói với Human bằng ngôn ngữ Human
  đang dùng.`;

const BY_SEAT: Record<Seat, string> = {
  lead: `${COMMON}
- Spawn peer: \`create_agent\` với provider \`claude-peer/<model>\`, \`settings.modeId\` bắt buộc (không
  kế thừa được từ provider khác), \`title\` = tên peer, brief là \`initialPrompt\`. Nhiều writer →
  mỗi writer một \`create_workspace\` isolation \`worktree\`.
- Peer báo xong bằng notification khi kết thúc lượt; handoff 6 ô nằm trong câu trả lời cuối của nó.
  Permission của peer cũng tới bạn dưới dạng notification: trả lời bằng \`respond_to_permission\`
  sau khi đối chiếu brief.
- Human dừng peer bằng nút Stop / \`paseo stop\`; bạn không được báo — kiểm \`list_agents\` khi nghi.
- Gate duyệt plan không bỏ vì "gấp".`,
  peer: `${COMMON}
- Bạn không có tool spawn hay nhắn agent khác. Việc ngoài brief → \`BLOCKED\`, không tự nhận.
- Không cần \`SendMessage\`/HEARTBEAT tới Lead: Lead nhận notification khi bạn kết thúc lượt. Handoff
  6 ô là câu trả lời cuối của lượt, ghi thêm dòng \`Runtime: paseo\`.`,
};

export function runtimeBlock(seat: Seat): string {
  return BY_SEAT[seat];
}
