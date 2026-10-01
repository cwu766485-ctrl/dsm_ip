param(
  [ValidateSet('thermo3','thermo5')][string]$Flavour = 'thermo3',
  [string]$Part = 'xczu15eg-ffvb1156-2-i',
  [double]$CoreMHz = 218.75,
  [double]$MinSaifCoveragePct = 5.0,
  [double]$MaxCoverageDeltaPct = 1.0,
  [string]$ReuseRunDir = '',
  [switch]$SkipActivity,
  [switch]$SkipBuild,
  [ValidateSet('continuous','burst','idle','tdd_sparse')][string[]]$Workloads = @('continuous','burst','idle'),
  [string]$VivadoBat = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$rootOut = if ($ReuseRunDir) {
  (Resolve-Path -LiteralPath $ReuseRunDir).Path
} else {
  Join-Path $repo "runs\lp_power_ab\${stamp}_${Flavour}"
}
New-Item -ItemType Directory -Force -Path $rootOut | Out-Null
$simScript = Join-Path $repo 'dv\verif\scripts\run_xsim_lp_power_activity.ps1'
$buildTcl = Join-Path $repo 'syn\build_tid32_thermo_power_project.tcl'
$powerTcl = Join-Path $repo 'syn\report_lp_power_from_dcp.tcl'
$modes = @('baseline','lp')

function Get-ResultFields([string]$Path) {
  $line = Get-Content -LiteralPath $Path | Select-Object -Last 1
  if ($line -notmatch 'sent=(\d+) outputs=(\d+) digest=([0-9a-fA-F]+) cycles=(\d+)') {
    throw "Malformed activity result: $Path"
  }
  [pscustomobject]@{
    Sent=[int]$Matches[1]; Outputs=[int]$Matches[2]
    Digest=$Matches[3].ToLowerInvariant(); Cycles=[int]$Matches[4]
  }
}

# Generate mode-specific SAIF with an identical useful transaction sequence.
foreach ($workload in $workloads) {
  foreach ($mode in $modes) {
    if (!$SkipActivity) {
      & powershell -NoProfile -ExecutionPolicy Bypass -File $simScript `
        -Flavour $Flavour -Mode $mode -Workload $workload
      if ($LASTEXITCODE -ne 0) { throw "activity simulation failed: $Flavour/$mode/$workload" }
    }
    $result = Join-Path $repo "runs\lp_power_activity\${Flavour}_${mode}_${workload}\result.txt"
    $saif = Join-Path $repo "runs\lp_power_activity\${Flavour}_${mode}_${workload}\${Flavour}_${mode}_${workload}.saif"
    if (!(Test-Path -LiteralPath $result) -or !(Test-Path -LiteralPath $saif)) {
      throw "activity artifacts missing: $Flavour/$mode/$workload"
    }
  }
  $b = Get-ResultFields (Join-Path $repo "runs\lp_power_activity\${Flavour}_baseline_${workload}\result.txt")
  $l = Get-ResultFields (Join-Path $repo "runs\lp_power_activity\${Flavour}_lp_${workload}\result.txt")
  if ($b.Sent -ne $l.Sent -or $b.Outputs -ne $l.Outputs -or
      $b.Digest -ne $l.Digest -or $b.Cycles -ne $l.Cycles) {
    throw "baseline/LP functional mismatch for $Flavour/$workload"
  }
}

# Implement each design once. Workload reports reopen a clean routed DCP so
# activity from one SAIF can never leak into the next report.
$designDcp = @{}
foreach ($mode in $modes) {
  $designOut = Join-Path $rootOut "design_${mode}"
  New-Item -ItemType Directory -Force -Path $designOut | Out-Null
  if (!$SkipBuild) {
    $log = Join-Path $designOut 'vivado.log'
    & $VivadoBat -mode batch -source $buildTcl -tclargs $repo $Part $CoreMHz $Flavour $mode $designOut *> $log
    if ($LASTEXITCODE -ne 0) { throw "$mode implementation failed; see $log" }
  }
  $dcp = Join-Path $designOut 'routed.dcp'
  if (!(Test-Path -LiteralPath $dcp)) { throw "routed DCP missing: $dcp" }
  $designDcp[$mode] = $dcp
}

$strip = "tb_tid32_${Flavour}_MODE_lp_power/u_tb"
$rows = @()
foreach ($workload in $workloads) {
  $power = @{}
  foreach ($mode in $modes) {
    $saif = Join-Path $repo "runs\lp_power_activity\${Flavour}_${mode}_${workload}\${Flavour}_${mode}_${workload}.saif"
    $report = Join-Path $rootOut "power_${mode}_${workload}.rpt"
    $log = Join-Path $rootOut "power_${mode}_${workload}.log"
    $modeStrip = $strip.Replace('MODE', $mode)
    & $VivadoBat -mode batch -source $powerTcl -tclargs $designDcp[$mode] $saif $modeStrip $report *> $log
    if ($LASTEXITCODE -ne 0) { throw "$mode/$workload power analysis failed; see $log" }
    $text = Get-Content -Raw -LiteralPath $report
    if ($text -notmatch '\| Dynamic \(W\)\s+\|\s+([0-9.]+)') { throw "dynamic power missing: $report" }
    $dynamic = [double]$Matches[1]
    if ($text -notmatch '\| Total On-Chip Power \(W\)\s+\|\s+([0-9.]+)') { throw "total power missing: $report" }
    $total = [double]$Matches[1]
    if ($text -notmatch '\| Design Nets Matched\s+\|\s+([^|]+)') {
      throw "SAIF coverage missing: $report"
    }
    $matchedText = $Matches[1].Trim()
    if ($matchedText -notmatch '([0-9]+(?:\.[0-9]+)?)\s*%') {
      throw "SAIF matched coverage is not a percentage: '$matchedText' in $report"
    }
    $coverage = [double]$Matches[1]
    if ($coverage -lt $MinSaifCoveragePct) {
      throw "SAIF coverage $coverage% is below required $MinSaifCoveragePct%: $report"
    }
    $power[$mode] = [pscustomobject]@{
      Dynamic=$dynamic; Total=$total; Matched=$matchedText; Coverage=$coverage
    }
  }
  $reduction = 100.0 * ($power.baseline.Dynamic - $power.lp.Dynamic) / $power.baseline.Dynamic
  $coverageDelta = [math]::Abs($power.baseline.Coverage - $power.lp.Coverage)
  if ($coverageDelta -gt $MaxCoverageDeltaPct) {
    throw "baseline/LP SAIF coverage differs by $coverageDelta percentage points for $Flavour/$workload"
  }
  $rows += [pscustomobject]@{
    Flavour=$Flavour; Workload=$workload
    Baseline_Dynamic_W=$power.baseline.Dynamic; LP_Dynamic_W=$power.lp.Dynamic
    Dynamic_Reduction_pct=[math]::Round($reduction,2)
    Baseline_Total_W=$power.baseline.Total; LP_Total_W=$power.lp.Total
    Baseline_Nets_Matched=$power.baseline.Matched; LP_Nets_Matched=$power.lp.Matched
    Baseline_SAIF_Coverage_pct=[math]::Round($power.baseline.Coverage,2)
    LP_SAIF_Coverage_pct=[math]::Round($power.lp.Coverage,2)
    SAIF_Coverage_Delta_pct=[math]::Round($coverageDelta,2)
    Confidence='Medium (RTL-SAIF direct match plus Vivado propagation)'
  }
}
$csv = Join-Path $rootOut 'power_comparison.csv'
$rows | Export-Csv -LiteralPath $csv -NoTypeInformation
$rows | Format-Table -AutoSize
Write-Host "LP_POWER_AB_COMPLETE=$csv"
