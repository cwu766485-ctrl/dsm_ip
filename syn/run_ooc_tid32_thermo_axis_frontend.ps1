param(
  [ValidateSet('thermo3','thermo5')][string]$Flavour = 'thermo5',
  [string]$Part = 'xczu15eg-ffvb1156-2-i',
  [double]$CoreMHz = 218.75,
  [ValidateSet('quick','full')][string]$Implementation = 'quick',
  [string]$VivadoBat = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat',
  [switch]$Background
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (!(Test-Path -LiteralPath $VivadoBat)) { throw 'Vivado executable is unavailable.' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$out = Join-Path $repo "syn\out\tid32_${Flavour}_axis_frontend_${stamp}"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$tcl = Join-Path $repo 'syn\run_ooc_tid32_thermo_axis_frontend.tcl'
$log = Join-Path $out 'vivado.log'
if ($Background) {
  $stdout = Join-Path $out 'vivado.stdout.log'
  $stderr = Join-Path $out 'vivado.stderr.log'
  $proc = Start-Process -FilePath $VivadoBat -ArgumentList @('-mode','batch','-source',$tcl,'-tclargs',$Part,$CoreMHz,$Flavour,$out,$Implementation) `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
  $proc.Id | Set-Content -NoNewline (Join-Path $out 'vivado.pid')
  Write-Host "Started background $Flavour AXI frontend OOC: PID=$($proc.Id) log=$log"
  exit 0
}
& $VivadoBat -mode batch -source $tcl -tclargs $Part $CoreMHz $Flavour $out $Implementation *> $log
if ($LASTEXITCODE -ne 0) { throw "${Flavour} AXI frontend OOC failed: exit=$LASTEXITCODE; see $out\vivado.log" }
$summary = Join-Path $out 'summary.csv'
if (!(Test-Path -LiteralPath $summary)) { throw "${Flavour} AXI frontend OOC did not produce summary.csv" }
$row = Import-Csv -LiteralPath $summary
$row | Format-Table -AutoSize
if ($row.Status -ne 'PASS') { throw "${Flavour} AXI frontend timing failed: $($row.Status)" }
