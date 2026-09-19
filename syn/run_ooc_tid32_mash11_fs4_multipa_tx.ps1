param([string]$VivadoBat='D:\Xilinx\Vivado\2024.1\bin\vivado.bat',[string]$Part='xczu15eg-ffvb1156-2-i',[double]$TargetMHz=218.75,[string]$OutRoot='')
$ErrorActionPreference='Stop'; if(!(Test-Path $VivadoBat)){throw "Vivado executable not found: $VivadoBat"}
if([string]::IsNullOrWhiteSpace($OutRoot)){$OutRoot=Join-Path $PSScriptRoot 'out'}; $OutRoot=[IO.Path]::GetFullPath($OutRoot); New-Item -ItemType Directory -Force -Path $OutRoot|Out-Null
$label=('{0:F2}' -f $TargetMHz).Replace('.','p'); $outDir=Join-Path $OutRoot "tid32_mash11_fs4_multipa_tx_ooc_$($Part.Replace('-','_'))_${label}mhz_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
& $VivadoBat -mode batch -source (Join-Path $PSScriptRoot 'run_ooc_tid32_mash11_fs4_multipa_tx.tcl') -tclargs $Part $TargetMHz $outDir
if($LASTEXITCODE){throw "TID-MASH OOC failed: exit=$LASTEXITCODE"}; $row=Import-Csv (Join-Path $outDir 'summary.csv'); $row|Format-Table -AutoSize
if($row.Status -ne 'PASS'){throw "TID-MASH OOC timing failed: $($row.Status)"}
