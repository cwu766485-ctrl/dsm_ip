$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
$work=Join-Path $repo 'dv\verif\out_xsim_gt_link_bringup_bist'; New-Item -ItemType Directory -Force $work | Out-Null
$src=@((Join-Path $repo 'rtl\gt\gt_link_bringup_bist.sv'),(Join-Path $repo 'dv\verif\block\gt\tb_gt_link_bringup_bist.sv')) | ForEach-Object {'"'+$_+'"'}
Push-Location $work
try {
  cmd.exe /d /c "call $settings >nul && xvlog -sv $($src -join ' ') && xelab tb_gt_link_bringup_bist -s sim_gt_link_bringup_bist && xsim sim_gt_link_bringup_bist -runall > xsim.log"
  if($LASTEXITCODE -ne 0){ throw "GT BERT XSim failed: $LASTEXITCODE" }
  $log = Get-Content (Join-Path $work 'xsim.log') -Raw
  if($log -notmatch 'GT_LINK_BRINGUP_BIST_PASS') { throw 'GT BERT simulation did not emit PASS marker' }
  if($log -match '(?m)^\s*(Fatal:|Error:)') { throw 'GT BERT simulation reported a fatal/error' }
  Write-Host $log.TrimEnd()
} finally { Pop-Location }
Write-Host "GT link bring-up/BERT XSim PASS"


