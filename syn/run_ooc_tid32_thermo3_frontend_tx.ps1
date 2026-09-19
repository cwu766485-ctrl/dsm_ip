param([string]$Part='xczu15eg-ffvb1156-2-i',[double]$TargetMHz=218.75)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
if(!(Test-Path $settings)){throw 'Vivado settings are unavailable.'}
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'; $out=Join-Path $repo "syn\out\tid32_thermo3_frontend_tx_$stamp"; New-Item -ItemType Directory -Force $out|Out-Null
cmd.exe /d /c "call $settings >nul && vivado -mode batch -source `"$repo\syn\run_ooc_frontend_pipeline.tcl`" -tclargs $Part $TargetMHz `"$out`" > `"$out\vivado.log`" 2>&1"
if($LASTEXITCODE -ne 0){throw "Frontend OOC failed: $LASTEXITCODE"}
if(!(Select-String -Path "$out\vivado.log" -Pattern 'TID32_THERMO3_FRONTEND_OOC_STATUS=PASS' -Quiet)){throw 'Frontend OOC PASS marker is missing.'}
Get-Content "$out\summary.csv"
