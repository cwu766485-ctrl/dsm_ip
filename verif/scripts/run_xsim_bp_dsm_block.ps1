param(
  [int]$Samples = 2048,
  [string]$Python = "python",
  [int]$Seed = 20260812
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$settings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }

$work = Join-Path $repo "verif\out_xsim_bp_dsm_block"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$generator = Join-Path $repo "uvm_verif\refmodel\python\generate_bp_ef2_vectors.py"
& $Python $generator --samples $Samples --seed $Seed --output (Join-Path $work "bp_ef2_equivalence.csv")
if ($LASTEXITCODE -ne 0) { throw "BP EFDSM2 Python vector generation failed." }

$ef2 = Join-Path $repo "rtl\dsm\singlebit\dsm_core_ef2.sv"
$bp = Join-Path $repo "rtl\tx_bandpass_if\dsm_core_bp_ef2.sv"
$tb = Join-Path $repo "verif\block\bp_dsm\tb\tb_dsm_core_bp_ef2_bittrue.sv"
$tbRandom = Join-Path $repo "verif\block\bp_dsm\tb\tb_dsm_core_bp_ef2_random.sv"

Push-Location $work
try {
  function Invoke-VivadoCmd([string]$Command) {
    $log = $null
    if ($Command -like "xvlog *") { $log = Join-Path (Get-Location) "xvlog.log" }
    elseif ($Command -like "xelab *") { $log = Join-Path (Get-Location) "xelab.log" }
    elseif ($Command -like "xsim *") { $log = Join-Path (Get-Location) "xsim.log" }
    if ($log) { Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue }
    $cmdFile = Join-Path $env:TEMP ("run_xsim_bp_" + [guid]::NewGuid().ToString() + ".cmd")
    $batch = "@echo off`r`n" + "call `"$settings`" >nul`r`n" + "$Command`r`n"
    Set-Content -LiteralPath $cmdFile -Encoding ASCII -Value $batch
    try {
      cmd.exe /c $cmdFile
      if ($LASTEXITCODE -ne 0) { throw "Command failed: $Command" }
      if ($log -and -not (Test-Path -LiteralPath $log)) {
        throw "Vivado command returned without creating its log: $Command"
      }
      if ($log -and (Select-String -LiteralPath $log -Pattern "ERROR:" -SimpleMatch -Quiet)) {
        throw "Vivado reported an error: $Command"
      }
    } finally {
      Remove-Item -LiteralPath $cmdFile -Force -ErrorAction SilentlyContinue
    }
  }
  Invoke-VivadoCmd "xvlog -sv `"$ef2`" `"$bp`" `"$tb`" `"$tbRandom`""
  Invoke-VivadoCmd "xelab -debug typical tb_dsm_core_bp_ef2_bittrue -s sim_bp_dsm_block"
  Invoke-VivadoCmd "xsim sim_bp_dsm_block -runall"
  Move-Item -LiteralPath xelab.log -Destination xelab_directed.log -Force
  Move-Item -LiteralPath xsim.log -Destination xsim_directed.log -Force
  Invoke-VivadoCmd "xelab -debug typical tb_dsm_core_bp_ef2_random -s sim_bp_dsm_random"
  Move-Item -LiteralPath xelab.log -Destination xelab_random.log -Force
  Invoke-VivadoCmd "xsim sim_bp_dsm_random -runall"
  Move-Item -LiteralPath xsim.log -Destination xsim_random.log -Force
} finally {
  Pop-Location
}
if (-not (Select-String -LiteralPath (Join-Path $work "xsim_directed.log") -Pattern "BP_EFDSM2_BLOCK_BITTRUE_PASS" -Quiet)) {
  throw "BP EFDSM2 block PASS marker was not found."
}
if (-not (Select-String -LiteralPath (Join-Path $work "xsim_random.log") -Pattern "BP_EFDSM2_RANDOM_PROTOCOL_PASS" -Quiet)) {
  throw "BP EFDSM2 randomized PASS marker was not found."
}
Write-Host "BP EFDSM2 Python-to-RTL block bit-true passed: $Samples samples."
