param(
  [Parameter(Mandatory=$true)][string]$AlgorithmSummary,
  [Parameter(Mandatory=$true)][string]$OocSummary,
  [Parameter(Mandatory=$true)][string]$OutCsv
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $AlgorithmSummary)) { throw "Algorithm CSV missing: $AlgorithmSummary" }
if (!(Test-Path -LiteralPath $OocSummary)) { throw "OOC CSV missing: $OocSummary" }
$algorithm = Import-Csv -LiteralPath $AlgorithmSummary
$ooc = Import-Csv -LiteralPath $OocSummary
$rows = @()
foreach ($level in @(3,5)) {
  foreach ($interp in @(2,3,4)) {
    foreach ($dpd in @(1,2,4)) {
      $flavour = "thermo$level"
      $a = $algorithm | Where-Object {
        [int]$_.ThermoLevels -eq $level -and [int]$_.InterpTaps -eq $interp -and [int]$_.DPDMaxTaps -eq $dpd
      } | Select-Object -First 1
      $p = $ooc | Where-Object {
        $_.Flavour -eq $flavour -and [int]$_.InterpTaps -eq $interp -and [int]$_.DPDMaxTaps -eq $dpd
      } | Select-Object -First 1
      $rows += [pscustomobject]@{
        Flavour=$flavour; InterpTaps=$interp; DPDMaxTaps=$dpd; DPDMode='identity memory-poly: tap0=1, delayed=0'
        AlgorithmStatus=if($a){'COMPLETE'}else{'PENDING'}
        WorstEVM_percent=if($a){$a.WorstEVM_percent}else{$null}
        WorstSNDR_dB=if($a){$a.WorstSNDR_dB}else{$null}
        WorstPA_ACLR_dBc=if($a){$a.WorstPA_ACLR_dBc}else{$null}
        WorstFilteredACLR_dBc=if($a){$a.WorstFilteredACLR_dBc}else{$null}
        AllPass256QAM=if($a){$a.AllPass256QAM}else{$null}
        RawWordMismatches=if($a){$a.RawWordMismatches}else{$null}
        OOCStatus=if($p){$p.Status}else{'PENDING'}
        WNS_ns=if($p){$p.WNS_ns}else{$null}; WHS_ns=if($p){$p.WHS_ns}else{$null}
        LUT=if($p){$p.LUT}else{$null}; FF=if($p){$p.FF}else{$null}
        BRAM=if($p){$p.BRAM}else{$null}; DSP=if($p){$p.DSP}else{$null}
        OOCDirectory=if($p){$p.OOC_Directory}else{''}
      }
    }
  }
}
$outParent = Split-Path -Parent $OutCsv
if ($outParent) { New-Item -ItemType Directory -Force -Path $outParent | Out-Null }
$rows | Export-Csv -LiteralPath $OutCsv -NoTypeInformation
$rows | Format-Table -AutoSize
Write-Host "THERMO_SKU_UNIFIED_MATRIX=$OutCsv"
