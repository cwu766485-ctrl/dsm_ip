param(
    [string]$XsaWorkspace = ".\fpga\zu15eg\out\vitis_baremetal",
    [string]$OutDir = ".\fpga\zu15eg\out\vitis_baremetal_direct",
    [int]$WaveformQam = 16,
    [int]$WaveformUsedSubcarriers = 48,
    [double]$WaveformInputBackoff = 0.58,
    [int]$WaveformFftSize = 256,
    [int]$WaveformSeed = 1,
    [string[]]$Define = @()
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")
$bsp = Resolve-Path (Join-Path $repoRoot "$XsaWorkspace\dsm_zu15eg_platform\psu_cortexa53_0\standalone_a53_0\bsp")
$outPath = if ([System.IO.Path]::IsPathRooted($OutDir)) {
    $OutDir
} else {
    Join-Path $repoRoot $OutDir
}
$srcDir = Join-Path $repoRoot "fpga\zu15eg\baremetal\src"
$gcc = "D:\Xilinx\Vitis\2024.1\gnu\aarch64\nt\aarch64-none\bin\aarch64-none-elf-gcc.exe"
$size = "D:\Xilinx\Vitis\2024.1\gnu\aarch64\nt\aarch64-none\bin\aarch64-none-elf-size.exe"

if (!(Test-Path $gcc)) { throw "A53 GCC was not found: $gcc" }

$waveformGenerator = Join-Path $repoRoot "fpga\zu15eg\scripts\generate_dpd_tx_waveform.py"
$waveformHeader = Join-Path $srcDir "dpd_tx_waveform.h"
& python $waveformGenerator --qam $WaveformQam --used-subcarriers $WaveformUsedSubcarriers `
    --input-backoff $WaveformInputBackoff --fft-size $WaveformFftSize --seed $WaveformSeed `
    --header $waveformHeader
if ($LASTEXITCODE -ne 0) { throw "DPD TX waveform generation failed with exit code $LASTEXITCODE" }

New-Item -ItemType Directory -Force -Path $outPath | Out-Null
$linkerScript = Join-Path $outPath "lscript.ld"
Copy-Item "D:\Xilinx\Vitis\2024.1\data\embeddedsw\lib\sw_apps\imgsel\src\zynqmp\lscript.ld" $linkerScript -Force
$linkerText = Get-Content -Raw $linkerScript
$linkerText = $linkerText.Replace("psu_ddr_0_MEM_0 : ORIGIN = 0x0, LENGTH = 0x7FF00000", "psu_ddr_0_MEM_0 : ORIGIN = 0x00100000, LENGTH = 0x7FE00000")
$linkerText = $linkerText.Replace("> psu_ocm_ram_0_MEM_0", "> psu_ddr_0_MEM_0")
Set-Content -LiteralPath $linkerScript -Value $linkerText -Encoding ascii

$commonArgs = @(
    "-DSDT", "-DARMA53_64", "-DCAL_USE_SOFTWARE_SEED=0",
    "-march=armv8-a", "-mlittle-endian", "-mabi=lp64", "-O2",
    "-ffunction-sections", "-fdata-sections",
    "-I", (Join-Path $bsp "include"),
    "-I", (Join-Path $bsp "libsrc\axidma\src"),
    "-I", (Join-Path $bsp "libsrc\build_configs\gen_bsp\include"),
    "-I", (Join-Path $bsp "libsrc\standalone\src\common"),
    "-I", (Join-Path $bsp "libsrc\standalone\src\arm\ARMv8\64bit"),
    "-I", $srcDir
)
foreach ($item in $Define) {
    if (-not [string]::IsNullOrWhiteSpace($item)) {
        $commonArgs += "-D$item"
    }
}

& $gcc @commonArgs "-c" (Join-Path $srcDir "dsm_dpd_baremetal_smoke.c") "-o" (Join-Path $outPath "app.o")
if ($LASTEXITCODE -ne 0) { throw "A53 application compile failed with exit code $LASTEXITCODE" }
& $gcc @commonArgs "-c" (Join-Path $srcDir "dpd_tinyml_tree.c") "-o" (Join-Path $outPath "dpd_tinyml_tree.o")
if ($LASTEXITCODE -ne 0) { throw "A53 TinyML tree compile failed with exit code $LASTEXITCODE" }
& $gcc @commonArgs "-c" (Join-Path $srcDir "dpd_tinyml_features.c") "-o" (Join-Path $outPath "dpd_tinyml_features.o")
if ($LASTEXITCODE -ne 0) { throw "A53 TinyML feature compile failed with exit code $LASTEXITCODE" }
& $gcc @commonArgs "-c" (Join-Path $srcDir "dpd_safety_seed_policy.c") "-o" (Join-Path $outPath "dpd_safety_seed_policy.o")
if ($LASTEXITCODE -ne 0) { throw "A53 safety seed policy compile failed with exit code $LASTEXITCODE" }

$asmBase = Join-Path $bsp "libsrc\standalone\src\arm\ARMv8\64bit"
foreach ($source in @("gcc\asm_vectors.S", "gcc\boot.S", "gcc\xil-crt0.S", "platform\ZynqMP\gcc\translation_table.S")) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($source)
    & $gcc @commonArgs "-x" "assembler-with-cpp" "-c" (Join-Path $asmBase $source) "-o" (Join-Path $outPath "$name.o")
    if ($LASTEXITCODE -ne 0) { throw "A53 startup compile failed for $source" }
}

$elf = Join-Path $outPath "dsm_dpd_baremetal_smoke.elf"
$bspLib = Join-Path $bsp "lib"
$runtimeSearchArgs = @("-L$bspLib")
$runtimeLibs = @("-lxil", "-lc", "-lgcc")
if (Test-Path (Join-Path $bspLib "libxilstandalone.a")) {
    $runtimeLibs = @("-lxil", "-lxilstandalone", "-lxil", "-lc", "-lgcc")
} else {
    $platformRoot = Resolve-Path (Join-Path $bsp "..\..\..")
    $fsblRuntime = Join-Path $platformRoot "zynqmp_fsbl\zynqmp_fsbl_bsp\lib"
    if (Test-Path (Join-Path $fsblRuntime "libxilstandalone.a")) {
        $runtimeSearchArgs += "-L$fsblRuntime"
        $runtimeLibs = @("-lxil", "-lxilstandalone", "-lxil", "-lc", "-lgcc")
    }
}
& $gcc "-march=armv8-a" "-mlittle-endian" "-mabi=lp64" `
    ("-specs=" + (Join-Path $bsp "Xilinx.spec")) `
    ("-T" + $linkerScript) "-Wl,--gc-sections" `
    ("-Wl,-Map," + (Join-Path $outPath "dsm_dpd_baremetal_smoke.map")) `
    "-o" $elf `
    (Join-Path $outPath "asm_vectors.o") (Join-Path $outPath "boot.o") `
    (Join-Path $outPath "xil-crt0.o") (Join-Path $outPath "translation_table.o") `
    (Join-Path $outPath "app.o") (Join-Path $outPath "dpd_tinyml_tree.o") `
    (Join-Path $outPath "dpd_tinyml_features.o") (Join-Path $outPath "dpd_safety_seed_policy.o") @runtimeSearchArgs `
    "-Wl,--start-group" @runtimeLibs "-Wl,--end-group"
if ($LASTEXITCODE -ne 0) { throw "A53 ELF link failed with exit code $LASTEXITCODE" }

& $size $elf
Write-Host "Built direct A53 ELF: $elf"
