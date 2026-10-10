param([Parameter(Mandatory=$true)][string]$OutDir)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = [System.IO.Path]::GetFullPath($OutDir)
$routedDcp = Join-Path $out 'routed.dcp'
if (!(Test-Path -LiteralPath $routedDcp)) { throw "Missing routed checkpoint: $routedDcp" }
$vivado = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
if (!(Test-Path -LiteralPath $vivado)) { throw 'Vivado 2024.1 is unavailable.' }
$tcl = Join-Path $repo 'syn\holdfix_thermo5_qsfp_gt14_parent.tcl'
$log = Join-Path $out 'holdfix.stdout.log'
& $vivado -mode batch -source $tcl -tclargs $out *> $log
if ($LASTEXITCODE -ne 0) { throw "Parent post-route hold fix failed; see $log" }
if (!(Select-String -LiteralPath $log -Pattern 'THERMO5_QSFP_PARENT_HOLDFIX_COMPLETE=' -Quiet)) {
  throw "Parent hold-fix completion marker missing; inspect $log"
}
Write-Host "Parent post-route hold repair completed: $out"
