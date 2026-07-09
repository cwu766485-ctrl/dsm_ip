param(
    [string]$Elf = ".\fpga\zu15eg\out\vitis_baremetal\dsm_dpd_baremetal_smoke\build\dsm_dpd_baremetal_smoke.elf",
    [string]$ProjectDir = "",
    [switch]$SkipProgram,
    [switch]$SkipPsuInit,
    [switch]$PrintOnly
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$zu15egDir = Resolve-Path (Join-Path $scriptDir "..\..")
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..\..\..")
$elfPath = Resolve-Path (Join-Path $repoRoot $Elf)

if ([string]::IsNullOrWhiteSpace($ProjectDir)) {
    $ProjectDir = Join-Path $zu15egDir "local_hw\pl_ps_gpio_test"
}

$projectPath = $null
if (Test-Path $ProjectDir) {
    $projectPath = Resolve-Path $ProjectDir
}

$bitFile = ""
$psuInit = ""
if ($projectPath) {
    $candidateBit = Join-Path $projectPath "pl_ps_gpio_test.runs\impl_1\top.bit"
    if (Test-Path $candidateBit) {
        $bitFile = (Resolve-Path $candidateBit).Path
    }

    $candidatePsu = Join-Path $projectPath "pl_ps_gpio_test.vitis\top\hw\psu_init.tcl"
    if (Test-Path $candidatePsu) {
        $psuInit = (Resolve-Path $candidatePsu).Path
    } else {
        $foundPsu = Get-ChildItem -Path $projectPath -Recurse -Filter psu_init.tcl -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($foundPsu) {
            $psuInit = $foundPsu.FullName
        }
    }
}

$vitisPsuInit = Join-Path $zu15egDir "out\vitis_baremetal\dsm_zu15eg_platform\hw\sdt\psu_init.tcl"
if ([string]::IsNullOrWhiteSpace($psuInit) -and (Test-Path $vitisPsuInit)) {
    $psuInit = (Resolve-Path $vitisPsuInit).Path
}

if ($SkipPsuInit) {
    $psuInit = ""
}

$xsdbCandidates = @()
$cmd = Get-Command xsdb -ErrorAction SilentlyContinue
if ($cmd) {
    $xsdbCandidates += $cmd.Source
}
$xsdbCandidates += @(
    "D:\Xilinx\Vitis\2024.1\bin\xsdb.bat",
    "D:\Xilinx\Vivado\2024.1\bin\xsdb.bat"
)

$xsdb = $xsdbCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$tcl = Join-Path $scriptDir "run_baremetal_smoke.tcl"

$env:ELF_FILE = $elfPath.Path
$env:BIT_FILE = $bitFile
$env:PSU_INIT_TCL = $psuInit
$env:PROGRAM_BIT = $(if ($SkipProgram) { "0" } elseif ($bitFile -ne "") { "1" } else { "0" })

Write-Host "ELF_FILE     = $env:ELF_FILE"
Write-Host "BIT_FILE     = $env:BIT_FILE"
Write-Host "PSU_INIT_TCL = $env:PSU_INIT_TCL"
Write-Host "PROGRAM_BIT  = $env:PROGRAM_BIT"
Write-Host "XSDB_SCRIPT  = $tcl"
Write-Host "Open the PS UART terminal before continuing if you want to capture xil_printf output."

if ($PrintOnly) {
    Write-Host "PrintOnly set; XSDB was not launched."
    exit 0
}

if (-not $xsdb) {
    throw "xsdb was not found. Start this from a Xilinx/Vitis shell or add xsdb.bat to PATH."
}

$logDir = Join-Path $zu15egDir "out"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$logPath = Join-Path $logDir "xsdb_baremetal_smoke.log"

& $xsdb $tcl 2>&1 | Tee-Object -FilePath $logPath
if ($LASTEXITCODE -ne 0) {
    throw "XSDB bare-metal smoke launch failed with exit code $LASTEXITCODE"
}

$logText = Get-Content -Raw $logPath
if ($logText -match "ERROR:|Missing required|does not exist|no Cortex-A53") {
    throw "XSDB bare-metal smoke launch reported an error. See $logPath"
}
