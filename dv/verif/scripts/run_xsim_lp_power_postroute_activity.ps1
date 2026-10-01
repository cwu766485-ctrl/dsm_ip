param(
  [ValidateSet('thermo3','thermo5')][string]$Flavour = 'thermo3',
  [ValidateSet('baseline','lp')][string]$Mode = 'baseline',
  [ValidateSet('continuous','burst','idle')][string]$Workload = 'burst',
  [Parameter(Mandatory=$true)][string]$Netlist,
  [switch]$Smoke,
  [string]$VivadoRoot = 'D:\Xilinx\Vivado\2024.1'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$netlistPath = (Resolve-Path -LiteralPath $Netlist).Path
$out = Join-Path $repo "runs\lp_power_postroute_activity\${Flavour}_${Mode}_${Workload}"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$xvlog = Join-Path $VivadoRoot 'bin\xvlog.bat'
$xelab = Join-Path $VivadoRoot 'bin\xelab.bat'
$xsim = Join-Path $VivadoRoot 'bin\xsim.bat'
foreach ($tool in @($xvlog,$xelab,$xsim)) {
  if (!(Test-Path -LiteralPath $tool)) { throw "Vivado simulator tool missing: $tool" }
}
$simTop = "tb_tid32_${Flavour}_${Mode}_lp_power"
$snapshot = "postroute_${Flavour}_${Mode}_${Workload}"
$workloadArg = "WORKLOAD_$($Workload.ToUpperInvariant())"
$saif = Join-Path $out "${Flavour}_${Mode}_${Workload}_postroute.saif"
$simTcl = Join-Path $out 'run_saif.tcl'
$fileList = Join-Path $out 'compile.f'
Remove-Item -LiteralPath $saif,(Join-Path $out 'result.txt'),(Join-Path $out 'xvlog.log'),(Join-Path $out 'xelab.log'),(Join-Path $out 'xsim.log') -Force -ErrorAction SilentlyContinue
@($netlistPath, (Join-Path $repo 'dv\verif\subsystem\tx_frontend\tb\tb_tid32_thermo_axis_lp_power.sv')) |
  ForEach-Object { '"' + $_ + '"' } | Set-Content -LiteralPath $fileList -Encoding ascii
# The testbench's conditional generate name contains a dot.  XSim represents
# it as one escaped hierarchical token (for example g_thermo3.u_dut), so an
# ordinary slash-separated path silently selects no objects.  Select the DUT
# subtree by name instead; this is resolved against the elaborated netlist.
$activityScope = '*u_dut*'
@(
  "open_saif {$saif}",
  "log_saif [get_objects -r $activityScope]",
  'run all',
  'close_saif',
  'exit'
) | Set-Content -LiteralPath $simTcl -Encoding ascii

Push-Location $out
try {
  $defines = @('-d','POSTROUTE_FUNCSIM')
  if ($Mode -eq 'lp') { $defines += @('-d','POSTROUTE_LP') }
  if ($Smoke) { $defines += @('-d','POSTROUTE_SMOKE') }
  & $xvlog -sv @defines -f $fileList -log xvlog.log
  if ($LASTEXITCODE -ne 0) { throw "post-route xvlog failed; see $out\xvlog.log" }
  # Functional netlists instantiate Xilinx primitives that reference the
  # global reset model.  Elaborating glbl explicitly is required by XSim.
  & $xelab $simTop glbl -L unisims_ver -L unimacro_ver -debug typical -s $snapshot -log xelab.log
  if ($LASTEXITCODE -ne 0) { throw "post-route xelab failed; see $out\xelab.log" }
  & $xsim $snapshot -tclbatch (Split-Path -Leaf $simTcl) `
    -testplusarg $workloadArg -log xsim.log
  if ($LASTEXITCODE -ne 0) { throw "post-route xsim failed; see $out\xsim.log" }
} finally {
  Pop-Location
}
$pass = Select-String -Path (Join-Path $out 'xsim.log') -Pattern 'LP_POWER_WORKLOAD_PASS' | Select-Object -Last 1
if (!$pass) { throw "PASS marker missing; see $out\xsim.log" }
if (!(Test-Path -LiteralPath $saif)) { throw "SAIF missing: $saif" }
$pass.Line | Set-Content -LiteralPath (Join-Path $out 'result.txt')
# The final read_saif step uses the recorded simulation scope and normalizes
# the escaped generate name to the OOC top.  Keeping this provenance avoids
# a misleading claim that a hand-written strip string increased coverage.
$stripPath = "${simTop}/u_tb (escaped g_${Flavour}.u_dut normalized to OOC top)"
$stripPath | Set-Content -LiteralPath (Join-Path $out 'strip_path.txt')
Write-Host $pass.Line
Write-Host "POSTROUTE_SAIF=$saif"
Write-Host "POSTROUTE_STRIP_PATH=$stripPath"
