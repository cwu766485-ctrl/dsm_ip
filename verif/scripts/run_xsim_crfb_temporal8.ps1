param([int]$Words=256,[int]$Seed=20260915)
$ErrorActionPreference='Stop'; $repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'; if(!(Test-Path $settings)){throw 'Vivado settings missing'}
$work=Join-Path $repo 'verif\out_xsim_crfb_temporal8'; New-Item -ItemType Directory -Force -Path $work|Out-Null
$csv=Join-Path $work 'crfb_temporal8_equivalence.csv'; $m=$repo.Replace('\','/')+'/matlab/tx_bandpass_if';
& matlab -batch "addpath('$m'); gen_crfb_smash2_temporal8_vectors('words',$Words,'seed',$Seed,'output','$($csv.Replace('\','/'))');"; if($LASTEXITCODE){throw 'MATLAB vector generation failed'}
$rtl=Join-Path $repo 'rtl\tx_bandpass_if\crfb_smash2_temporal8.sv'; $tb=Join-Path $repo 'verif\block\bp_dsm\tb\tb_crfb_smash2_temporal8_bittrue.sv'
Push-Location $work
try {
  cmd /c "call `"$settings`" >nul && xvlog -sv `"$rtl`" `"$tb`" && xelab tb_crfb_smash2_temporal8_bittrue -s sim_crfb8 -log xelab.log && xsim sim_crfb8 -runall -log xsim.log"
  if($LASTEXITCODE){throw 'CRFB temporal8 XSim failed'}
  if(!(Select-String -LiteralPath (Join-Path $work 'xsim.log') -Pattern 'CRFB_TEMPORAL8_BITTRUE_PASS' -Quiet)){throw 'CRFB temporal8 PASS marker missing'}
} finally {Pop-Location}
