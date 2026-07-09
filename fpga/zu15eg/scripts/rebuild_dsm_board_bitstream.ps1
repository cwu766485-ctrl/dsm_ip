param(
    [string]$Project = ".\fpga\zu15eg\local_hw\pl_ps_gpio_test\pl_ps_gpio_test.xpr",
    [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $VivadoBat)) {
    throw "Vivado executable not found: $VivadoBat"
}

if (-not (Test-Path -LiteralPath $Project)) {
    throw "Vivado project not found: $Project"
}

$script = Join-Path $PSScriptRoot "rebuild_dsm_board_bitstream.tcl"
& $VivadoBat -mode batch -source $script -tclargs $Project
if ($LASTEXITCODE -ne 0) {
    throw "ZU15EG DSM board bitstream rebuild failed"
}
