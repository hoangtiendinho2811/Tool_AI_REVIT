# Việc còn tồn sau giai đoạn 1

Ghi lại từ review cuối giai đoạn 1 (2026-11-06). Xử lý ở giai đoạn 2 hoặc khi chạm tới code liên quan.

## Cần kiểm tra trên mô hình thật
- [ ] Đối chiếu `get_structural_summary` với Schedule (ví dụ: cột 40x50 ở 02-TẦNG 2 = 65; cột 22x22 ở 06-TẦNG 6 = 46, lớn bất thường so với 6 ở các tầng khác).
- [ ] Gọi `get_structural_summary` khi không mở mô hình → phải trả `success=false`, "Chưa mở mô hình nào trong Revit".
- [ ] RevitLookup (Snoop Selection) và Add-in Manager hiện trên tab Add-Ins.

## Lệnh `get_structural_summary`
- [ ] Tường xếp chồng (stacked wall): tường cha và các tường con đều là `Wall` → một tường có thể bị đếm 1+N lần. So với Schedule rồi bỏ cha hoặc bỏ con (`Wall.IsStackedWallMember`).
- [ ] Móng băng dưới tường (`WallFoundation`) rơi vào "(không có level)" → lấy level qua `WallFoundation.WallId`.
- [ ] Cầu thang: thêm `STAIRS_BASE_LEVEL_PARAM` vào chuỗi tìm level.
- [ ] Phần tử trong design option phụ đang được đếm.
- [ ] Sắp level theo cao độ thay vì theo tên ("Tầng 10" đang đứng trước "Tầng 2").
- [ ] Chế độ trả kết quả gọn (chỉ `byCategory`) để tiết kiệm token.
- [ ] Timeout C# (120 s) bằng timeout phía Node (120 s) → hạ C# xuống ~110 s để người dùng thấy thông báo tiếng Việt.

## Script
- [ ] `scripts/tests/deploy-2024.tests.ps1`: test 2–6 báo lỗi giả khi Revit đang mở → mặc định truyền `-RevitProcessName KhongCoTienTrinhNay`.
- [ ] `scripts/build-2024.ps1`: báo lỗi rõ bằng tiếng Việt khi không tìm thấy MSBuild.
- [ ] `scripts/deploy-2024.ps1`: nếu `Move-Item` lỗi giữa chừng khi sao lưu, in hướng dẫn khôi phục từ `_backup_mcp_cu`.
- [ ] `docs/huong-dan.md` mục khôi phục: nhắc tới thư mục sao lưu có hậu tố thời gian.

## Quy ước cách vẽ (cần người dùng chốt)
- [ ] Vách tại giao với cột: chạy xuyên tâm cột hay cắt vào mép cột (đề xuất: cắt vào mép cột).
