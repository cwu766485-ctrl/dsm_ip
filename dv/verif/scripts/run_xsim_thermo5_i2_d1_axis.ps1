param([switch]$StressPaReady,[switch]$XpmFifo,[int]$Seed=1)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$work=Join-Path $repo $(if($XpmFifo){"runs\uvm_thermo5_i2_d1\axis_xsim_xpm_seed$Seed"}else{'runs\uvm_thermo5_i2_d1\axis_xsim'})
$vectors=Join-Path $repo 'runs\uvm_thermo5_i2_d1\vectors'
if (!(Test-Path -LiteralPath (Join-Path $vectors 'tid32_thermo5_frontend_pa3.mem'))) {
  throw 'Run dv/uvm/sim/generate_thermo5_sku_vectors.ps1 first.'
}
New-Item -ItemType Directory -Force -Path $work | Out-Null
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
if (!(Test-Path -LiteralPath $settings)) { throw 'Vivado settings unavailable.' }
$relative=@(
  'rtl/axis/dsm_reset_sync.sv','rtl/axis/dsm_frame_power_ctrl.sv',
  'rtl/axis/dsm_async_fifo.sv','rtl/axis/dsm_xpm_async_fifo.sv',
  'rtl/axis/dsm_axis14_to_core8_cdc.sv',
  'rtl/frontend/dsm_frame_gain_vector.sv',
  'rtl/gt/gt_tx_user_bridge.sv','rtl/gt/gt_tx_raw64_boundary.sv',
  'rtl/dpd/dpd_poly.v','rtl/dpd/dpd_memory_poly.v',
  'rtl/dpd/dpd_vector16_memory_poly.sv','rtl/dpd/dpd_vector_elastic_buffer.sv',
  'rtl/interp/dsm_interp_x2_polyphase_vector.sv',
  'rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo5_axis_frontend_tx.sv',
  'dv/verif/subsystem/tx_frontend/tb/tb_thermo5_i2_d1_axis_bittrue.sv'
)
$vendor=@()
$define=''
if($XpmFifo){
  $vendor=@(
    'D:\Xilinx\Vivado\2024.1\data\verilog\src\glbl.v',
    'D:\Xilinx\Vivado\2024.1\data\ip\xpm\xpm_cdc\hdl\xpm_cdc.sv',
    'D:\Xilinx\Vivado\2024.1\data\ip\xpm\xpm_memory\hdl\xpm_memory.sv',
    'D:\Xilinx\Vivado\2024.1\data\ip\xpm\xpm_fifo\hdl\xpm_fifo.sv'
  )
  foreach($path in $vendor){if(!(Test-Path -LiteralPath $path)){throw "Missing vendor XPM model: $path"}}
  $define='-d THERMO5_XPM_FIFO'
}
$source=(($vendor + ($relative | ForEach-Object { Join-Path $repo $_ })) | ForEach-Object { '"'+$_+'"' }) -join ' '
Push-Location $work
try {
  cmd.exe /d /c "call $settings >nul && xvlog -sv $define $source > console_xvlog.log 2>&1"
  if ($LASTEXITCODE -ne 0) { throw "xvlog failed: $work\console_xvlog.log" }
  $tops=if($XpmFifo){'tb_thermo5_i2_d1_axis_bittrue glbl'}else{'tb_thermo5_i2_d1_axis_bittrue'}
  cmd.exe /d /c "call $settings >nul && xelab $tops -s sim_thermo5_i2_d1_axis > console_xelab.log 2>&1"
  if ($LASTEXITCODE -ne 0) { throw "xelab failed: $work\console_xelab.log" }
  Copy-Item -Path (Join-Path $vectors '*.mem') -Destination $work
  $plusarg=if($StressPaReady){'-testplusarg STRESS_PA_READY'}else{''}
  cmd.exe /d /c "call $settings >nul && xsim sim_thermo5_i2_d1_axis -runall -sv_seed $Seed $plusarg > console_xsim.log 2>&1"
  if ($LASTEXITCODE -ne 0) { throw "xsim failed: $work\console_xsim.log" }
} finally { Pop-Location }
if (!(Select-String -LiteralPath (Join-Path $work 'console_xsim.log') -Pattern 'THERMO5_I2_D1_AXIS_BITTRUE_PASS' -Quiet)) {
  throw "Full-chain PASS marker missing: $work\console_xsim.log"
}
if (Select-String -LiteralPath (Join-Path $work 'console_xsim.log') -Pattern '(^|\s)(Error:|Fatal:|FATAL_ERROR:)' -Quiet) {
  throw "XSim reported an error despite the PASS marker: $work\console_xsim.log"
}
Write-Host "THERMO5_I2_D1_AXIS_BITTRUE_PASS log=$work\console_xsim.log"
