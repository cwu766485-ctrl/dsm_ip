param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i",
  [int[]]$DataWidth = @(32,465),
  [string]$OutRoot = ""
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $VivadoBat)) { throw "Vivado executable not found: $VivadoBat" }
if ([string]::IsNullOrWhiteSpace($OutRoot)) { $OutRoot = Join-Path $PSScriptRoot 'out' }
$OutRoot = [System.IO.Path]::GetFullPath($OutRoot)
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
foreach ($width in $DataWidth) {
  if ($width -lt 1) { throw "DataWidth must be positive: $width" }
  $outDir = Join-Path $OutRoot "xpm_async_fifo_width_probe_$($Part.Replace('-','_'))_${width}b_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  & $VivadoBat -mode batch -source (Join-Path $PSScriptRoot 'run_ooc_xpm_async_fifo_width_probe.tcl') -tclargs $Part $width $outDir
  if ($LASTEXITCODE -ne 0) { throw "XPM FIFO width probe failed for ${width}b: exit=$LASTEXITCODE" }
  $summary = Join-Path $outDir 'summary.csv'
  if (!(Test-Path -LiteralPath $summary)) { throw "No summary.csv for ${width}b probe" }
  Import-Csv -LiteralPath $summary | Format-Table -AutoSize
}
