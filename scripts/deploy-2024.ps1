<#
.SYNOPSIS
  Triển khai plugin + commandset (bản Release R24) vào thư mục Add-ins của Revit 2024.
.DESCRIPTION
  - Dừng nếu Revit đang chạy (DLL bị khoá).
  - Lần đầu: chuyển bản MCP cũ (revit-mcp.addin, revit_mcp_plugin\ cũ, RevitMCPCommandSet\) vào _backup_mcp_cu\.
  - Chép kết quả build, giữ nguyên commandRegistry.json (lệnh đã bật trong Settings).
  Dùng -WhatIf để xem trước mà không thay đổi gì.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\deploy-2024.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$AddinsDir = (Join-Path $env:APPDATA 'Autodesk\Revit\Addins\2024'),
    [string]$BuildDir = '',   # mặc định: <repo>\plugin\bin\AddIn 2024 Release R24 ($PSScriptRoot rỗng trong param của PS 5.1)
    [string]$RevitProcessName = 'Revit'
)
$ErrorActionPreference = 'Stop'
if (-not $BuildDir) { $BuildDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\plugin\bin\AddIn 2024 Release R24' }

if (Get-Process -Name $RevitProcessName -ErrorAction SilentlyContinue) {
    Write-Host 'Hãy đóng Revit trước khi triển khai.'
    exit 1
}
if (-not (Test-Path (Join-Path $BuildDir 'mcp-servers-for-revit.addin'))) {
    Write-Host "Chưa build Release R24 (không thấy $BuildDir). Chạy scripts\build-2024.ps1 trước."
    exit 1
}
if (-not (Test-Path $AddinsDir)) {
    if ($PSCmdlet.ShouldProcess($AddinsDir, 'Tạo thư mục Add-ins')) { New-Item -ItemType Directory -Force $AddinsDir | Out-Null }
}

# 1. Sao lưu bản MCP cũ
$backupDir = Join-Path $AddinsDir '_backup_mcp_cu'
$newAddin = Join-Path $AddinsDir 'mcp-servers-for-revit.addin'
$oldItems = @('revit-mcp.addin', 'RevitMCPCommandSet')
if (-not (Test-Path $newAddin)) { $oldItems += 'revit_mcp_plugin' }   # revit_mcp_plugin chỉ là bản cũ khi chưa có addin mới

foreach ($name in $oldItems) {
    $src = Join-Path $AddinsDir $name
    if (-not (Test-Path $src)) { continue }
    $dest = Join-Path $backupDir $name
    if (Test-Path $dest) { $dest = "$dest-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
    if ($PSCmdlet.ShouldProcess($src, "Chuyển vào $dest")) {
        New-Item -ItemType Directory -Force $backupDir | Out-Null
        Move-Item -LiteralPath $src -Destination $dest
        Write-Host "Đã sao lưu: $name -> $dest"
    }
}

# 2. Chép kết quả build, bỏ qua commandRegistry.json nếu đích đã có
$buildRoot = (Resolve-Path $BuildDir).Path.TrimEnd('\')
$copied = 0
Get-ChildItem -LiteralPath $buildRoot -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($buildRoot.Length + 1)
    $dest = Join-Path $AddinsDir $rel
    if ($_.Name -eq 'commandRegistry.json' -and (Test-Path $dest)) {
        Write-Host "Giữ nguyên: $rel"
        return
    }
    if ($PSCmdlet.ShouldProcess($dest, 'Chép')) {
        New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        Write-Host "Đã chép: $rel"
        $copied++
    }
}

Write-Host ''
Write-Host "Xong ($copied file). Mở Revit 2024 -> tab Revit MCP Plugin -> Settings -> bật lệnh -> Save, rồi bấm Revit MCP Switch."
exit 0
