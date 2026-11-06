using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;

// Không dùng Autodesk.* ở file này: được biên dịch lại trong tests/KetCau.Tests để test không cần Revit.
namespace RevitMCPCommandSet.Models.KetCau
{
    /// <summary>Một phần tử đã đọc từ mô hình: hạng mục (nhãn tiếng Việt), level, loại, có phải kết cấu không.</summary>
    public sealed class ElementRecord
    {
        public string Category;
        public string Level;
        public string Type;
        public bool IsStructural;

        public ElementRecord(string category, string level, string type, bool isStructural = true)
        {
            Category = category;
            Level = level;
            Type = type;
            IsStructural = isStructural;
        }
    }

    public sealed class SummaryRow
    {
        [JsonProperty("category")] public string Category;
        [JsonProperty("level")] public string Level;
        [JsonProperty("type")] public string Type;
        [JsonProperty("isStructural")] public bool IsStructural;
        [JsonProperty("count")] public int Count;
    }

    public sealed class StructuralSummary
    {
        [JsonProperty("success")] public bool Success;
        [JsonProperty("message")] public string Message = "";
        [JsonProperty("total")] public int Total;
        [JsonProperty("structuralTotal")] public int StructuralTotal;
        [JsonProperty("byCategory")] public Dictionary<string, int> ByCategory = new Dictionary<string, int>();
        [JsonProperty("rows")] public List<SummaryRow> Rows = new List<SummaryRow>();
    }

    public static class StructuralSummaryAggregator
    {
        public static readonly string[] CategoryOrder = { "Cột", "Cột kiến trúc", "Dầm", "Sàn", "Vách", "Tường", "Móng", "Cầu thang" };
        public const string NoLevel = "(không có level)";

        public static StructuralSummary Aggregate(IEnumerable<ElementRecord> records)
        {
            var list = records.ToList();
            var rows = list
                .GroupBy(r => new
                {
                    r.Category,
                    Level = string.IsNullOrEmpty(r.Level) ? NoLevel : r.Level,
                    r.Type,
                    r.IsStructural
                })
                .Select(g => new SummaryRow
                {
                    Category = g.Key.Category,
                    Level = g.Key.Level,
                    Type = g.Key.Type,
                    IsStructural = g.Key.IsStructural,
                    Count = g.Count()
                })
                .OrderBy(r => CategoryRank(r.Category))
                .ThenBy(r => r.Category, StringComparer.Ordinal)
                .ThenBy(r => r.Level, StringComparer.Ordinal)
                .ThenBy(r => r.Type, StringComparer.Ordinal)
                .ThenByDescending(r => r.IsStructural)
                .ToList();

            var byCategory = new Dictionary<string, int>();
            foreach (var row in rows)
            {
                byCategory.TryGetValue(row.Category, out var n);
                byCategory[row.Category] = n + row.Count;
            }

            return new StructuralSummary
            {
                Success = true,
                Total = list.Count,
                StructuralTotal = list.Count(r => r.IsStructural),
                ByCategory = byCategory,
                Rows = rows
            };
        }

        // Hạng mục không có trong CategoryOrder xếp sau cùng (rồi theo chữ cái).
        private static int CategoryRank(string category)
        {
            int i = Array.IndexOf(CategoryOrder, category);
            return i < 0 ? CategoryOrder.Length : i;
        }
    }
}
