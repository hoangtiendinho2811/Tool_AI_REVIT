# Hướng dẫn: Claude điều khiển Revit 2024

## 1. Cách hoạt động

```
Claude Code (VS Code)  ──stdio──▶  server Node (server/build/index.js)
                                        │
                                        ▼  TCP 127.0.0.1:8080 (chỉ máy này)
Revit 2024  ◀── plugin revit_mcp_plugin ◀── commandset RevitMCPCommandSet.dll
```

Bạn chat với Claude trong VS Code. Claude gọi lệnh, server chuyển lệnh sang Revit,
Revit thực hiện trên mô hình đang mở rồi trả kết quả.

## 2. Cài đặt lần đầu

Mở PowerShell tại `D:\Tool_AI_REVIT`:

```powershell
# Build plugin, commandset (Release R24) và server
powershell -ExecutionPolicy Bypass -File scripts\build-2024.ps1

# Đóng Revit, rồi triển khai vào %AppData%\Autodesk\Revit\Addins\2024
powershell -ExecutionPolicy Bypass -File scripts\deploy-2024.ps1 -WhatIf   # xem trước
powershell -ExecutionPolicy Bypass -File scripts\deploy-2024.ps1
```

Lần triển khai đầu tiên, bản MCP cũ (`revit-mcp.addin`, `revit_mcp_plugin\`, `RevitMCPCommandSet\`)
được chuyển vào `Addins\2024\_backup_mcp_cu\`. Các add-in khác không bị đụng tới.

Mở VS Code tại `D:\Tool_AI_REVIT`, mở Claude Code. File `.mcp.json` khai báo server `revit`;
chấp nhận khi Claude Code hỏi.

> Luôn build bằng `scripts\build-2024.ps1`. Script này luôn kèm `-restore`: VS Code có thể tự restore
> gói theo cấu hình mặc định (Revit 2020), build thiếu restore sẽ báo lỗi kiểu
> `'ElementId' does not contain a definition for 'Value'`.
>
> Không build cấu hình `Debug R24`: cấu hình đó tự chép thẳng vào thư mục Add-ins.

## 3. Mỗi lần dùng

1. Mở Revit 2024 và một mô hình. Nếu Revit hỏi về add-in lạ, chọn **Always Load**.
2. Tab **Add-Ins** → panel **Revit MCP Plugin** → **Settings** → tick các lệnh muốn dùng → **Save** (chỉ cần làm lần đầu
   và mỗi khi có lệnh mới).
3. Bấm **Revit MCP Switch** để bật dịch vụ.
4. Trong Claude Code, thử: *"gọi say_hello trong Revit"* → Revit hiện hộp thoại.

## 4. Lỗi thường gặp

| Hiện tượng | Nguyên nhân / cách xử lý |
|---|---|
| Claude báo không kết nối được Revit | Revit chưa mở, hoặc chưa bấm **Revit MCP Switch**. |
| Claude báo `Method not found: 'ten_lenh'` | Lệnh chưa được bật: **Settings** → tick lệnh → **Save**, rồi bấm **Revit MCP Switch** hai lần (tắt rồi bật lại) — lệnh chỉ được nạp lúc bật dịch vụ. Lệnh mới thêm luôn phải bật một lần. |
| `deploy-2024.ps1` báo "Hãy đóng Revit trước khi triển khai." | Revit đang khoá DLL. Đóng Revit rồi chạy lại. |
| `get_structural_summary` trả `"Chưa mở mô hình nào trong Revit"` | Mở một mô hình trước khi gọi. |
| Cổng 8080 bị chiếm | Kiểm tra: `netstat -ano \| findstr :8080`. Đảm bảo bản MCP cũ đã nằm trong `_backup_mcp_cu`. |

## 5. Thêm một lệnh mới

Ví dụ có sẵn: `get_structural_summary`. Một lệnh cần **5 chỗ**, tên lệnh phải trùng tuyệt đối:

1. **Logic thuần + test** (không dùng `Autodesk.*`): `commandset/Models/KetCau/<Ten>.cs`,
   test trong `tests/KetCau.Tests/` (thêm `<Compile Include=... Link=...>` vào `KetCau.Tests.csproj`).
   Chạy: `dotnet test tests/KetCau.Tests`.
2. **Handler** (chạy trên luồng Revit): `commandset/Services/KetCau/<Ten>EventHandler.cs`,
   implement `IExternalEventHandler, IWaitableExternalEventHandler`.
3. **Command**: `commandset/Commands/KetCau/<Ten>Command.cs`, kế thừa `ExternalEventCommandBase`,
   `CommandName => "ten_lenh"`.
4. **Manifest**: thêm mục vào `command.json` (`commandName`, `description`, `assemblyPath: "RevitMCPCommandSet.dll"`).
5. **Tool phía server**: `server/src/tools/ten_lenh.ts`, export hàm `register...Tool(server)`.
   Server tự nạp mọi file trong `server/src/tools/`.

Sau đó: `scripts\build-2024.ps1` → đóng Revit → `scripts\deploy-2024.ps1` → mở Revit →
**Settings** → tick lệnh mới → **Save** → bấm **Revit MCP Switch** (nếu dịch vụ đang bật thì tắt rồi bật lại) → mở lại phiên Claude Code để nó thấy tool mới.

## 6. Cảnh báo về `send_code_to_revit`

Lệnh này cho Claude **chạy code C# bất kỳ** bên trong Revit. Code đó có thể sửa hoặc xoá mô hình.
Luôn đọc code Claude định chạy trước khi đồng ý, và lưu mô hình trước khi thử.
Plugin đã được sửa để chỉ nhận kết nối từ chính máy này (`127.0.0.1`); bản gốc mở cho cả mạng LAN.

## 7. Khôi phục bản MCP cũ

Đóng Revit, rồi trong `%AppData%\Autodesk\Revit\Addins\2024`:

1. Xoá `mcp-servers-for-revit.addin` và thư mục `revit_mcp_plugin\`.
2. Chuyển toàn bộ nội dung `_backup_mcp_cu\` ra lại `Addins\2024\`.

Lưu ý: trong lần build đầu tiên, `RevitMCPCommandSet.dll` (và vài thư viện Nice3point) trong thư mục
`RevitMCPCommandSet\` cũ đã bị ghi đè bằng bản build mới. Nếu cần đúng bản cũ, build lại từ mã nguồn
cũ ở `D:\RevitMCP_Workspace\revit-mcp-commandset-main`.

## 8. Lấy cập nhật từ repo gốc

```powershell
git fetch upstream
git merge upstream/main
```

Code của mình nằm trong các thư mục `KetCau` nên ít khi xung đột. Các chỗ đã sửa vào code gốc:
`plugin/Core/SocketService.cs` (chỉ nghe localhost), `commandset/RevitMCPCommandSet.csproj`
(`PublishAddinFiles=false`), `command.json` (thêm lệnh).
