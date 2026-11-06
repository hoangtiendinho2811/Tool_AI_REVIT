using System.Linq;
using Newtonsoft.Json.Linq;
using RevitMCPCommandSet.Models.KetCau;
using Xunit;

public class StructuralSummaryTests
{
    [Fact]
    public void GopTheoHangMucLevelLoai()
    {
        var r = StructuralSummaryAggregator.Aggregate(new[] {
            new ElementRecord("Cột", "Tầng 1", "C1 400x400"),
            new ElementRecord("Cột", "Tầng 1", "C1 400x400"),
            new ElementRecord("Dầm", "Tầng 1", "D1 220x400"),
            new ElementRecord("Cột", "Tầng 2", "C1 400x400") });
        Assert.True(r.Success);
        Assert.Equal(4, r.Total);
        Assert.Equal(3, r.ByCategory["Cột"]);
        Assert.Equal(1, r.ByCategory["Dầm"]);
        Assert.Equal(3, r.Rows.Count);
        Assert.Equal(2, r.Rows.Single(x => x.Category == "Cột" && x.Level == "Tầng 1").Count);
    }

    [Fact]
    public void SapXepTheoThuTuHangMucRoiLevelRoiLoai()
    {
        var r = StructuralSummaryAggregator.Aggregate(new[] {
            new ElementRecord("Móng", "Tầng 1", "M1"),
            new ElementRecord("Cột", "Tầng 2", "C2"),
            new ElementRecord("Cột", "Tầng 1", "C2"),
            new ElementRecord("Cột", "Tầng 1", "C1") });
        Assert.Equal(new[] { "Cột|Tầng 1|C1", "Cột|Tầng 1|C2", "Cột|Tầng 2|C2", "Móng|Tầng 1|M1" },
            r.Rows.Select(x => $"{x.Category}|{x.Level}|{x.Type}").ToArray());
    }

    [Fact]
    public void LevelRongVaoNhomKhongCoLevel()
    {
        var r = StructuralSummaryAggregator.Aggregate(new[] {
            new ElementRecord("Móng", null, "M1"), new ElementRecord("Móng", "", "M1") });
        Assert.Equal(StructuralSummaryAggregator.NoLevel, r.Rows.Single().Level);
        Assert.Equal(2, r.Rows.Single().Count);
    }

    [Fact]
    public void TachDongKetCauVaKienTrucCungLoai()
    {
        var r = StructuralSummaryAggregator.Aggregate(new[] {
            new ElementRecord("Sàn", "Tầng 1", "S120", true),
            new ElementRecord("Sàn", "Tầng 1", "S120", false),
            new ElementRecord("Tường", "Tầng 1", "T110", false) });
        Assert.Equal(3, r.Total);
        Assert.Equal(1, r.StructuralTotal);
        Assert.Equal(2, r.ByCategory["Sàn"]);
        Assert.Equal(2, r.Rows.Count(x => x.Category == "Sàn"));
        Assert.Equal(new[] { "Sàn", "Tường" }, r.Rows.Select(x => x.Category).Distinct().ToArray());
    }

    [Fact]
    public void DanhSachRongVanThanhCong()
    {
        var r = StructuralSummaryAggregator.Aggregate(new ElementRecord[0]);
        Assert.True(r.Success);
        Assert.Equal(0, r.Total);
        Assert.Empty(r.Rows);
        Assert.Empty(r.ByCategory);
    }

    [Fact]
    public void JsonDungTenTruongCamelCase()
    {
        var r = StructuralSummaryAggregator.Aggregate(new[] { new ElementRecord("Cột", "Tầng 1", "C1", true) });
        var j = JObject.FromObject(r);
        Assert.Equal(new[] { "success", "message", "total", "structuralTotal", "byCategory", "rows" },
            j.Properties().Select(p => p.Name).ToArray());
        Assert.Equal(new[] { "category", "level", "type", "isStructural", "count" },
            ((JObject)j["rows"][0]).Properties().Select(p => p.Name).ToArray());
    }
}
