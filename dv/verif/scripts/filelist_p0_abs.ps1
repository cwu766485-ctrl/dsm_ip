param(
  [Parameter(Mandatory = $true)][string]$RepoRoot,
  [Parameter(Mandatory = $true)][string]$OutFile
)

$ErrorActionPreference = "Stop"
$rtlRoot = Join-Path $RepoRoot "rtl"

# Sources shared by the scalar low-pass DSM regression tops and their P0
# compatibility harness. Keep this list intentionally independent of the
# product-transmitter RTL that is not part of this algorithm-study branch.
$relativeSources = @(
  "mem\rom_reader.sv",
  "dsm\singlebit\dsm_core.sv",
  "dsm\singlebit\dsm_core_dsm2.sv",
  "dsm\singlebit\dsm_core_ef1.sv",
  "dsm\singlebit\dsm_core_ef2.sv",
  "dsm\singlebit\dsm_core_mash11.sv",
  "dsm\singlebit\dsm_core_mash111.sv",
  "dsm\singlebit\dsm_core_mash22.sv",
  "dsm\multibit\dsm_core_multibit.sv",
  "duc\duc_fs4_merge.sv",
  "duc\duc_fs4_merge_signed.sv",
  "duc\duc_nco_mix_signed.v",
  "top\p0_top_lp1.v",
  "top\p0_top_lp2.v",
  "top\p0_top_ef1.v",
  "top\p0_top_ef2.v",
  "top\p0_top_mash11_mb.v",
  "top\p0_top_mash111_mb.v",
  "top\p0_top_mash22_mb.v"
)

$sources = foreach ($relativePath in $relativeSources) {
  $path = Join-Path $rtlRoot $relativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Required DSM source is missing: $path"
  }
  (Resolve-Path -LiteralPath $path).Path
}

$parent = Split-Path -Parent $OutFile
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
Set-Content -LiteralPath $OutFile -Value ($sources -join "`r`n") -Encoding ASCII
