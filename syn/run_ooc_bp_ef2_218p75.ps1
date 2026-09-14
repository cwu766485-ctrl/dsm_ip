param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $VivadoBat)) {
  throw "Vivado executable not found: $VivadoBat"
}

$script = Join-Path $PSScriptRoot "run_ooc_bp_ef2_axi.tcl"
$target = 218.75
Write-Host "=== BP EFDSM2 single-lane OOC: $target MHz ==="
& $VivadoBat -mode batch -source $script -tclargs $Part $target
$vivadoExit = $LASTEXITCODE

$targetLabel = "218p75"
$latest = Get-ChildItem (Join-Path $PSScriptRoot "reports") -Directory `
  -Filter "bp_ef2_axi_ooc_*_${targetLabel}mhz_*" |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $latest) {
  throw "No OOC output directory was created. Vivado exit code: $vivadoExit"
}

$summary = Join-Path $latest.FullName "summary.csv"
if (-not (Test-Path -LiteralPath $summary)) {
  throw "No summary.csv was created. Vivado exit code: $vivadoExit; output: $($latest.FullName)"
}

$row = Import-Csv -LiteralPath $summary
Write-Host "218.75 MHz OOC summary: $summary"
if ($vivadoExit -ne 0 -or $row.Status -ne "PASS") {
  throw "218.75 MHz OOC did not pass: status=$($row.Status), Vivado exit=$vivadoExit"
}
Write-Host "218.75 MHz OOC PASS: WNS=$($row.WNS_ns) ns, Fmax=$($row.Fmax_est_MHz) MHz"
