param(
  [string]$RunDir,
  [string]$MetricsCsv,
  [string]$OutCsv
)

$ErrorActionPreference = "Stop"

if (-not $RunDir -or [string]::IsNullOrWhiteSpace($RunDir)) {
  $RunDir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path "verif\out_xsim_p0"
}
if (-not $OutCsv -or [string]::IsNullOrWhiteSpace($OutCsv)) {
  $OutCsv = Join-Path $RunDir "summary.csv"
}

$rows = @()

Get-ChildItem -Path $RunDir -Filter "summary_tb_*.csv" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
  $tb = Import-Csv $_.FullName
  foreach ($r in $tb) {
    $rows += [pscustomobject]@{
      Layer = "TB"
      Test = $r.Test
      Pass = [int]$r.Pass
      Detail = "samples=$($r.Samples); errors=$($r.Errors)"
    }
  }
}

if ($MetricsCsv -and -not [string]::IsNullOrWhiteSpace($MetricsCsv) -and (Test-Path -LiteralPath $MetricsCsv)) {
  $metricRows = Import-Csv $MetricsCsv
  $limits = @{
    "LPDSM"   = 6.0
    "LPDSM2"  = 6.0
    "EFDSM"   = 2.5
    "EFDSM2"  = 0.5
    "MASH11"  = 0.5
    "MASH111" = 0.5
    "MASH22"  = 0.7
  }
  foreach ($m in $metricRows) {
    $design = [string]$m.Design
    if (-not $limits.ContainsKey($design)) { continue }
    $evm = [double]$m.EVM_percent
    $sndr = [double]$m.SNDR_dB
    $pass = ($evm -le [double]$limits[$design]) -and ($sndr -ge 20.0)
    $rows += [pscustomobject]@{
      Layer = "METRIC"
      Test = $design
      Pass = [int]$pass
      Detail = ("EVM={0:N4}%; SNDR={1:N4}dB; limit={2:N3}%" -f $evm, $sndr, [double]$limits[$design])
    }
  }
}

if ($rows.Count -eq 0) {
  $rows += [pscustomobject]@{
    Layer = "REGRESSION"
    Test = "no_results"
    Pass = 0
    Detail = "no TB summaries or metrics found"
  }
}

$outDir = Split-Path -Parent $OutCsv
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$rows | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding ASCII

$failed = @($rows | Where-Object { [int]$_.Pass -ne 1 })
Write-Host "Regression summary: $OutCsv"
Write-Host "Rows=$($rows.Count), Failed=$($failed.Count)"
if ($failed.Count -gt 0) {
  $failed | Format-Table -AutoSize | Out-String | Write-Host
  exit 1
}
