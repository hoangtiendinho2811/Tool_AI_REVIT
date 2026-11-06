# Giai đoạn 1 — Nền MCP cho Revit 2024: Kế hoạch thực hiện

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude Code gọi được lệnh Revit 2024 qua bản fork mcp-servers-for-revit, có thêm lệnh kết cấu đầu tiên `get_structural_summary`, cài kèm RevitLookup + Add-in Manager, có hướng dẫn tiếng Việt.

**Architecture:** Repo `D:\Tool_AI_REVIT` là fork của mcp-servers-for-revit (remote `upstream`). Claude Code ↔ (stdio) ↔ server Node `server/build/index.js` ↔ (TCP localhost:8080) ↔ plugin C# `revit_mcp_plugin` trong Revit ↔ commandset `RevitMCPCommandSet.dll` (Revit API qua ExternalEvent). Logic thuần (không phụ thuộc Revit) tách riêng để test bằng xUnit.

**Tech Stack:** C# / .NET Framework 4.8 (cấu hình `Release R24`), MSBuild VS 2022 Community, Nice3point.Revit.* 2024, RevitMCPSDK 2024; TypeScript + @modelcontextprotocol/sdk + zod (Node 24); xUnit (net48); PowerShell 5.1.

**Spec:** `docs/superpowers/specs/2026-11-06-giai-doan-1-nen-mcp-design.md`

## Global Constraints

- Chỉ Revit **2024**; build bằng `"C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" mcp-servers-for-revit.sln -p:Configuration="Release R24" -restore` (giống workflow upstream).
- **Không** build cấu hình `Debug R24`: target Debug của upstream tự chép vào `%AppData%\Autodesk\Revit\Addins\2024\revit_mcp_plugin\` — trùng tên thư mục plugin MCP cũ của người dùng. Chỉ triển khai qua `scripts/deploy-2024.ps1`.
- Không đụng tới add-in khác trong `Addins\2024` (BTCK 060, Bai_Thi_Cuoi_Ky_111220060, GridCreatorAddin, RevitAddinTool, Resources, ExamTemplateAddin.addin.disabled).
- Bản MCP cũ (`revit-mcp.addin`, `revit_mcp_plugin\`, `RevitMCPCommandSet\` trong `Addins\2024`) chỉ được **chuyển** vào `Addins\2024\_backup_mcp_cu\`, không xoá.
- Tên lệnh phải trùng tuyệt đối giữa `server/src/tools/*.ts`, `command.json` và `CommandName` trong C#.
- Chữ hiển thị cho người dùng (nhãn hạng mục, thông báo lỗi, tài liệu) bằng tiếng Việt.
- Code của mình đặt trong thư mục con `KetCau` (namespace `RevitMCPCommandSet.*.KetCau`) để tách khỏi code upstream, dễ gộp cập nhật.

## Review Focus

1. **Revit đang mở khi chạy deploy** → DLL bị khoá; script phải dừng với thông báo rõ, không chép dở dang. (Task 3, kiểm bằng chạy thử khi Revit mở.)
2. **Redeploy xoá mất `commandRegistry.json`** (nơi lưu các lệnh người dùng đã bật trong Settings) → script phải giữ nguyên file này. (Task 3)
3. **Gọi lệnh khi chưa mở mô hình nào** → trả `success=false` với thông báo "Chưa mở mô hình nào trong Revit", không ném lỗi khó hiểu. (Task 5)
4. **Phần tử không có level** (dầm chỉ có Reference Level, cột chỉ có Base Level, móng gắn host) → không được rơi mất hay lỗi; xếp đúng level theo thứ tự ưu tiên, còn lại vào nhóm "(không có level)". (Task 5, test aggregator + bước kiểm tra thủ công)
5. **Lệnh mới chưa được bật trong Settings** → Claude gọi sẽ báo không tìm thấy lệnh; tài liệu phải có bước bật lệnh và cách nhận biết lỗi này. (Task 7)

---

### Task 1: Tạo repo git từ upstream và build bản gốc cho Revit 2024

**Files:**
- Create: `.gitignore` bổ sung (nếu upstream chưa có): `server/node_modules/`, `server/build/`, `**/bin/`, `**/obj/`
- Giữ nguyên: `docs/superpowers/**` (đã có)

**Interfaces:**
- Produces: nhánh `giai-doan-1` dựa trên `upstream/main`; thư mục build `plugin/bin/AddIn 2024 Release R24/` chứa `mcp-servers-for-revit.addin` và `revit_mcp_plugin/` (có `Commands/RevitMCPCommandSet/command.json` + `Commands/RevitMCPCommandSet/2024/RevitMCPCommandSet.dll`); `server/build/index.js`.

- [ ] **Step 1:** Trong `D:\Tool_AI_REVIT`: `git init`, `git remote add upstream https://github.com/mcp-servers-for-revit/mcp-servers-for-revit`, `git fetch upstream`, `git checkout -b giai-doan-1 upstream/main` (thư mục `docs/` chưa track không xung đột vì upstream không có `docs/superpowers`).
- [ ] **Step 2:** Build C#: lệnh MSBuild ở Global Constraints. Expected: `Build succeeded`, 0 error.
- [ ] **Step 3:** Kiểm tra: `ls "plugin/bin/AddIn 2024 Release R24/revit_mcp_plugin/Commands/RevitMCPCommandSet/2024/RevitMCPCommandSet.dll"` tồn tại; và **không** có gì mới trong `%AppData%\Autodesk\Revit\Addins\2024` (so `Get-ChildItem` trước/sau).
- [ ] **Step 4:** Build server: `cd server; npm ci; npm run build`. Expected: có `server/build/index.js`.
- [ ] **Step 5:** Commit: `git add .gitignore docs; git commit -m "chore: khởi tạo fork, thêm tài liệu thiết kế giai đoạn 1"`.

### Task 2: Chỉ cho phép kết nối từ máy này (sửa lỗ hổng mạng)

Upstream mở cổng bằng `new TcpListener(IPAddress.Any, _port)` (`plugin/Core/SocketService.cs:105`) → máy khác trong mạng LAN gửi được lệnh, kể cả `send_code_to_revit` (chạy code tuỳ ý). Server chỉ kết nối `localhost` (`server/src/utils/ConnectionManager.ts:23`) nên đổi sang loopback không ảnh hưởng chức năng.

**Files:**
- Modify: `plugin/Core/SocketService.cs:105`

- [ ] **Step 1:** Đổi thành `new TcpListener(IPAddress.Loopback, _port)`; thêm comment một dòng tiếng Việt nêu lý do.
- [ ] **Step 2:** Build lại (lệnh MSBuild). Expected: 0 error.
- [ ] **Step 3:** (Kiểm chứng chạy thật làm ở Task 4 Step 4: `netstat -ano | findstr :8080` phải hiện `127.0.0.1:8080`, không phải `0.0.0.0:8080`.)
- [ ] **Step 4:** Commit: `fix(plugin): chỉ lắng nghe trên localhost`.

### Task 3: Script triển khai `scripts/deploy-2024.ps1`

**Files:**
- Create: `scripts/deploy-2024.ps1`

**Interfaces:**
- Consumes: thư mục build của Task 1.
- Produces: `powershell -ExecutionPolicy Bypass -File scripts/deploy-2024.ps1 [-WhatIf]`; mã thoát 0 = thành công, 1 = dừng có lý do.

Hành vi (theo thứ tự):
1. Nếu có tiến trình `Revit` đang chạy → in "Hãy đóng Revit trước khi triển khai." và `exit 1`, không chép gì.
2. Nếu thư mục build `plugin\bin\AddIn 2024 Release R24\` không có → in "Chưa build Release R24." và `exit 1`.
3. Nếu `Addins\2024\revit-mcp.addin`, `Addins\2024\RevitMCPCommandSet\` tồn tại, hoặc `Addins\2024\revit_mcp_plugin\` tồn tại **mà không có** `Addins\2024\mcp-servers-for-revit.addin` (tức là bản cũ) → chuyển chúng vào `Addins\2024\_backup_mcp_cu\` (tạo nếu chưa có; nếu đích đã tồn tại thì thêm hậu tố thời gian `yyyyMMdd-HHmmss`). In từng mục đã chuyển.
4. Chép toàn bộ nội dung thư mục build vào `Addins\2024\`, **bỏ qua** `commandRegistry.json` nếu đích đã có file đó.
5. In danh sách file đã chép và nhắc: "Mở Revit → tab Revit MCP Plugin → Settings → bật lệnh → Save."
- `-WhatIf` (dùng `[CmdletBinding(SupportsShouldProcess)]`): in mọi việc sẽ làm, không thay đổi gì.

- [ ] **Step 1:** Ghi lại hiện trạng: `Get-ChildItem "$env:APPDATA\Autodesk\Revit\Addins\2024" | Select Name` (lưu ra scratchpad để so).
- [ ] **Step 2:** Viết script theo hành vi trên.
- [ ] **Step 3:** Chạy `-WhatIf`. Expected: liệt kê chuyển 3 mục cũ vào `_backup_mcp_cu` và các file sẽ chép; `Get-ChildItem` không đổi so với Step 1.
- [ ] **Step 4:** Kiểm Review Focus 1: mở Revit 2024 (hoặc nhờ người dùng mở), chạy script thật. Expected: thông báo "Hãy đóng Revit…", exit 1, thư mục không đổi.
- [ ] **Step 5:** Đóng Revit, chạy thật. Expected: 3 mục cũ nằm trong `_backup_mcp_cu`; có `mcp-servers-for-revit.addin` và `revit_mcp_plugin\Commands\RevitMCPCommandSet\2024\RevitMCPCommandSet.dll`; các add-in khác của người dùng còn nguyên.
- [ ] **Step 6:** Kiểm Review Focus 2: tạo tạm file `revit_mcp_plugin\Commands\commandRegistry.json` có nội dung `{"test":1}` (nếu chưa có), chạy lại script, file vẫn còn nội dung `{"test":1}`; xoá file thử.
- [ ] **Step 7:** Commit: `feat(scripts): thêm script triển khai Revit 2024`.

### Task 4: Đăng ký MCP vào Claude Code và chạy thử lệnh có sẵn

**Files:**
- Create: `.mcp.json`

```json
{
  "mcpServers": {
    "revit": {
      "command": "node",
      "args": ["server/build/index.js"]
    }
  }
}
```

- [ ] **Step 1:** Tạo `.mcp.json` như trên. Người dùng mở lại phiên Claude Code trong `D:\Tool_AI_REVIT` và chấp nhận server `revit` khi được hỏi.
- [ ] **Step 2:** Người dùng mở Revit 2024 + một mô hình kết cấu của họ; chọn "Always Load" nếu hỏi; tab **Revit MCP Plugin → Settings** → bật tất cả lệnh → **Save**; bấm **Revit MCP Switch** để bật dịch vụ.
- [ ] **Step 3:** Từ Claude Code gọi `say_hello` (message "Xin chào từ Claude") → hộp thoại hiện trong Revit; gọi `get_current_view_info` → trả JSON có tên view đang mở.
- [ ] **Step 4:** `netstat -ano | findstr :8080` → có `127.0.0.1:8080 ... LISTENING`, không có `0.0.0.0:8080` (kiểm Task 2).
- [ ] **Step 5:** Commit: `chore: đăng ký server MCP revit cho Claude Code`.

### Task 5: Lệnh `get_structural_summary`

Thống kê **toàn bộ** phần tử kết cấu và kiến trúc (cột, dầm, sàn, vách/tường, móng, cầu thang) trong mô hình đang mở theo hạng mục → level → loại, mỗi dòng có cờ `isStructural` để phân biệt kết cấu/kiến trúc. (Người dùng chọn đếm tất cả, không lọc.)

**Files:**
- Create: `commandset/Models/KetCau/StructuralSummary.cs` — kiểu dữ liệu + bộ gộp, **không** `using Autodesk.*`
- Create: `commandset/Services/KetCau/GetStructuralSummaryEventHandler.cs`
- Create: `commandset/Commands/KetCau/GetStructuralSummaryCommand.cs`
- Modify: `command.json` — thêm mục lệnh
- Create: `server/src/tools/get_structural_summary.ts`
- Test: `tests/KetCau.Tests/KetCau.Tests.csproj` (net48, xUnit, `<Compile Include="..\..\commandset\Models\KetCau\StructuralSummary.cs" Link="StructuralSummary.cs" />`, **không** thêm vào `.sln`), `tests/KetCau.Tests/StructuralSummaryTests.cs`

**Interfaces:**
- Produces (C#, namespace `RevitMCPCommandSet.Models.KetCau`):
  - `public sealed class ElementRecord { public string Category; public string Level; public string Type; public bool IsStructural; }` (constructor `(string category, string level, string type, bool isStructural = true)`)
  - `public sealed class SummaryRow { public string Category; public string Level; public string Type; public bool IsStructural; public int Count; }`
  - `public sealed class StructuralSummary { public bool Success; public string Message; public int Total; public int StructuralTotal; public Dictionary<string,int> ByCategory; public List<SummaryRow> Rows; }`
  - `public static class StructuralSummaryAggregator { public static readonly string[] CategoryOrder = { "Cột", "Cột kiến trúc", "Dầm", "Sàn", "Vách", "Tường", "Móng", "Cầu thang" }; public const string NoLevel = "(không có level)"; public static StructuralSummary Aggregate(IEnumerable<ElementRecord> records); }`
  - Gộp theo khoá (Category, Level, Type, IsStructural). `ByCategory` đếm theo Category (cả kết cấu lẫn kiến trúc). `StructuralTotal` = số phần tử có `IsStructural=true`.
- Tên lệnh: `get_structural_summary`; không có tham số.
- JSON trả về (Newtonsoft, camelCase như các lệnh upstream): `{ "success": true, "message": "", "total": 36, "structuralTotal": 30, "byCategory": { "Cột": 24, "Dầm": 6, "Tường": 6 }, "rows": [ { "category": "Cột", "level": "Tầng 1", "type": "C1 400x400", "isStructural": true, "count": 24 } ] }`

- [ ] **Step 1: Viết test thất bại** trong `StructuralSummaryTests.cs`:

```csharp
[Fact] public void GopTheoHangMucLevelLoai()
{
    var r = StructuralSummaryAggregator.Aggregate(new[] {
        new ElementRecord("Cột","Tầng 1","C1 400x400"),
        new ElementRecord("Cột","Tầng 1","C1 400x400"),
        new ElementRecord("Dầm","Tầng 1","D1 220x400"),
        new ElementRecord("Cột","Tầng 2","C1 400x400") });
    Assert.True(r.Success);
    Assert.Equal(4, r.Total);
    Assert.Equal(3, r.ByCategory["Cột"]);
    Assert.Equal(1, r.ByCategory["Dầm"]);
    Assert.Equal(3, r.Rows.Count);
    Assert.Equal(2, r.Rows.Single(x => x.Category=="Cột" && x.Level=="Tầng 1").Count);
}
[Fact] public void SapXepTheoThuTuHangMucRoiLevelRoiLoai()
{
    var r = StructuralSummaryAggregator.Aggregate(new[] {
        new ElementRecord("Móng","Tầng 1","M1"),
        new ElementRecord("Cột","Tầng 2","C2"),
        new ElementRecord("Cột","Tầng 1","C2"),
        new ElementRecord("Cột","Tầng 1","C1") });
    Assert.Equal(new[]{"Cột|Tầng 1|C1","Cột|Tầng 1|C2","Cột|Tầng 2|C2","Móng|Tầng 1|M1"},
        r.Rows.Select(x => $"{x.Category}|{x.Level}|{x.Type}").ToArray());
}
[Fact] public void LevelRongVaoNhomKhongCoLevel()
{
    var r = StructuralSummaryAggregator.Aggregate(new[] {
        new ElementRecord("Móng", null, "M1"), new ElementRecord("Móng", "", "M1") });
    Assert.Equal(StructuralSummaryAggregator.NoLevel, r.Rows.Single().Level);
    Assert.Equal(2, r.Rows.Single().Count);
}
[Fact] public void TachDongKetCauVaKienTrucCungLoai()
{
    var r = StructuralSummaryAggregator.Aggregate(new[] {
        new ElementRecord("Sàn","Tầng 1","S120", true),
        new ElementRecord("Sàn","Tầng 1","S120", false),
        new ElementRecord("Tường","Tầng 1","T110", false) });
    Assert.Equal(3, r.Total);
    Assert.Equal(1, r.StructuralTotal);
    Assert.Equal(2, r.ByCategory["Sàn"]);
    Assert.Equal(2, r.Rows.Count(x => x.Category == "Sàn"));
    Assert.Equal(new[]{"Sàn","Tường"}, r.Rows.Select(x => x.Category).Distinct().ToArray());
}
[Fact] public void DanhSachRongVanThanhCong()
{
    var r = StructuralSummaryAggregator.Aggregate(new ElementRecord[0]);
    Assert.True(r.Success); Assert.Equal(0, r.Total); Assert.Empty(r.Rows); Assert.Empty(r.ByCategory);
}
```

(Sắp xếp level theo thứ tự chữ là tạm; sắp theo cao độ để giai đoạn 2.)

- [ ] **Step 2:** `dotnet test tests/KetCau.Tests` → FAIL (chưa có `StructuralSummaryAggregator`).
- [ ] **Step 3:** Viết `StructuralSummary.cs`. Hạng mục không có trong `CategoryOrder` xếp sau cùng theo chữ cái; `ByCategory` chỉ chứa hạng mục có phần tử.
- [ ] **Step 4:** `dotnet test tests/KetCau.Tests` → 5 PASS.
- [ ] **Step 5:** Viết `GetStructuralSummaryEventHandler` theo mẫu `Services/DataExtraction/AnalyzeModelStatisticsEventHandler.cs` (ManualResetEvent, `IWaitableExternalEventHandler`, thuộc tính `ResultInfo` kiểu `StructuralSummary`). Trong `Execute`:
  - Nếu `app.ActiveUIDocument?.Document == null` → `ResultInfo = { Success=false, Message="Chưa mở mô hình nào trong Revit" }`.
  - Thu thập **tất cả** (WhereElementIsNotElementType), không lọc, theo ánh xạ hạng mục → nhãn / `isStructural`:
    - `OST_StructuralColumns` → "Cột" / true
    - `OST_Columns` → "Cột kiến trúc" / false
    - `OST_StructuralFraming` → "Dầm" / true
    - `OST_Floors` → "Sàn" / `FLOOR_PARAM_IS_STRUCTURAL` = 1
    - `OST_Walls` → `WALL_STRUCTURAL_SIGNIFICANT` = 1 ? "Vách" / true : "Tường" / false
    - `OST_StructuralFoundation` → "Móng" / true
    - `OST_Stairs` → "Cầu thang" / false (Revit không có cờ kết cấu cho cầu thang)
  - Tham số không có hoặc không đọc được → coi là `false`.
  - Level: `element.LevelId` hợp lệ → tên level; nếu không, `INSTANCE_REFERENCE_LEVEL_PARAM`; nếu không, `FAMILY_BASE_LEVEL_PARAM`; nếu không → `null` (bộ gộp đổi thành `NoLevel`).
  - Type: tên `ElementType` (`doc.GetElement(e.GetTypeId())?.Name`), nếu null → `"(không rõ loại)"`.
  - Bọc ngoại lệ → `Success=false, Message="Lỗi: " + ex.Message`; luôn `Set()` trong `finally`.
- [ ] **Step 6:** Viết `GetStructuralSummaryCommand` theo mẫu `Commands/DataExtraction/AnalyzeModelStatisticsCommand.cs`: `CommandName => "get_structural_summary"`, `RaiseAndWaitForCompletion(120000)`, hết giờ → `TimeoutException("Thống kê kết cấu quá thời gian")`.
- [ ] **Step 7:** Thêm vào `command.json`: `{ "commandName": "get_structural_summary", "description": "Thống kê cột, dầm, sàn, vách, móng, cầu thang theo level và loại", "assemblyPath": "RevitMCPCommandSet.dll" }`.
- [ ] **Step 8:** Viết `server/src/tools/get_structural_summary.ts` theo mẫu `say_hello.ts`: export `registerGetStructuralSummaryTool(server: McpServer)`; mô tả tool (tiếng Anh cho AI hiểu tốt, kèm ghi chú trả về nhãn tiếng Việt); schema rỗng `{}`; gửi `sendCommand("get_structural_summary", args)`; lỗi → text `"Thống kê kết cấu thất bại: ..."`. (`register.ts` tự nạp mọi file trong `tools/`.)
- [ ] **Step 9:** Build C# (MSBuild) + `cd server; npm run build` → 0 lỗi. Đóng Revit, chạy `scripts/deploy-2024.ps1`.
- [ ] **Step 10:** Kiểm thật (người dùng mở mô hình kết cấu, bật lệnh mới trong Settings → Save, bật Switch): gọi `get_structural_summary` → số cột/dầm khớp với Schedule hoặc đếm tay ở một level; có dầm (chỉ có Reference Level) nằm đúng level (Review Focus 4). Đóng mô hình (để Revit mở nhưng không có document), gọi lại → `success=false`, message "Chưa mở mô hình nào trong Revit" (Review Focus 3).
- [ ] **Step 11:** Commit: `feat(ketcau): thêm lệnh get_structural_summary`.

### Task 6: Cài RevitLookup và Add-in Manager cho Revit 2024

**Files:** không có (cài phần mềm).

- [ ] **Step 1:** Tìm bản phát hành mới nhất hỗ trợ 2024: https://github.com/jeremytammik/RevitLookup/releases và https://github.com/chuongmep/RevitAddInManager/releases. Tải installer (.msi/.exe) vào thư mục con riêng trong scratchpad. Báo người dùng tên file + phiên bản trước khi cài.
- [ ] **Step 2:** Người dùng xác nhận → chạy installer (đóng Revit trước).
- [ ] **Step 3:** Mở Revit 2024: tab Add-ins có RevitLookup (Snoop Selection chạy được trên một cột) và Add-in Manager (mở được cửa sổ). Add-in cũ của người dùng vẫn hiện.

### Task 7: Hướng dẫn tiếng Việt `docs/huong-dan.md`

**Files:**
- Create: `docs/huong-dan.md`

Nội dung (mỗi mục ngắn, có lệnh copy được):
1. Kiến trúc một hình ASCII: Claude Code ↔ server ↔ localhost:8080 ↔ Revit.
2. Cài đặt lần đầu: build (lệnh MSBuild + npm), `deploy-2024.ps1`, mở Claude Code trong `D:\Tool_AI_REVIT`.
3. Mỗi lần dùng: mở Revit → Switch; kiểm `say_hello`.
4. Lỗi thường gặp: "không kết nối được" (chưa bật Switch / Revit chưa mở); "không tìm thấy lệnh" (chưa bật lệnh trong Settings → Save — Review Focus 5); deploy báo "Hãy đóng Revit".
5. Thêm lệnh mới — 5 chỗ phải sửa, lấy `get_structural_summary` làm ví dụ (Model+test, Handler, Command, `command.json`, tool TS), rồi build → deploy → bật trong Settings.
6. Cảnh báo `send_code_to_revit`: chạy code tuỳ ý trong Revit, luôn đọc code trước khi cho chạy; đã giới hạn chỉ nhận kết nối từ máy này.
7. Khôi phục bản MCP cũ: xoá `mcp-servers-for-revit.addin` + `revit_mcp_plugin\`, chuyển nội dung `_backup_mcp_cu\` về `Addins\2024\`.
8. Lấy cập nhật từ upstream: `git fetch upstream; git merge upstream/main`.

- [ ] **Step 1:** Viết tài liệu.
- [ ] **Step 2:** Kiểm: mọi lệnh/đường dẫn trong tài liệu khớp với file thật (`scripts/deploy-2024.ps1`, `.mcp.json`, tên tab ribbon "Revit MCP Plugin", nút "Revit MCP Switch", "Settings").
- [ ] **Step 3:** Commit: `docs: thêm hướng dẫn tiếng Việt`.
