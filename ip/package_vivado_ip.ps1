param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $VivadoBat)) {
  throw "Vivado executable not found: $VivadoBat"
}

$script = Join-Path $PSScriptRoot "package_vivado_ip.tcl"
$component = Join-Path $PSScriptRoot "ip_repo\dsm_ip_1_0\component.xml"
$log = Join-Path $PSScriptRoot "build\package_vivado_ip.log"
$started = Get-Date
Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
& $VivadoBat -mode batch -source $script -log $log
if ($LASTEXITCODE -ne 0) {
  throw "Vivado IP packaging failed"
}
if (-not (Test-Path -LiteralPath $log)) {
  throw "Vivado returned without producing the packaging log"
}
if (-not (Test-Path -LiteralPath $component)) {
  throw "Vivado returned without producing component.xml"
}
if ((Get-Item -LiteralPath $component).LastWriteTime -lt $started) {
  throw "Vivado did not refresh component.xml during this packaging run"
}
if (-not (Select-String -LiteralPath $log -Pattern "Packaged DSM IP:" -SimpleMatch)) {
  throw "Vivado packaging success marker was not found"
}
