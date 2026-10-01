param(
  [ValidateSet('thermo3','thermo5')][string]$Flavour = 'thermo3',
  [ValidateSet('baseline','lp')][string]$Mode = 'baseline',
  [ValidateSet('continuous','burst','idle','tdd_sparse')][string]$Workload = 'continuous',
  [string]$VivadoRoot = 'D:\Xilinx\Vivado\2024.1'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$out = Join-Path $repo "runs\lp_power_activity\${Flavour}_${Mode}_${Workload}"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$xvlog = Join-Path $VivadoRoot 'bin\xvlog.bat'
$xelab = Join-Path $VivadoRoot 'bin\xelab.bat'
$xsim = Join-Path $VivadoRoot 'bin\xsim.bat'
foreach ($tool in @($xvlog,$xelab,$xsim)) {
  if (!(Test-Path -LiteralPath $tool)) { throw "Vivado simulator tool missing: $tool" }
}
$sources = @(
  'rtl/axis/dsm_reset_sync.sv',
  'rtl/axis/dsm_frame_power_ctrl.sv',
  'rtl/axis/dsm_async_fifo.sv',
  'rtl/axis/dsm_xpm_async_fifo.sv',
  'rtl/axis/dsm_axis14_to_core8_cdc.sv',
  'rtl/frontend/dsm_frame_gain_vector.sv',
  'rtl/gt/gt_tx_user_bridge.sv',
  'rtl/gt/gt_tx_raw64_boundary.sv',
  'rtl/dpd/dpd_poly.v',
  'rtl/dpd/dpd_memory_poly.v',
  'rtl/dpd/dpd_vector16_memory_poly.sv',
  'rtl/dpd/dpd_vector_elastic_buffer.sv',
  'rtl/interp/dsm_interp_x2_polyphase_vector.sv',
  'rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo3_fs4_multipa_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo3_frontend_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo3_axis_frontend_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo5_axis_frontend_tx.sv',
  'dv/verif/subsystem/tx_frontend/tb/tb_tid32_thermo_axis_lp_power.sv'
) | ForEach-Object { Join-Path $repo $_ }
$simTop = "tb_tid32_${Flavour}_${Mode}_lp_power"
$snapshot = "lp_power_${Flavour}_${Mode}_${Workload}"
$workloadArg = "WORKLOAD_$($Workload.ToUpperInvariant())"
$saif = Join-Path $out "${Flavour}_${Mode}_${Workload}.saif"
$simTcl = Join-Path $out 'run_saif.tcl'
$fileList = Join-Path $out 'compile.f'
Remove-Item -LiteralPath $saif,(Join-Path $out 'result.txt'),(Join-Path $out 'xvlog.log'),(Join-Path $out 'xelab.log'),(Join-Path $out 'xsim.log') -Force -ErrorAction SilentlyContinue
$sources | ForEach-Object { '"' + $_ + '"' } | Set-Content -LiteralPath $fileList -Encoding ascii
$activityScope = "/${simTop}/u_tb/*"
@(
  "open_saif {$saif}",
  "log_saif [get_objects -r $activityScope]",
  'run all',
  'close_saif',
  'exit'
) | Set-Content -LiteralPath $simTcl -Encoding ascii

Push-Location $out
try {
  & $xvlog -sv -f $fileList -log xvlog.log
  if ($LASTEXITCODE -ne 0) { throw "xvlog failed; see $out\xvlog.log" }
  & $xelab $simTop -debug typical -s $snapshot -log xelab.log
  if ($LASTEXITCODE -ne 0) { throw "xelab failed; see $out\xelab.log" }
  & $xsim $snapshot -tclbatch (Split-Path -Leaf $simTcl) `
    -testplusarg $workloadArg `
    -log xsim.log
  if ($LASTEXITCODE -ne 0) { throw "xsim failed; see $out\xsim.log" }
} finally {
  Pop-Location
}
$pass = Select-String -Path (Join-Path $out 'xsim.log') -Pattern 'LP_POWER_WORKLOAD_PASS' | Select-Object -Last 1
if (!$pass) { throw "PASS marker missing; see $out\xsim.log" }
if (!(Test-Path -LiteralPath $saif)) { throw "SAIF missing: $saif" }
# XSim emits the generate block and DUT instance as one escaped SAIF name
# (for example g_thermo3\.u_dut).  Normalize that source-only hierarchy to
# the u_dut instance present in the routed OOC wrapper before Vivado mapping.
$saifText = [System.IO.File]::ReadAllText($saif)
$escapedDut = if ($Flavour -eq 'thermo5') {
  'g_thermo5\.u_dut'
} else {
  'g_thermo3\.u_dut'
}
if (!$saifText.Contains("(INSTANCE  $escapedDut")) {
  throw "expected XSim DUT hierarchy missing from SAIF: $escapedDut"
}
$saifText = $saifText.Replace("(INSTANCE  $escapedDut", '(INSTANCE  u_dut')
[System.IO.File]::WriteAllText($saif, $saifText, [System.Text.Encoding]::ASCII)
$pass.Line | Set-Content -LiteralPath (Join-Path $out 'result.txt')
Write-Host $pass.Line
Write-Host "SAIF=$saif"
