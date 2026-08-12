param()

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$settings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }

$work = Join-Path $repo "verif\out_xsim_fs4_mixer_block"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$rtl = Join-Path $repo "rtl\tx_bandpass_if\bp_fs4_iq_mixer.sv"
$tb = Join-Path $repo "verif\block\fs4_mixer\tb\tb_bp_fs4_iq_mixer.sv"
$tbRandom = Join-Path $repo "verif\block\fs4_mixer\tb\tb_bp_fs4_iq_mixer_random.sv"

Push-Location $work
try {
  function Invoke-VivadoCmd([string]$Command) {
    $log = $null
    if ($Command -like "xvlog *") { $log = Join-Path (Get-Location) "xvlog.log" }
    elseif ($Command -like "xelab *") { $log = Join-Path (Get-Location) "xelab.log" }
    elseif ($Command -like "xsim *") { $log = Join-Path (Get-Location) "xsim.log" }
    if ($log) { Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue }
    $cmdFile = Join-Path $env:TEMP ("run_xsim_fs4_" + [guid]::NewGuid().ToString() + ".cmd")
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
  Invoke-VivadoCmd "xvlog -sv `"$rtl`" `"$tb`" `"$tbRandom`""
  Invoke-VivadoCmd "xelab -debug typical tb_bp_fs4_iq_mixer -s sim_fs4_mixer_block"
  Invoke-VivadoCmd "xsim sim_fs4_mixer_block -runall"
  Move-Item -LiteralPath xelab.log -Destination xelab_directed.log -Force
  Move-Item -LiteralPath xsim.log -Destination xsim_directed.log -Force
  Invoke-VivadoCmd "xelab -debug typical tb_bp_fs4_iq_mixer_random -s sim_fs4_mixer_random"
  Move-Item -LiteralPath xelab.log -Destination xelab_random.log -Force
  Invoke-VivadoCmd "xsim sim_fs4_mixer_random -runall"
  Move-Item -LiteralPath xsim.log -Destination xsim_random.log -Force
} finally {
  Pop-Location
}
if (-not (Select-String -LiteralPath (Join-Path $work "xsim_directed.log") -Pattern "FS4_MIXER_BLOCK_PASS" -Quiet)) {
  throw "Fs/4 mixer block PASS marker was not found."
}
if (-not (Select-String -LiteralPath (Join-Path $work "xsim_random.log") -Pattern "FS4_MIXER_RANDOM_PASS" -Quiet)) {
  throw "Fs/4 mixer randomized PASS marker was not found."
}
Write-Host "Fs/4 mixer block test passed."
