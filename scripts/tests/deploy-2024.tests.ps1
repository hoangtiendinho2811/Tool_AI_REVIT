# Kiểm thử scripts/deploy-2024.ps1 trên thư mục giả (không đụng %AppData% thật).
# Chạy: powershell -ExecutionPolicy Bypass -File scripts/tests/deploy-2024.tests.ps1
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$deploy = Join-Path $PSScriptRoot '..\deploy-2024.ps1'
$failures = 0

function Assert($cond, $msg) {
    if ($cond) { Write-Host "  PASS $msg" } else { Write-Host "  FAIL $msg" -ForegroundColor Red; $script:failures++ }
}

function New-Fixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("deploytest-" + [guid]::NewGuid())
    $addins = Join-Path $root 'Addins'
    $build = Join-Path $root 'build'
    # Bản MCP cũ + add-in khác của người dùng
    New-Item -ItemType Directory -Force "$addins\revit_mcp_plugin" | Out-Null
    Set-Content "$addins\revit_mcp_plugin\old.dll" 'old'
    Set-Content "$addins\revit-mcp.addin" 'old addin'
    New-Item -ItemType Directory -Force "$addins\RevitMCPCommandSet" | Out-Null
    Set-Content "$addins\RevitMCPCommandSet\old.dll" 'old'
    New-Item -ItemType Directory -Force "$addins\GridCreatorAddin" | Out-Null
    Set-Content "$addins\GridCreatorAddin.addin" 'user addin'
    # Kết quả build
    New-Item -ItemType Directory -Force "$build\revit_mcp_plugin\Commands\RevitMCPCommandSet\2024" | Out-Null
    Set-Content "$build\mcp-servers-for-revit.addin" 'new addin'
    Set-Content "$build\revit_mcp_plugin\RevitMCPPlugin.dll" 'new'
    Set-Content "$build\revit_mcp_plugin\Commands\RevitMCPCommandSet\command.json" '{}'
    Set-Content "$build\revit_mcp_plugin\Commands\RevitMCPCommandSet\2024\RevitMCPCommandSet.dll" 'new'
    Set-Content "$build\revit_mcp_plugin\Commands\commandRegistry.json" '{"fromBuild":1}'
    return @{ Root = $root; Addins = $addins; Build = $build }
}

function Invoke-Deploy($f, [string[]]$extra) {
    $args2 = @('-ExecutionPolicy', 'Bypass', '-File', $deploy, '-AddinsDir', $f.Addins, '-BuildDir', $f.Build) + $extra
    $ErrorActionPreference = 'Continue'
    $out = & powershell.exe @args2 2>&1 | Out-String
    return @{ Code = $LASTEXITCODE; Out = $out }
}

Write-Host "Test 1: Revit dang chay -> dung, khong thay doi gi"
$f = New-Fixture
$before = (Get-ChildItem $f.Addins -Recurse | ForEach-Object FullName) -join '|'
$r = Invoke-Deploy $f @('-RevitProcessName', 'powershell')   # powershell chắc chắn đang chạy
Assert ($r.Code -eq 1) "exit code 1"
Assert ($r.Out -match 'Hãy đóng Revit') "thong bao dong Revit"
Assert (((Get-ChildItem $f.Addins -Recurse | ForEach-Object FullName) -join '|') -eq $before) "thu muc khong doi"
Remove-Item $f.Root -Recurse -Force

Write-Host "Test 2: chua build -> dung"
$f = New-Fixture
Remove-Item $f.Build -Recurse -Force
$r = Invoke-Deploy $f @('-RevitProcessName', 'KhongCoTienTrinhNay')
Assert ($r.Code -eq 1) "exit code 1"
Assert ($r.Out -match 'Chưa build Release R24') "thong bao chua build"
Remove-Item $f.Root -Recurse -Force

Write-Host "Test 3: -WhatIf khong thay doi gi"
$f = New-Fixture
$before = (Get-ChildItem $f.Addins -Recurse | ForEach-Object FullName) -join '|'
$r = Invoke-Deploy $f @('-RevitProcessName', 'KhongCoTienTrinhNay', '-WhatIf')
Assert ($r.Code -eq 0) "exit code 0"
Assert (((Get-ChildItem $f.Addins -Recurse | ForEach-Object FullName) -join '|') -eq $before) "thu muc khong doi"
Remove-Item $f.Root -Recurse -Force

Write-Host "Test 4: trien khai lan dau -> sao luu ban cu, chep ban moi, giu add-in khac"
$f = New-Fixture
$r = Invoke-Deploy $f @('-RevitProcessName', 'KhongCoTienTrinhNay')
$bk = Join-Path $f.Addins '_backup_mcp_cu'
Assert ($r.Code -eq 0) "exit code 0"
Assert (Test-Path "$bk\revit-mcp.addin") "revit-mcp.addin da sao luu"
Assert (Test-Path "$bk\revit_mcp_plugin\old.dll") "revit_mcp_plugin cu da sao luu"
Assert (Test-Path "$bk\RevitMCPCommandSet\old.dll") "RevitMCPCommandSet cu da sao luu"
Assert (-not (Test-Path "$($f.Addins)\revit-mcp.addin")) "revit-mcp.addin khong con o goc"
Assert (-not (Test-Path "$($f.Addins)\RevitMCPCommandSet")) "RevitMCPCommandSet khong con o goc"
Assert (-not (Test-Path "$($f.Addins)\revit_mcp_plugin\old.dll")) "file cu khong lan vao plugin moi"
Assert (Test-Path "$($f.Addins)\mcp-servers-for-revit.addin") "addin moi da chep"
Assert (Test-Path "$($f.Addins)\revit_mcp_plugin\Commands\RevitMCPCommandSet\2024\RevitMCPCommandSet.dll") "commandset moi da chep"
Assert (Test-Path "$($f.Addins)\GridCreatorAddin.addin") "add-in khac cua nguoi dung con nguyen"
Assert ($r.Out -match 'Settings') "nhac bat lenh trong Settings"

Write-Host "Test 5: trien khai lai -> giu commandRegistry.json, khong sao luu plugin moi"
Set-Content "$($f.Addins)\revit_mcp_plugin\Commands\commandRegistry.json" '{"test":1}'
$r = Invoke-Deploy $f @('-RevitProcessName', 'KhongCoTienTrinhNay')
Assert ($r.Code -eq 0) "exit code 0"
Assert ((Get-Content "$($f.Addins)\revit_mcp_plugin\Commands\commandRegistry.json" -Raw).Trim() -eq '{"test":1}') "commandRegistry.json giu nguyen"
Assert (@(Get-ChildItem $bk).Count -eq 3) "khong sao luu them gi"
Remove-Item $f.Root -Recurse -Force

Write-Host "Test 6: da co ban sao luu -> them hau to thoi gian"
$f = New-Fixture
New-Item -ItemType Directory -Force "$($f.Addins)\_backup_mcp_cu\revit-mcp.addin" | Out-Null
$r = Invoke-Deploy $f @('-RevitProcessName', 'KhongCoTienTrinhNay')
Assert ($r.Code -eq 0) "exit code 0"
Assert (@(Get-ChildItem "$($f.Addins)\_backup_mcp_cu" -Filter 'revit-mcp.addin*').Count -eq 2) "ban sao luu thu hai co hau to"
Remove-Item $f.Root -Recurse -Force

Write-Host "Test 7: khong truyen -BuildDir -> dung thu muc build mac dinh cua repo"
$f = New-Fixture
$ErrorActionPreference = 'Continue'
$out = & powershell.exe -ExecutionPolicy Bypass -File $deploy -AddinsDir $f.Addins -RevitProcessName KhongCoTienTrinhNay -WhatIf 2>&1 | Out-String
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Assert ($code -eq 0) "exit code 0 (out: $($out.Substring(0, [Math]::Min(120, $out.Length))))"
Assert ($out -match 'mcp-servers-for-revit\.addin') "liet ke file tu thu muc build mac dinh"
Remove-Item $f.Root -Recurse -Force

if ($failures -gt 0) { Write-Host "$failures test FAIL" -ForegroundColor Red; exit 1 } else { Write-Host "Tat ca PASS"; exit 0 }
