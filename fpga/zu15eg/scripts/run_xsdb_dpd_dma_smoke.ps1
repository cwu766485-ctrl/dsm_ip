param(
    [Parameter(Mandatory = $true)]
    [string]$DsmBase,

    [Parameter(Mandatory = $true)]
    [string]$DmaBase,

    [string]$DdrAddr = "0x10000000",
    [string]$DmaBytes = "0x00004000",
    [string]$ProjectDir = "",
    [ValidateSet("bypass", "poly", "lut", "0", "1", "2")]
    [string]$DpdMode = "poly",
    [switch]$SkipProgram,
    [switch]$SkipPsuInit,
    [switch]$PrintOnly
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$zu15egDir = Resolve-Path (Join-Path $scriptDir "..")
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")

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

if ($SkipPsuInit) {
    $psuInit = ""
}

$dmaBin = Join-Path $zu15egDir "p0_iq_dma_words.bin"
if (-not (Test-Path $dmaBin)) {
    $packer = Join-Path $scriptDir "pack_p0_iq_for_dma.py"
    throw "Missing DMA binary: $dmaBin. Generate it first, for example: python `"$packer`" --limit 4096"
}

$env:DSM_BASE = $DsmBase
$env:DMA_BASE = $DmaBase
$env:DDR_ADDR = $DdrAddr
$env:DMA_BYTES = $DmaBytes
$env:DMA_BIN = (Resolve-Path $dmaBin).Path
$env:PSU_INIT_TCL = $psuInit
$env:BIT_FILE = $bitFile
$env:PROGRAM_BIT = $(if ($SkipProgram) { "0" } elseif ($bitFile -ne "") { "1" } else { "0" })
$env:DPD_MODE = switch ($DpdMode) {
    "bypass" { "0" }
    "poly" { "1" }
    "lut" { "2" }
    default { $DpdMode }
}

$xsdbCandidates = @()
$cmd = Get-Command xsdb -ErrorAction SilentlyContinue
if ($cmd) {
    $xsdbCandidates += $cmd.Source
}
$xsdbCandidates += @(
    "D:\Xilinx\Vitis\2024.1\bin\xsdb.bat",
    "D:\Xilinx\Vivado\2024.1\bin\xsdb.bat",
    "D:\Xilinx\Vitis\2023.2\bin\xsdb.bat",
    "D:\Xilinx\Vivado\2023.2\bin\xsdb.bat",
    "D:\Xilinx\Vitis\2022.2\bin\xsdb.bat",
    "D:\Xilinx\Vivado\2022.2\bin\xsdb.bat"
)

$xsdb = $xsdbCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$tcl = Join-Path $scriptDir "xsdb_dpd_dma_smoke.tcl"

Write-Host "DSM_BASE     = $env:DSM_BASE"
Write-Host "DMA_BASE     = $env:DMA_BASE"
Write-Host "DDR_ADDR     = $env:DDR_ADDR"
Write-Host "DMA_BYTES    = $env:DMA_BYTES"
Write-Host "DMA_BIN      = $env:DMA_BIN"
Write-Host "PSU_INIT_TCL = $env:PSU_INIT_TCL"
Write-Host "BIT_FILE     = $env:BIT_FILE"
Write-Host "PROGRAM_BIT  = $env:PROGRAM_BIT"
Write-Host "DPD_MODE     = $env:DPD_MODE"
Write-Host "XSDB_SCRIPT  = $tcl"

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
$logPath = Join-Path $logDir "xsdb_dpd_dma_smoke.log"

& $xsdb $tcl 2>&1 | Tee-Object -FilePath $logPath
if ($LASTEXITCODE -ne 0) {
    throw "XSDB DPD/DMA smoke failed with exit code $LASTEXITCODE"
}

$logText = Get-Content -Raw $logPath
if ($logText -match "mismatch|timeout|ERROR:|Missing required|does not exist") {
    throw "XSDB DPD/DMA smoke reported an error. See $logPath"
}
