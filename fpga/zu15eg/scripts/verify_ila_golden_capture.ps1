[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CaptureCsv,
    [int]$PackageIndex = 0,
    [string]$Python = "py"
)

# Use the default Windows Python launcher when available. Supply an explicit
# python.exe path through -Python on hosts that do not install the launcher.

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$goldenDir = Join-Path $repo "fpga\zu15eg\out\ila_golden_memory_pkg$PackageIndex"
$generator = Join-Path $PSScriptRoot "generate_ila_golden.py"
$comparator = Join-Path $PSScriptRoot "compare_ila_golden.py"

Push-Location $repo
try {
    $pythonArgs = @()
    if ($Python -eq "py") { $pythonArgs += "-3" }
    & $Python @pythonArgs $generator --out-dir $goldenDir --package-index $PackageIndex
    if ($LASTEXITCODE -ne 0) { throw "ILA golden generation failed." }
    & $Python @pythonArgs $comparator $CaptureCsv --golden-dir $goldenDir
    if ($LASTEXITCODE -ne 0) { throw "ILA capture differs from the frozen golden trace." }
    Write-Host "BOARD_ILA_BITTRUE_PASS golden=$goldenDir capture=$CaptureCsv"
}
finally {
    Pop-Location
}
