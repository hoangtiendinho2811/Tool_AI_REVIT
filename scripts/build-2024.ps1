<#
.SYNOPSIS
  Build plugin + commandset (Release R24) và server Node.
  Luôn kèm -restore: VS Code có thể tự restore gói theo cấu hình mặc định (Revit 2020),
  build không restore sẽ lỗi "ElementId does not contain a definition for 'Value'".
#>
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}   # để tiếng Việt hiển thị đúng trong console
$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
$msbuild = 'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe'
if (-not (Test-Path $msbuild)) {
    $vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
    $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
}

& $msbuild (Join-Path $repo 'mcp-servers-for-revit.sln') '-p:Configuration=Release R24' -restore -v:m -nologo
if ($LASTEXITCODE -ne 0) { Write-Host 'Build C# thất bại.'; exit 1 }

Push-Location (Join-Path $repo 'server')
try {
    if (-not (Test-Path 'node_modules')) { npm ci; if ($LASTEXITCODE -ne 0) { exit 1 } }
    npm run build
    if ($LASTEXITCODE -ne 0) { Write-Host 'Build server thất bại.'; exit 1 }
} finally { Pop-Location }

Write-Host 'Build xong. Đóng Revit rồi chạy scripts\deploy-2024.ps1.'
exit 0
