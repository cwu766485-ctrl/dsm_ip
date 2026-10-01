param(
  [ValidateSet('thermo3','thermo5')][string[]]$Flavours = @('thermo3','thermo5'),
  [ValidateSet(2,3,4)][int[]]$InterpTaps = @(2,3,4),
  [ValidateSet(1,2,4)][int[]]$DpdTaps = @(1,2,4),
  [string]$Part = 'xczu15eg-ffvb1156-2-i',
  [double]$CoreMHz = 218.75,
  [string]$OutDir = '',
  [string]$VivadoBat = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$root = if ([string]::IsNullOrWhiteSpace($OutDir)) {
  Join-Path $repo "runs\thermo_sku_matrix\$stamp"
} else { [System.IO.Path]::GetFullPath($OutDir) }
New-Item -ItemType Directory -Force -Path $root | Out-Null
$runner = Join-Path $repo 'syn\run_ooc_tid32_thermo_axis_frontend.ps1'

function Get-Utilization([string]$Report) {
  $text = Get-Content -Raw -LiteralPath $Report
  function Parse-Row([string]$Label) {
    $m = [regex]::Match($text,"(?m)^\|\s*$Label\s*\|\s*([0-9.]+)")
    if (!$m.Success) { return $null }
    return [double]$m.Groups[1].Value
  }
  [pscustomobject]@{
    LUT = Parse-Row 'CLB LUTs'
    FF = Parse-Row 'CLB Registers'
    BRAM = Parse-Row 'Block RAM Tile'
    DSP = Parse-Row 'DSPs'
  }
}

$rows = @()
function Write-Matrix([object[]]$CurrentRows, [string]$Path) {
  $CurrentRows | Export-Csv -LiteralPath $Path -NoTypeInformation
}
foreach ($flavour in $Flavours) {
  foreach ($interp in $InterpTaps) {
    foreach ($dpd in $DpdTaps) {
      $sku = "${flavour}_i${interp}_d${dpd}_a${dpd}"
      $skuOut = Join-Path $root $sku
      Write-Host "=== OOC $sku ==="
      & powershell -NoProfile -ExecutionPolicy Bypass -File $runner `
        -Flavour $flavour -Part $Part -CoreMHz $CoreMHz -Implementation full `
        -InterpTaps $interp -DpdMaxTaps $dpd -DpdActiveTaps $dpd `
        -CompileTimeDpdTaps -OutDir $skuOut -VivadoBat $VivadoBat
      $exit = $LASTEXITCODE
      $summary = Join-Path $skuOut 'summary.csv'
      if ((Test-Path -LiteralPath $summary)) {
        $timing = Import-Csv -LiteralPath $summary | Select-Object -First 1
        $util = Get-Utilization (Join-Path $skuOut 'utilization.rpt')
        $rows += [pscustomobject]@{
          Flavour=$flavour; InterpTaps=$interp; DPDMaxTaps=$dpd; DPDActiveTaps=$dpd
          Status=$timing.Status; WNS_ns=[double]$timing.WNS_ns; WHS_ns=[double]$timing.WHS_ns
          LUT=$util.LUT; FF=$util.FF; BRAM=$util.BRAM; DSP=$util.DSP
          OOC_Directory=$skuOut; ExitCode=$exit
        }
      } else {
        $rows += [pscustomobject]@{
          Flavour=$flavour; InterpTaps=$interp; DPDMaxTaps=$dpd; DPDActiveTaps=$dpd
          Status='NO_SUMMARY'; WNS_ns=$null; WHS_ns=$null; LUT=$null; FF=$null; BRAM=$null; DSP=$null
          OOC_Directory=$skuOut; ExitCode=$exit
        }
      }
      # Preserve completed rows if a later full route is interrupted.  This is
      # an evidence ledger, not a cache: a row is emitted only after its own
      # routed report has been read.
      Write-Matrix $rows (Join-Path $root 'thermo_sku_ooc_summary.csv')
    }
  }
}
$csv = Join-Path $root 'thermo_sku_ooc_summary.csv'
Write-Matrix $rows $csv
$rows | Format-Table -AutoSize
Write-Host "THERMO_SKU_OOC_MATRIX=$csv"
