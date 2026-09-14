param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i",
  [double]$TargetMHz = 218.75,
  [string]$OutRoot = ""
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $VivadoBat)) { throw "Vivado executable not found: $VivadoBat" }
if ([string]::IsNullOrWhiteSpace($OutRoot)) { $OutRoot = Join-Path $PSScriptRoot "reports" }
$OutRoot = [System.IO.Path]::GetFullPath($OutRoot)
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
$label = ("{0:F2}" -f $TargetMHz).Replace('.', 'p')
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = Join-Path $OutRoot "bp_ef2_map_compose8_ctx_pipe_ooc_$($Part.Replace('-','_').Replace('.','_'))_${label}mhz_$stamp"
$tcl = Join-Path $PSScriptRoot "run_ooc_bp_ef2_state_map_stage.tcl"
& $VivadoBat -mode batch -source $tcl -tclargs bp_ef2_state_map_compose8_ctx_pipe_ooc $Part $TargetMHz $outDir
if ($LASTEXITCODE -ne 0) { throw "Compose8 context-pipe OOC failed: exit=$LASTEXITCODE" }
$summary = Join-Path $outDir 'summary.csv'
if (-not (Test-Path -LiteralPath $summary)) { throw "No summary.csv was created" }
Import-Csv -LiteralPath $summary | Format-Table -AutoSize
