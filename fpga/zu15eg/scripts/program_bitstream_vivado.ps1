param(
    [string]$BitFile = ".\fpga\zu15eg\local_hw\pl_ps_gpio_test\pl_ps_gpio_test.runs\impl_1\top.bit",
    [string]$LtxFile = ".\fpga\zu15eg\local_hw\pl_ps_gpio_test\pl_ps_gpio_test.runs\impl_1\top.ltx",
    [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $VivadoBat)) {
    throw "Vivado executable not found: $VivadoBat"
}
if (-not (Test-Path -LiteralPath $BitFile)) {
    throw "Bitstream not found: $BitFile"
}

$script = Join-Path $PSScriptRoot "program_bitstream_vivado.tcl"
& $VivadoBat -mode batch -source $script -tclargs $BitFile $LtxFile
if ($LASTEXITCODE -ne 0) {
    throw "Vivado bitstream programming failed"
}
