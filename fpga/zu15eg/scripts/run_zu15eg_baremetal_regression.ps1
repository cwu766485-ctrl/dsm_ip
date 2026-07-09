param(
    [string]$Project = ".\fpga\zu15eg\local_hw\pl_ps_gpio_test\pl_ps_gpio_test.xpr",
    [string]$DsmBase = "0xA0010000",
    [string]$ExpectedSamples = "0x00001000",
    [string]$ExpectedDpdCtrl = "0x00000002",
    [switch]$SkipBitstreamBuild,
    [switch]$SkipXsaExport,
    [switch]$SkipElfBuild,
    [switch]$SkipProgram,
    [switch]$SkipPsuInit,
    [switch]$CleanStaleHwProcesses
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$zu15egDir = Resolve-Path (Join-Path $scriptDir "..")
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..\..")
$outDir = Join-Path $zu15egDir "out"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $outDir "zu15eg_baremetal_regression_$timestamp.log"

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
if (-not $xsdb) {
    throw "xsdb was not found. Install Vitis/Vivado or add xsdb.bat to PATH."
}

function Invoke-LoggedStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host "==== $Name ===="
    & $Action
    Write-Host "PASS $Name"
}

function Invoke-PowerShellScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [string[]]$Arguments = @()
    )

    $resolved = Resolve-Path (Join-Path $repoRoot $Path)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $resolved.Path @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Path failed with exit code $LASTEXITCODE"
    }
}

function Invoke-XsdbScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $xsdbLog = & $xsdb (Join-Path $scriptDir $Path) 2>&1
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }
    $xsdbLog | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "$Path failed with exit code $LASTEXITCODE"
    }
    $xsdbText = $xsdbLog -join "`n"
    if ($xsdbText -match "No usable ZU15EG JTAG target found|no PL target|no Cortex-A53|ERROR:") {
        throw "$Path reported no usable hardware target"
    }
}

Start-Transcript -Path $logPath -Force | Out-Null
try {
    Write-Host "ZU15EG bare-metal DSM/DPD regression"
    Write-Host "Repo root          = $($repoRoot.Path)"
    Write-Host "Project            = $Project"
    Write-Host "DSM_BASE           = $DsmBase"
    Write-Host "Expected samples   = $ExpectedSamples"
    Write-Host "Expected DPD_CTRL  = $ExpectedDpdCtrl"
    Write-Host "Log                = $logPath"

    if ($CleanStaleHwProcesses) {
        Invoke-LoggedStep "Clean stale Xilinx hardware processes" {
            Get-CimInstance Win32_Process |
                Where-Object {
                    $_.Name -match '^(hw_server|xsdb|cmd)\.exe$' -and
                    $_.CommandLine -match 'hw_server|xsdb|xic\.bat'
                } |
                ForEach-Object {
                    Write-Host "Stopping PID $($_.ProcessId): $($_.CommandLine)"
                    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                }
            Start-Sleep -Seconds 2
        }
    }

    if (-not $SkipBitstreamBuild) {
        Invoke-LoggedStep "Rebuild ZU15EG bitstream" {
            Invoke-PowerShellScript ".\fpga\zu15eg\scripts\rebuild_dsm_board_bitstream.ps1" @("-Project", $Project)
        }
    } else {
        Write-Host "SKIP Rebuild ZU15EG bitstream"
    }

    if (-not $SkipXsaExport) {
        Invoke-LoggedStep "Export XSA" {
            Invoke-PowerShellScript ".\fpga\zu15eg\scripts\export_hw_platform.ps1" @("-Project", $Project)
        }
    } else {
        Write-Host "SKIP Export XSA"
    }

    if (-not $SkipElfBuild) {
        Invoke-LoggedStep "Build bare-metal ELF" {
            Invoke-PowerShellScript ".\fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.ps1"
        }
    } else {
        Write-Host "SKIP Build bare-metal ELF"
    }

    Invoke-LoggedStep "Require usable JTAG targets" {
        Invoke-XsdbScript "xsdb_require_targets.tcl"
    }

    $runArgs = @()
    if ($SkipProgram) {
        $runArgs += "-SkipProgram"
    }
    if ($SkipPsuInit) {
        $runArgs += "-SkipPsuInit"
    }
    Invoke-LoggedStep "Program and launch bare-metal smoke" {
        Invoke-PowerShellScript ".\fpga\zu15eg\baremetal\scripts\run_baremetal_smoke.ps1" $runArgs
    }

    Invoke-LoggedStep "Read and check DSM counters" {
        $env:DSM_BASE = $DsmBase
        $env:EXPECTED_SAMPLES = $ExpectedSamples
        $env:EXPECTED_DPD_CTRL = $ExpectedDpdCtrl
        & $xsdb (Join-Path $scriptDir "read_dsm_counters.tcl")
        if ($LASTEXITCODE -ne 0) {
            throw "DSM counter check failed with exit code $LASTEXITCODE"
        }
    }

    Write-Host ""
    Write-Host "PASS ZU15EG bare-metal DSM/DPD regression"
} finally {
    Stop-Transcript | Out-Null
}

Write-Host "Regression log: $logPath"
