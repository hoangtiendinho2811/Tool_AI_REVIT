# Giai đoạn 1 — Nền móng: Claude ↔ Revit 2024 qua MCP

Ngày: 2026-11-06 · Trạng thái: đã duyệt (2026-11-06)

## Mục đích

Người dùng làm kết cấu (chính) và kiến trúc trên **Revit 2024**. Mục tiêu dài hạn là để AI
dựng cột/dầm/sàn/vách/cầu thang và vẽ thép theo TCVN, với đầu vào từ lời nói, Excel, CAD và PDF.
Giai đoạn 1 chỉ dựng **nền**: Claude ra lệnh được cho Revit, có quy trình thêm lệnh mới,
và có công cụ hỗ trợ lập trình. Các giai đoạn sau xây trên nền này.

Lộ trình đã thống nhất:
1. **Nền móng** (tài liệu này)
2. Lệnh dựng hình kết cấu — đầu vào Excel + lời nói
3. Vẽ thép cột/dầm/sàn/vách theo TCVN
4. Đọc bản vẽ CAD link + PDF vector → lệnh dựng hình
5. AI tự viết C# cho việc chưa có lệnh, có tra tài liệu Revit API
6. (Tuỳ chọn, sau giai đoạn 3) Khung chat ngay trong Revit, chuyển yêu cầu sang Claude Code
   chạy ẩn (`claude -p`) để dùng gói Claude sẵn có — không cần API key, không tốn thêm tiền

Cách chat ở giai đoạn 1: người dùng chat trong Claude Code (VS Code) đặt cạnh Revit. Đã cân nhắc
chạy AI trên máy (Ollama) — loại vì GPU 4 GB VRAM chỉ chạy được mô hình nhỏ, gọi lệnh kém chính xác;
và API trả theo lượt — loại vì người dùng muốn không tốn thêm tiền.

## Mục tiêu

- Từ Claude Code (trong VS Code), gọi được các lệnh có sẵn của mcp-servers-for-revit trên Revit 2024
  (ví dụ `say_hello`, `get_current_view_info`, `create_grid`, `create_level`).
- Có mã nguồn tại `D:\Tool_AI_REVIT`, build được bản Revit 2024 trên máy này, có script cài đặt một lệnh.
- Thêm **một lệnh mẫu của mình** chạy thông suốt từ Claude tới Revit, chứng minh quy trình thêm lệnh
  cho giai đoạn 2.
- Cài **RevitLookup** và **Add-in Manager** cho Revit 2024.
- Có hướng dẫn tiếng Việt: cài đặt, khởi động, thêm lệnh mới.

## Không làm trong giai đoạn này

- Lệnh dựng hình kết cấu chuyên sâu, vẽ thép, đọc CAD/PDF, RAG tài liệu API (giai đoạn 2–5).
- Hỗ trợ phiên bản Revit khác 2024.

## Tuyệt đối tránh

- Làm hỏng các add-in đang có của người dùng trong `%AppData%\Autodesk\Revit\Addins\2024`
  (BTCK 060, Bai_Thi_Cuoi_Ky, GridCreatorAddin, RevitAddinTool…).
- Xoá bản MCP cũ. Bản cũ (`revit-mcp.addin`, `revit_mcp_plugin`, `RevitMCPCommandSet`) chỉ được
  **chuyển vào thư mục sao lưu**, khôi phục được.

## Ràng buộc

- Revit 2024 → add-in .NET Framework 4.8, cấu hình build `Release R24` của repo gốc.
- Máy có .NET SDK 8 và 9, Node.js 24. Chưa rõ có Visual Studio / MSBuild cho .NET Framework không —
  người làm kiểm tra; ưu tiên build bằng `dotnet build` (thêm gói reference assemblies nếu cần).
- Repo gốc: https://github.com/mcp-servers-for-revit/mcp-servers-for-revit (MIT). Muốn thêm lệnh
  phải khai báo ở **cả** phần server TypeScript **và** commandset C# (tên lệnh phải trùng).

## Các cách đã cân nhắc

| Cách | Ưu | Nhược | Quyết định |
|---|---|---|---|
| **A. Fork repo gốc, phát triển tiếp** | Chạy ngay, có ~25 lệnh, có sẵn `send_code_to_revit` cho giai đoạn 5 | Khung add-in là của họ; cập nhật từ upstream có thể phải gộp tay | **Chọn** (người dùng chọn) |
| B. Tự làm từ template Nice3point + cầu nối riêng | Toàn quyền, đúng template | Tốn thêm vài ngày, phải viết lại lệnh cơ bản | Không chọn |
| C. Cài nguyên bản, viết bộ lệnh riêng nạp thêm | Tách biệt | Không có tài liệu hỗ trợ bộ lệnh bên thứ ba; vẫn phải sửa server | Loại |

Thư viện Nice3point (Toolkit/Extensions) có thể dùng trong code lệnh nếu tiện; template Nice3point
để dành cho add-in độc lập có nút bấm riêng sau này.

## Thiết kế

**Mã nguồn.** `D:\Tool_AI_REVIT` là repo git chứa mã của mcp-servers-for-revit, remote `upstream`
trỏ về repo gốc. Có đẩy lên GitHub riêng hay không là việc sau, không thuộc giai đoạn này.

**Server MCP.** Chạy từ mã nguồn trong `server/` (build bằng Node), **không** dùng `npx` gói npm,
vì sẽ thêm lệnh của mình. Đăng ký vào Claude Code ở phạm vi dự án (`.mcp.json` trong repo).

**Plugin + commandset.** Build cấu hình Release R24. Một script PowerShell `scripts/deploy-2024.ps1`:
1. Kiểm tra Revit đang tắt (nếu đang mở thì dừng và báo).
2. Lần đầu: chuyển bản MCP cũ vào `%AppData%\Autodesk\Revit\Addins\2024\_backup_mcp_cu\`.
3. Chép kết quả build vào đúng cấu trúc thư mục mà plugin yêu cầu.

**Lệnh mẫu.** `get_structural_summary`: đếm **tất cả** cột, dầm, sàn, vách/tường, móng, cầu thang (cả kết cấu lẫn kiến trúc, có cờ phân biệt) theo level và loại (type)
trong mô hình đang mở, trả về JSON. Chọn lệnh này vì nó chỉ đọc (an toàn), hữu ích cho kết cấu,
và đi đủ đường: tool TS → WebSocket → commandset C# → Revit API → trả kết quả.

**Công cụ hỗ trợ.** Cài bản phát hành Revit 2024 của RevitLookup (github.com/jeremytammik/RevitLookup)
và Add-in Manager (github.com/chuongmep/RevitAddInManager).

**Tài liệu.** `docs/huong-dan.md` bằng tiếng Việt: cài đặt, mở Revit và bật lệnh (tab
mcp-servers-for-revit → Settings → Save), kiểm tra kết nối, các bước thêm một lệnh mới
(lấy `get_structural_summary` làm ví dụ), cách khôi phục bản MCP cũ.

**Kiểm tra hoàn thành.** Mở một mô hình kết cấu mẫu trong Revit 2024; từ Claude Code gọi lần lượt
`say_hello`, `get_current_view_info`, `get_structural_summary`, ra kết quả đúng. Mở RevitLookup và
Add-in Manager từ ribbon. Các add-in cũ của người dùng vẫn nạp bình thường.

## Để người làm tự quyết

- Cách build .NET Framework 4.8 trên máy này; chi tiết script triển khai.
- Cổng WebSocket (giữ mặc định của repo gốc).
- Định dạng JSON chi tiết của `get_structural_summary`.
- Kiểm tra code repo gốc (lệnh `send_code_to_revit` chạy code tuỳ ý — ghi chú rủi ro trong hướng dẫn).

## Những quyết định là của tôi (Claude), người dùng chưa trực tiếp chọn

- Dùng Claude Code làm client (không phải Claude Desktop).
- Chạy server từ mã nguồn thay vì `npx`.
- Lệnh mẫu là `get_structural_summary`.
- Bản MCP cũ được chuyển vào thư mục sao lưu thay vì xoá.
