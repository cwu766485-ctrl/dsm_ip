param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i",
  [string[]]$TargetMHz = @("150", "175", "200", "225", "250")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $VivadoBat)) {
  throw "Vivado executable not found: $VivadoBat"
}
$targets = @()
foreach ($target in $TargetMHz) {
  foreach ($item in ($target -split ',')) {
    $trimmed = $item.Trim()
    if ($trimmed.Length -eq 0) { continue }
    try {
      $mhz = [double]::Parse(
        $trimmed,
        [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
      throw "TargetMHz contains an invalid frequency: '$trimmed'."
    }
    $targets += $mhz
  }
}
if ($targets.Count -eq 0 -or ($targets | Where-Object { $_ -le 0 }).Count -ne 0) {
  throw "TargetMHz must contain one or more positive clock frequencies."
}

$script = Join-Path $PSScriptRoot "run_ooc_bp_ef2_axi.tcl"
$rows = @()
$failures = @()
foreach ($MHz in $targets) {
  Write-Host "=== BP EFDSM2 single-lane OOC: $MHz MHz ==="
  & $VivadoBat -mode batch -source $script -tclargs $Part $MHz
  $vivadoExit = $LASTEXITCODE

  $targetLabel = ("{0:F2}" -f $MHz).Replace('.', 'p')
  $latest = Get-ChildItem (Join-Path $PSScriptRoot "reports") -Directory -Filter "bp_ef2_axi_ooc_*_${targetLabel}mhz_*" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($null -eq $latest) {
    throw "BP EFDSM2 AXI OOC did not create an output directory at $MHz MHz."
  }
  $summary = Join-Path $latest.FullName "summary.csv"
  if (-not (Test-Path -LiteralPath $summary)) {
    throw "Missing OOC summary for $MHz MHz: $summary"
  }
  $row = Import-Csv -LiteralPath $summary
  $rows += $row
  if ($vivadoExit -ne 0 -or $row.Status -ne "PASS") {
    $failures += "$MHz MHz ($($row.Status), Vivado exit $vivadoExit)"
  }
}

$outDir = Join-Path $PSScriptRoot "reports"
$matrix = Join-Path $outDir "bp_ef2_axi_single_lane_zu15eg_sweep.csv"
$rows | Sort-Object {[double]$_.Target_MHz} | Export-Csv -NoTypeInformation -LiteralPath $matrix
Write-Host "Single-lane sweep summary: $matrix"
if ($failures.Count -ne 0) {
  throw "One or more target frequencies did not meet timing: $($failures -join '; ')"
}
