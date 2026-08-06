param(
  [switch]$KeepWork
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$vivadoSettings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path $vivadoSettings)) {
  throw "Vivado settings not found at $vivadoSettings."
}

$work = Join-Path $repo "verif\out_xsim_tx_routes"
if ((Test-Path $work) -and -not $KeepWork) {
  Remove-Item -LiteralPath $work -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $work | Out-Null
Set-Location $work

$rtlFiles = @(
  "$repo\rtl\axis\axis_skid_buffer.sv",
  "$repo\rtl\dsm\singlebit\dsm_core.sv",
  "$repo\rtl\dsm\singlebit\dsm_core_dsm2.sv",
  "$repo\rtl\dsm\singlebit\dsm_core_ef1.sv",
  "$repo\rtl\dsm\singlebit\dsm_core_ef2.sv",
  "$repo\rtl\dsm\singlebit\dsm_core_mash11.sv",
  "$repo\rtl\dsm\singlebit\dsm_core_mash111.sv",
  "$repo\rtl\dsm\singlebit\dsm_core_mash22.sv",
  "$repo\rtl\dsm\multibit\dsm_core_multibit.sv",
  "$repo\rtl\dsm\multibit\dsm_core_multibit_lp1.sv",
  "$repo\rtl\dsm\multibit\dsm_core_multibit_lp2.sv",
  "$repo\rtl\dsm\multibit\dsm_core_multibit_ef1.sv",
  "$repo\rtl\dsm\multibit\dsm_core_multibit_ef2.sv",
  "$repo\rtl\dsm\multibit\dsm_core_multibit_mash11.sv",
  "$repo\rtl\dsm\multibit\dsm_core_multibit_mash111.sv",
  "$repo\rtl\dsm\multibit\dsm_core_multibit_mash22.sv",
  "$repo\rtl\interp\dsm_interp_fir_fixed.sv",
  "$repo\rtl\interp\dsm_interp_cic_direct.sv",
  "$repo\rtl\interp\dsm_interp_fir_polyphase.sv",
  "$repo\rtl\interp\dsm_interp_fir_i2_polyphase.sv",
  "$repo\rtl\interp\dsm_interp2_halfband.sv",
  "$repo\rtl\interp\dsm_interp_frontend.sv",
  "$repo\rtl\duc\duc_fs4_merge.sv",
  "$repo\rtl\duc\duc_fs4_merge_signed.sv",
  "$repo\rtl\duc\duc_nco_mix_signed.v",
  "$repo\rtl\ip\dsm_ip_core.sv",
  "$repo\rtl\ip\dsm_ip_top.v",
  "$repo\rtl\tx_analog_iq\dsm_iq_analog_top.sv",
  "$repo\rtl\tx_bandpass_if\bp_fs4_iq_mixer.sv",
  "$repo\rtl\tx_bandpass_if\dsm_core_bp_single.sv",
  "$repo\rtl\tx_bandpass_if\dsm_core_bp_ef2.sv",
  "$repo\rtl\tx_bandpass_if\tx_bp_if_top.sv"
)

$filelist = Join-Path $work "filelist_tx_routes.f"
Set-Content -LiteralPath $filelist -Value ($rtlFiles -join "`r`n") -Encoding ASCII
$tbs = @(
  "$repo\verif\tb\tx_analog_iq\tb_dsm_iq_analog_top.sv",
  "$repo\verif\tb\tx_bandpass_if\tb_dsm_core_bp_single.sv",
  "$repo\verif\tb\tx_bandpass_if\tb_tx_bp_if_top.sv"
)

$bat = Join-Path $env:TEMP ("run_xsim_tx_routes_" + [guid]::NewGuid().ToString() + ".cmd")
try {
  Set-Content -LiteralPath $bat -Encoding ASCII -Value (@(
    '@echo off',
    "call `"$vivadoSettings`" >nul",
    "xvlog -sv -log xvlog.log -f `"$filelist`" " + (($tbs | ForEach-Object { "`"$_`"" }) -join ' '),
    'if errorlevel 1 exit /b 1',
    'xelab -log xelab_analog_iq.log tb_dsm_iq_analog_top -s sim_analog_iq',
    'if errorlevel 1 exit /b 1',
    'xsim sim_analog_iq -log xsim_analog_iq.log -runall',
    'if errorlevel 1 exit /b 1',
    'xelab -log xelab_bp_single.log tb_dsm_core_bp_single -s sim_bp_single',
    'if errorlevel 1 exit /b 1',
    'xsim sim_bp_single -log xsim_bp_single.log -runall',
    'if errorlevel 1 exit /b 1',
    'xelab -log xelab_bp_if.log tb_tx_bp_if_top -s sim_bp_if',
    'if errorlevel 1 exit /b 1',
    'xsim sim_bp_if -log xsim_bp_if.log -runall'
  ))
  cmd.exe /c $bat
  if ($LASTEXITCODE -ne 0) { throw "XSim transmitter-route regression failed." }
  $logs = @('xvlog.log', 'xelab_analog_iq.log', 'xsim_analog_iq.log', 'xelab_bp_single.log', 'xsim_bp_single.log', 'xelab_bp_if.log', 'xsim_bp_if.log')
  foreach ($name in $logs) {
    if (-not (Test-Path -LiteralPath (Join-Path $work $name))) {
      throw "Vivado returned without producing $name."
    }
  }
  foreach ($name in @('xsim_analog_iq.log', 'xsim_bp_single.log', 'xsim_bp_if.log')) {
    if (-not (Select-String -LiteralPath (Join-Path $work $name) -Pattern 'PASS' -SimpleMatch -Quiet)) {
      throw "Simulation PASS marker was not found in $name."
    }
  }
} finally {
  Remove-Item -LiteralPath $bat -Force -ErrorAction SilentlyContinue
}

Write-Host "TX route XSim regression passed. Outputs in $work"
