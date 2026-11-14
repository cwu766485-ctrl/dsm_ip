param(
  [string]$VivadoBat = 'D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat',
  [string]$OutRoot = '',
  [string]$Part = 'xczu15eg-ffvb1156-2-i',
  [string]$RouteDirective = 'Default',
  [switch]$SynthOnly
)

$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $VivadoBat)) { throw "Vivado is unavailable: $VivadoBat" }
if ($RouteDirective -notin @('Default','RuntimeOptimized','Quick')) {
  throw "Unsupported route directive: $RouteDirective"
}
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$gitExe = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if ([string]::IsNullOrWhiteSpace($gitExe) -and (Test-Path -LiteralPath 'D:\Git\cmd\git.exe')) {
  $gitExe = 'D:\Git\cmd\git.exe'
}
if ([string]::IsNullOrWhiteSpace($gitExe)) { throw 'Git for Windows was not found to record the source SHA.' }
$gitShaFile = Join-Path $env:TEMP "thermo5_vcu118_git_sha_$PID.txt"
$gitProcess = Start-Process -FilePath $gitExe -ArgumentList @('-C', $repo, 'rev-parse', 'HEAD') `
  -Wait -PassThru -NoNewWindow -RedirectStandardOutput $gitShaFile
$sourceCommit = (Get-Content -LiteralPath $gitShaFile -Raw).Trim()
Remove-Item -LiteralPath $gitShaFile
if ($gitProcess.ExitCode -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') {
  throw 'Unable to record the source commit SHA.'
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutRoot)) {
  $OutRoot = Join-Path $repo "runs\thermo5_vcu118_ab_ppa_$stamp"
} else {
  $OutRoot = [System.IO.Path]::GetFullPath($OutRoot)
  if (Test-Path -LiteralPath $OutRoot) { throw "Refusing to overwrite existing PPA directory: $OutRoot" }
}
New-Item -ItemType Directory -Path $OutRoot | Out-Null
$OutRoot = (Resolve-Path -LiteralPath $OutRoot).Path

$versionLog = Join-Path $OutRoot 'vivado_version.log'
$versionErr = Join-Path $OutRoot 'vivado_version.stderr.log'
$versionProcess = Start-Process -FilePath $VivadoBat -ArgumentList @('-version') -Wait -PassThru `
  -NoNewWindow -RedirectStandardOutput $versionLog -RedirectStandardError $versionErr
if (Test-Path -LiteralPath $versionErr) {
  Add-Content -LiteralPath $versionLog -Value (Get-Content -LiteralPath $versionErr)
  Remove-Item -LiteralPath $versionErr
}
$vivadoVersion = ((Get-Content -LiteralPath $versionLog -Raw) -split "`r?`n" |
  Where-Object { $_ -match 'Vivado v' } | Select-Object -First 1).Trim()
if ([string]::IsNullOrWhiteSpace($vivadoVersion)) { throw "Vivado version text missing (exit=$($versionProcess.ExitCode)); see $versionLog" }
$versionProbeExitCode = $versionProcess.ExitCode

$rows = @(
  @{ Name = 'A_causal_first'; Interpolation = 'causal'; TidOrder = 1 },
  @{ Name = 'B_cubic_first'; Interpolation = 'centered-cubic'; TidOrder = 1 },
  @{ Name = 'C_causal_ef2'; Interpolation = 'causal'; TidOrder = 2 },
  @{ Name = 'D_cubic_ef2'; Interpolation = 'centered-cubic'; TidOrder = 2 }
)
$oocRunner = Join-Path $PSScriptRoot 'run_ooc_thermo5_axil_control.ps1'
$routeTcl = Join-Path $PSScriptRoot 'route_ooc_thermo5_axil_from_checkpoint.tcl'
$scriptInputs = @($PSCommandPath, $oocRunner,
  (Join-Path $PSScriptRoot 'run_ooc_thermo5_axil_control.tcl'), $routeTcl)
$scriptHashes = @($scriptInputs | ForEach-Object {
  "$(Split-Path -Leaf $_)=$((Get-FileHash -Algorithm SHA256 -LiteralPath $_).Hash.ToLowerInvariant())"
}) -join ';'
$synthResults = @()

function Get-UtilizationValue([string]$Path, [string]$Metric) {
  if (!(Test-Path -LiteralPath $Path)) { return 'NA' }
  $content = Get-Content -LiteralPath $Path -Raw
  $pattern = '(?m)^\|\s*' + [regex]::Escape($Metric) + '\*?\s*\|\s*([\d,]+(?:\.\d+)?)'
  $match = [regex]::Match($content, $pattern)
  if (!$match.Success) { return 'NA' }
  return [double](($match.Groups[1].Value -replace ',', ''))
}

function Get-PowerValue([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) { return 'NA' }
  $content = Get-Content -LiteralPath $Path -Raw
  $match = [regex]::Match($content, '(?m)^\|\s*Total On-Chip Power \(W\)\s*\|\s*([\d.]+)')
  if (!$match.Success) { return 'NA' }
  return [double]$match.Groups[1].Value
}

function Write-ComparisonAndSummary($Items, [string]$Root, [string]$Mode, [string]$Commit, [string]$Version, [string]$TargetPart) {
  $comparison = @()
  foreach ($item in $Items) {
    $synthUtil = $item.Utilization
    $routeUtil = $item.RoutedUtilization
    $synthSummary = if (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $item.Configuration) 'synth_summary.csv')) {
      Import-Csv -LiteralPath (Join-Path (Split-Path -Parent $item.Configuration) 'synth_summary.csv')
    } else { $null }
    $routeSummaryPath = Join-Path (Split-Path -Parent $item.RouteLog) 'summary.csv'
    $routeSummary = if ($item.RouteStatus -ne 'NOT_RUN' -and (Test-Path -LiteralPath $routeSummaryPath)) {
      Import-Csv -LiteralPath $routeSummaryPath
    } else { $null }
    $comparison += [pscustomobject]@{
      Case = $item.Case
      Interpolation = $item.Interpolation
      TIDSM_Order = $item.TIDSM_Order
      Synth_LUT = Get-UtilizationValue $synthUtil 'CLB LUTs'
      Synth_FF = Get-UtilizationValue $synthUtil 'CLB Registers'
      Synth_DSP48 = Get-UtilizationValue $synthUtil 'DSPs'
      Synth_BRAM_Tiles = Get-UtilizationValue $synthUtil 'Block RAM Tile'
      Synth_URAM = Get-UtilizationValue $synthUtil 'URAM'
      Synth_WNS_ns = if ($synthSummary) { $synthSummary.Synthesis_WNS_ns } else { 'NA' }
      Synth_WHS_ns = if ($synthSummary) { $synthSummary.Synthesis_WHS_ns } else { 'NA' }
      Route_Status = $item.RouteStatus
      Routed_LUT = Get-UtilizationValue $routeUtil 'CLB LUTs'
      Routed_FF = Get-UtilizationValue $routeUtil 'CLB Registers'
      Routed_DSP48 = Get-UtilizationValue $routeUtil 'DSPs'
      Routed_BRAM_Tiles = Get-UtilizationValue $routeUtil 'Block RAM Tile'
      Routed_URAM = Get-UtilizationValue $routeUtil 'URAM'
      Routed_WNS_ns = if ($routeSummary) { $routeSummary.WNS_ns } else { 'NA' }
      Routed_WHS_ns = if ($routeSummary) { $routeSummary.WHS_ns } else { 'NA' }
      Power_Method = if ($item.PowerReport -and (Test-Path -LiteralPath $item.PowerReport)) { 'VECTORLESS_NO_SAIF' } else { 'NOT_RUN' }
      Power_Total_W = Get-PowerValue $item.PowerReport
      Power_Report = $item.PowerReport
      Worst_Timing_Path = if ($item.RouteStatus -ne 'NOT_RUN') { $item.RoutedTimingPaths } else { $item.TimingPaths }
      Unconstrained_Report = $item.UnconstrainedPaths
      Synthesis_Log = $item.SynthesisLog
      Route_Log = $item.RouteLog
    }
  }
  $comparisonPath = Join-Path $Root 'ab_ppa_comparison.csv'
  $comparison | Export-Csv -NoTypeInformation -LiteralPath $comparisonPath
  $resourceMetrics = @('LUT','FF','DSP48','BRAM_Tiles','URAM')
  $deltas = @()
  foreach ($metric in $resourceMetrics) {
    $column = "Routed_$metric"
    if ($Mode -eq 'SYNTH_ONLY') { $column = "Synth_$metric" }
    foreach ($pair in @(@('B_cubic_first','A_causal_first'),@('D_cubic_ef2','C_causal_ef2'),
      @('C_causal_ef2','A_causal_first'),@('D_cubic_ef2','B_cubic_first'))) {
      $left = $comparison | Where-Object Case -eq $pair[0] | Select-Object -First 1
      $right = $comparison | Where-Object Case -eq $pair[1] | Select-Object -First 1
      if ($left -and $right) {
        $leftValue = 0.0
        $rightValue = 0.0
        if ([double]::TryParse([string]$left.$column, [ref]$leftValue) -and
            [double]::TryParse([string]$right.$column, [ref]$rightValue)) {
          $deltas += [pscustomobject]@{ Metric=$metric; Change="$($pair[0]) minus $($pair[1])"; Delta=($leftValue - $rightValue) }
        }
      }
    }
  }
  $markdown = @(
    '# Thermo5 VCU118 A/B PPA'
    ''
    "- Status: $Mode"
    "- Source commit: ``$Commit``"
    "- Vivado: $Version"
    "- Part: ``$TargetPart``"
    '- Top: ``tid32_thermo5_axi_lite_axis_frontend_tx``'
    '- Clocks: Source 125 MHz; Core 218.75 MHz; AXI-Lite 100 MHz'
    '- Matched generics: INTERP_TAPS=2, DPD_MAX_TAPS=1, FPGA_USE_XPM_FIFO=1, STEP=5120'
    '- Synthesis: OOC, AreaOptimized_high; routing: Default'
    '- Synth WNS is a synthesis timing estimate. Routed WNS/WHS are the implementation timing results; no estimated Fmax is presented as routed Fmax.'
    ''
    '## Results'
    ''
    '| Case | Interpolation | TIDSM | LUT | FF | DSP48 | BRAM tiles | URAM | Synth WNS ns | Route status | Routed WNS ns | Routed WHS ns | Power W |'
    '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |'
  )
  foreach ($r in $comparison) {
    $metricPrefix = if ($Mode -eq 'ROUTED') { 'Routed' } else { 'Synth' }
    $markdown += "| $($r.Case) | $($r.Interpolation) | $($r.TIDSM_Order) | $($r.($metricPrefix + '_LUT')) | $($r.($metricPrefix + '_FF')) | $($r.($metricPrefix + '_DSP48')) | $($r.($metricPrefix + '_BRAM_Tiles')) | $($r.($metricPrefix + '_URAM')) | $($r.Synth_WNS_ns) | $($r.Route_Status) | $($r.Routed_WNS_ns) | $($r.Routed_WHS_ns) | $($r.Power_Total_W) ($($r.Power_Method)) |"
  }
  $markdown += @(
    ''
    'Matched resource deltas are listed below; negative values mean the first listed case uses fewer resources.'
    ''
    '## Model Context'
    ''
    'Prior held-out Python QAM256 model evidence (four disjoint seeds, 224,256 uncoded bits per cell; not FPGA measurements):'
    ''
    '| Case | Mean EVM | Mean SNDR | Uncoded BER |'
    '| --- | ---: | ---: | ---: |'
    '| A causal + first-order | 20.915% | 13.591 dB | 0.215272 |'
    '| B centered-cubic + first-order | 3.443% | 29.261 dB | 0.004223 |'
    '| C causal + EF2 | 20.824% | 13.629 dB | 0.214598 |'
    '| D centered-cubic + EF2 | 2.464% | 32.168 dB | 9.3643e-5 |'
    ''
    'Model results are from ``docs/verification/thermo5-tx-design-ablation.md`` and are not physical BER or a product-limit signoff. Power, when present, is Vivado vectorless without SAIF and is not measured workload power.'
    ''
    '## Logs and Reports'
    ''
    '- Machine-readable artifact manifest: ``ab_ppa_manifest.csv``'
    '- Machine-readable comparison: ``ab_ppa_comparison.csv``'
  )
  if ($deltas.Count -gt 0) {
    $markdown += @('', '## Matched Resource Deltas', '', '| Metric | Pair (first minus second) | Delta |', '| --- | --- | ---: |')
    foreach ($delta in $deltas) { $markdown += "| $($delta.Metric) | $($delta.Change) | $($delta.Delta) |" }
  }
  $markdown | Set-Content -LiteralPath (Join-Path $Root 'ab_ppa_summary.md')
}

foreach ($row in $rows) {
  $dir = Join-Path $OutRoot $row.Name
  $log = Join-Path $OutRoot "$($row.Name)_synth.log"
  $status = 'SYNTH_FAIL'
  $failure = ''
  try {
    & $oocRunner -Implementation synth -Part $Part -SourceMHz 125 -CoreMHz 218.75 -AxilMHz 100 `
      -OutDir $dir -VivadoBat $VivadoBat -Interpolation $row.Interpolation `
      -TidOrder $row.TidOrder -Step 5120 -DpdMaxTaps 1 -UseXpmFifo 1 *> $log
    $dcp = Join-Path $dir 'synthesized.dcp'
    $config = Join-Path $dir 'elaborated_configuration.txt'
    $timingReports = @('synth_timing_summary.rpt', 'synth_timing_paths.rpt',
      'synth_unconstrained_paths.rpt', 'synth_check_timing.rpt')
    if (!(Test-Path -LiteralPath $dcp) -or !(Test-Path -LiteralPath $config) -or
        @($timingReports | Where-Object { !(Test-Path -LiteralPath (Join-Path $dir $_)) }).Count -gt 0) {
      throw "Synthesis artifacts are incomplete for $($row.Name)"
    }
    $configText = Get-Content -LiteralPath $config -Raw
    foreach ($expected in @("PART=$Part", 'INTERP_TAPS=2', 'DPD_MAX_TAPS=1',
      'FPGA_USE_XPM_FIFO=1', "INTERP_CENTERED_CUBIC=$(if ($row.Interpolation -eq 'centered-cubic') { 1 } else { 0 })",
      "TIDSM_ORDER=$($row.TidOrder)", 'STEP=5120')) {
      if ($configText -notmatch [regex]::Escape($expected)) { throw "Elaborated configuration missing '$expected' for $($row.Name)" }
    }
    $status = 'SYNTH_PASS'
  } catch {
    $failure = $_.Exception.Message
    Add-Content -LiteralPath $log -Value "SYNTH_FAILURE=$failure"
  }
  $synthResults += [pscustomobject]@{
    Case = $row.Name
    Interpolation = $row.Interpolation
    TIDSM_Order = $row.TidOrder
    Part = $Part
    Source_MHz = 125
    Core_MHz = 218.75
    AXIL_MHz = 100
    Interp_Taps = 2
    DPD_Max_Taps = 1
    FIFO = 'XPM'
    STEP = 5120
    SourceCommit = $sourceCommit
    FlowScriptSHA256 = $scriptHashes
    VivadoVersion = $vivadoVersion
    VivadoVersionProbeExitCode = $versionProbeExitCode
    SynthesisStatus = $status
    Checkpoint = Join-Path $dir 'synthesized.dcp'
    Configuration = Join-Path $dir 'elaborated_configuration.txt'
    Utilization = Join-Path $dir 'synth_utilization.rpt'
    TimingSummary = Join-Path $dir 'synth_timing_summary.rpt'
    TimingPaths = Join-Path $dir 'synth_timing_paths.rpt'
    UnconstrainedPaths = Join-Path $dir 'synth_unconstrained_paths.rpt'
    CheckTiming = Join-Path $dir 'synth_check_timing.rpt'
    SynthesisLog = $log
    SynthesisFailure = $failure
    RouteStatus = 'NOT_RUN'
    RouteLog = ''
    RoutedCheckpoint = ''
    RoutedUtilization = ''
    RoutedTimingSummary = ''
    RoutedTimingPaths = ''
    RouteStatusReport = ''
    PowerReport = ''
  }
}

$manifestPath = Join-Path $OutRoot 'ab_ppa_manifest.csv'
$synthResults | Export-Csv -NoTypeInformation -LiteralPath $manifestPath
if (@($synthResults | Where-Object { $_.SynthesisStatus -ne 'SYNTH_PASS' }).Count -gt 0) {
  Write-ComparisonAndSummary $synthResults $OutRoot 'SYNTH_FAILURE' $sourceCommit $vivadoVersion $Part
  Write-Host "THERMO5_AB_SYNTH_FAILURE manifest=$manifestPath"
  exit 1
}
if ($SynthOnly) {
  Write-ComparisonAndSummary $synthResults $OutRoot 'SYNTH_ONLY' $sourceCommit $vivadoVersion $Part
  Write-Host "THERMO5_AB_SYNTH_ONLY_PASS part=$Part manifest=$manifestPath"
  exit 0
}

Write-Host 'THERMO5_AB_ALL_SYNTH_PASS; starting matched checkpoint routes.'
for ($index = 0; $index -lt $synthResults.Count; $index++) {
  $item = $synthResults[$index]
  $routeDir = Join-Path $OutRoot "$($item.Case)_route"
  New-Item -ItemType Directory -Path $routeDir | Out-Null
  $log = Join-Path $routeDir 'vivado_route.log'
  $stderr = Join-Path $routeDir 'vivado_route.stderr.log'
  $routeArgs = @('-mode','batch','-source',$routeTcl,'-tclargs',$item.Checkpoint,
    $routeDir,'synth',$RouteDirective)
  $routeStatus = 'ROUTE_TOOL_FAIL'
  try {
    $process = Start-Process -FilePath $VivadoBat -ArgumentList $routeArgs -Wait -PassThru `
      -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError $stderr
    if (Test-Path -LiteralPath $stderr) {
      Add-Content -LiteralPath $log -Value (Get-Content -LiteralPath $stderr)
      Remove-Item -LiteralPath $stderr
    }
    if ($process.ExitCode -eq 0 -and (Test-Path -LiteralPath (Join-Path $routeDir 'summary.csv'))) {
      $routeStatus = (Import-Csv -LiteralPath (Join-Path $routeDir 'summary.csv')).Status
    } elseif ($process.ExitCode -eq 0) {
      $routeStatus = 'ROUTE_REPORT_MISSING'
    }
  } catch {
    Add-Content -LiteralPath $log -Value "ROUTE_FAILURE=$($_.Exception.Message)"
  }
  $synthResults[$index].RouteStatus = $routeStatus
  $synthResults[$index].RouteLog = $log
  $synthResults[$index].RoutedCheckpoint = Join-Path $routeDir 'routed.dcp'
  $synthResults[$index].RoutedUtilization = Join-Path $routeDir 'utilization.rpt'
  $synthResults[$index].RoutedTimingSummary = Join-Path $routeDir 'timing_summary.rpt'
  $synthResults[$index].RoutedTimingPaths = Join-Path $routeDir 'timing_max_paths.rpt'
  $synthResults[$index].RouteStatusReport = Join-Path $routeDir 'route_status.rpt'
  $synthResults[$index].PowerReport = Join-Path $routeDir 'vectorless_power.rpt'
}
$synthResults | Export-Csv -NoTypeInformation -LiteralPath $manifestPath
Write-ComparisonAndSummary $synthResults $OutRoot 'ROUTED' $sourceCommit $vivadoVersion $Part
Write-Host "THERMO5_AB_RUN_COMPLETE manifest=$manifestPath"
