param([int]$Words=128,[int]$Seed=20260916)
$ErrorActionPreference='Stop'
$expectedWords=128
if($Words -ne $expectedWords){throw "This checked testbench is fixed at $expectedWords words; requested Words=$Words."}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
if(!(Test-Path $settings)){throw 'Vivado settings are unavailable.'}
$work=Join-Path $repo 'verif\out_xsim_tid32_mash11_fs4_multipa_tx'; New-Item -Force -ItemType Directory $work|Out-Null
$quoted=$work.Replace("'","''")
& 'D:\MATLAB\R2025a\bin\matlab.exe' -batch "addpath(genpath('$($repo.Replace('\','/'))/matlab/tx_bandpass_if')); gen_tid32_mash11_bittrue_vectors('$($quoted.Replace('\','/'))',$Words,$Seed);"
if($LASTEXITCODE){throw 'MATLAB TID-MASH vector generation failed.'}
$sources=@("$repo\rtl\gt\gt_tx_user_bridge.sv","$repo\rtl\gt\gt_tx_raw64_boundary.sv","$repo\rtl\tx_bandpass_if\tid32_cartesian_fs4_gt_tx.sv","$repo\rtl\tx_bandpass_if\tid32_mash11_fs4_multipa_tx.sv","$repo\verif\block\bp_dsm\tb\tb_tid32_mash11_fs4_multipa_tx_bittrue.sv")
Push-Location $work
try {
  $args=($sources|ForEach-Object{'"'+$_+'"'}) -join ' '
  cmd.exe /d /c "call `"$settings`" >nul && xvlog -sv $args > console_xvlog.log 2>&1 && xelab tb_tid32_mash11_fs4_multipa_tx_bittrue -s sim_tidmash > console_xelab.log 2>&1 && xsim sim_tidmash -runall > console_xsim.log 2>&1"
  if($LASTEXITCODE){throw "TID-MASH XSim failed: $LASTEXITCODE"}
} finally {Pop-Location}
if(!(Select-String -Path "$work\console_xsim.log" -Pattern 'TID32_MASH11_FS4_MULTIPA_BITTRUE_PASS' -Quiet)){throw 'TID-MASH PASS marker is missing.'}
Write-Host "TID32 MASH11 Fs/4 multi-PA XSim PASS: $work\console_xsim.log"
