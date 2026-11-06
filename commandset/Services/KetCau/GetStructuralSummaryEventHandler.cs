using Autodesk.Revit.DB;
using Autodesk.Revit.UI;
using RevitMCPCommandSet.Models.KetCau;
using RevitMCPSDK.API.Interfaces;
using ElementRecord = RevitMCPCommandSet.Models.KetCau.ElementRecord; // trùng tên với Autodesk.Revit.DB.ElementRecord

namespace RevitMCPCommandSet.Services.KetCau
{
    /// <summary>
    /// Đọc toàn bộ cột/dầm/sàn/vách/tường/móng/cầu thang (kết cấu + kiến trúc) trong mô hình đang mở.
    /// Chạy trên luồng chính của Revit qua ExternalEvent.
    /// </summary>
    public class GetStructuralSummaryEventHandler : IExternalEventHandler, IWaitableExternalEventHandler
    {
        private readonly ManualResetEvent _resetEvent = new ManualResetEvent(false);

        public StructuralSummary ResultInfo { get; private set; }

        public void Prepare()
        {
            ResultInfo = null;
            _resetEvent.Reset();
        }

        // Không Reset ở đây: Prepare() đã Reset trước khi Raise, tránh mất tín hiệu khi Execute chạy xong rất nhanh.
        public bool WaitForCompletion(int timeoutMilliseconds = 10000)
        {
            return _resetEvent.WaitOne(timeoutMilliseconds);
        }

        public void Execute(UIApplication app)
        {
            try
            {
                var doc = app.ActiveUIDocument?.Document;
                if (doc == null)
                {
                    ResultInfo = new StructuralSummary { Success = false, Message = "Chưa mở mô hình nào trong Revit" };
                    return;
                }

                var records = new List<ElementRecord>();
                Collect(doc, BuiltInCategory.OST_StructuralColumns, records, e => ("Cột", true));
                Collect(doc, BuiltInCategory.OST_Columns, records, e => ("Cột kiến trúc", false));
                Collect(doc, BuiltInCategory.OST_StructuralFraming, records, e => ("Dầm", true));
                Collect(doc, BuiltInCategory.OST_Floors, records, e => ("Sàn", IsFlagSet(e, BuiltInParameter.FLOOR_PARAM_IS_STRUCTURAL)));
                Collect(doc, BuiltInCategory.OST_Walls, records, e =>
                    IsFlagSet(e, BuiltInParameter.WALL_STRUCTURAL_SIGNIFICANT) ? ("Vách", true) : ("Tường", false));
                Collect(doc, BuiltInCategory.OST_StructuralFoundation, records, e => ("Móng", true));
                Collect(doc, BuiltInCategory.OST_Stairs, records, e => ("Cầu thang", false)); // Revit không có cờ kết cấu cho cầu thang

                ResultInfo = StructuralSummaryAggregator.Aggregate(records);
            }
            catch (Exception ex)
            {
                ResultInfo = new StructuralSummary { Success = false, Message = "Lỗi: " + ex.Message };
            }
            finally
            {
                _resetEvent.Set();
            }
        }

        public string GetName() => "Get Structural Summary";

        private static void Collect(Document doc, BuiltInCategory bic, List<ElementRecord> records,
            Func<Element, (string label, bool isStructural)> classify)
        {
            var elements = new FilteredElementCollector(doc).OfCategory(bic).WhereElementIsNotElementType();
            foreach (Element e in elements)
            {
                var (label, isStructural) = classify(e);
                string type = doc.GetElement(e.GetTypeId())?.Name ?? "(không rõ loại)";
                records.Add(new ElementRecord(label, GetLevelName(doc, e), type, isStructural));
            }
        }

        // Thứ tự: Level của phần tử -> Reference Level (dầm) -> Base Level (cột) -> null (bộ gộp đổi thành "(không có level)").
        private static string GetLevelName(Document doc, Element e)
        {
            if (e.LevelId != null && e.LevelId != ElementId.InvalidElementId)
            {
                var name = doc.GetElement(e.LevelId)?.Name;
                if (!string.IsNullOrEmpty(name)) return name;
            }
            foreach (var bip in new[] { BuiltInParameter.INSTANCE_REFERENCE_LEVEL_PARAM, BuiltInParameter.FAMILY_BASE_LEVEL_PARAM })
            {
                var id = e.get_Parameter(bip)?.AsElementId();
                if (id != null && id != ElementId.InvalidElementId)
                {
                    var name = doc.GetElement(id)?.Name;
                    if (!string.IsNullOrEmpty(name)) return name;
                }
            }
            return null;
        }

        // Tham số không có hoặc không đọc được -> false.
        private static bool IsFlagSet(Element e, BuiltInParameter bip)
        {
            var p = e.get_Parameter(bip);
            return p != null && p.HasValue && p.StorageType == StorageType.Integer && p.AsInteger() == 1;
        }
    }
}
