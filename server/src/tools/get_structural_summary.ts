import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { withRevitConnection } from "../utils/ConnectionManager.js";

export function registerGetStructuralSummaryTool(server: McpServer) {
  server.tool(
    "get_structural_summary",
    "Count ALL columns, beams, floors, walls, foundations and stairs (both structural and architectural) in the open Revit model, grouped by category, level and type. Read-only. Returns { success, message, total, structuralTotal, byCategory, rows[{category, level, type, isStructural, count}] }. Category labels are Vietnamese: 'Cột' (structural column), 'Cột kiến trúc' (architectural column), 'Dầm' (beam), 'Sàn' (floor), 'Vách' (structural wall), 'Tường' (non-structural wall), 'Móng' (foundation), 'Cầu thang' (stairs). Elements without a level are grouped under '(không có level)'.",
    {},
    async (args, extra) => {
      try {
        const response = await withRevitConnection(async (revitClient) => {
          return await revitClient.sendCommand("get_structural_summary", {});
        });

        return {
          content: [{ type: "text", text: JSON.stringify(response, null, 2) }],
        };
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `Thống kê kết cấu thất bại: ${
                error instanceof Error ? error.message : String(error)
              }`,
            },
          ],
        };
      }
    }
  );
}
