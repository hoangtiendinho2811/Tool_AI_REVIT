using Autodesk.Revit.UI;
using Newtonsoft.Json.Linq;
using RevitMCPCommandSet.Services.KetCau;
using RevitMCPSDK.API.Base;

namespace RevitMCPCommandSet.Commands.KetCau
{
    /// <summary>Lệnh MCP "get_structural_summary": thống kê phần tử theo hạng mục, level, loại.</summary>
    public class GetStructuralSummaryCommand : ExternalEventCommandBase
    {
        private static readonly object _executionLock = new object();
        private GetStructuralSummaryEventHandler _handler => (GetStructuralSummaryEventHandler)Handler;

        public override string CommandName => "get_structural_summary";

        public GetStructuralSummaryCommand(UIApplication uiApp)
            : base(new GetStructuralSummaryEventHandler(), uiApp)
        {
        }

        public override object Execute(JObject parameters, string requestId)
        {
            lock (_executionLock)
            {
                _handler.Prepare();
                if (RaiseAndWaitForCompletion(120000)) // mô hình lớn có thể mất thời gian
                {
                    return _handler.ResultInfo;
                }
                throw new TimeoutException("Thống kê kết cấu quá thời gian");
            }
        }
    }
}
