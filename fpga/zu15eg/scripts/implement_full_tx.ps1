param(
    [string]$Project = ".\fpga\zu15eg\local_hw\pl_ps_gpio_test\pl_ps_gpio_test.xpr",
    [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$projectPath = (Resolve-Path (Join-Path $repoRoot $Project)).Path
$scriptPath = Join-Path $PSScriptRoot "implement_full_tx.tcl"

if (-not (Test-Path -LiteralPath $VivadoBat)) {
    throw "Vivado executable not found: $VivadoBat"
}

& $VivadoBat -mode batch -source $scriptPath -tclargs $projectPath
if ($LASTEXITCODE -ne 0) {
    throw "ZU15EG full-TX routed implementation failed."
}
