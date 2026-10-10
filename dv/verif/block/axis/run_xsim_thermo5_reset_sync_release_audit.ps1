$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$settings = 'D:\Xilinx\Vivado\2024.1\settings64.bat'
$out = Join-Path $repo 'runs\thermo5_reset_bin_audit_xsim_20261006_01'
$rtl = Join-Path $repo 'rtl\axis\dsm_reset_sync.sv'
$tb = Join-Path $repo 'dv\verif\block\axis\tb_thermo5_reset_sync_release_audit.sv'

if (!(Test-Path -LiteralPath $settings)) { throw "Vivado settings are unavailable: $settings" }
if (Test-Path -LiteralPath $out) { throw "Output path already exists: $out" }
New-Item -ItemType Directory -Path $out | Out-Null
@("date=$(Get-Date -Format o)", "xvlog=$(Join-Path (Split-Path $settings) 'bin\xvlog.bat')", "xsim=$(Join-Path (Split-Path $settings) 'bin\xsim.bat')") |
  Set-Content -LiteralPath (Join-Path $out 'tool_manifest.txt') -Encoding ascii

Push-Location $out
try {
  $rtlArg = '"' + $rtl + '"'
  $tbArg = '"' + $tb + '"'
  cmd.exe /d /c "call `"$settings`" >nul && xvlog -sv $rtlArg $tbArg > console_xvlog.log 2>&1 && xelab thermo5_sku_uvm_tb -s sim_reset_sync_audit > console_xelab.log 2>&1 && xsim sim_reset_sync_audit -runall > console_xsim.log 2>&1"
  if ($LASTEXITCODE -ne 0) { throw "Reset synchronizer XSim failed with exit code $LASTEXITCODE" }
}
finally { Pop-Location }

if (!(Select-String -LiteralPath (Join-Path $out 'console_xsim.log') -Pattern 'RESET_SYNC_AUDIT_PASS source_epochs=2 core_epochs=2 source_release_edges=2 core_release_edges=2 source_1_0_samples=0 core_1_0_samples=0' -Quiet)) {
  throw "Reset audit PASS marker is missing; inspect $out"
}
Write-Host "RESET_SYNC_XSIM_PASS log=$out\console_xsim.log"
