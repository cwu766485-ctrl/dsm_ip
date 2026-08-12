param(
  [switch]$KeepWork
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$vivadoSettings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path $vivadoSettings)) {
  throw "Vivado settings not found at $vivadoSettings. Update run_xsim_ip_smoke.ps1."
}

$work = Join-Path $repo "verif\out_xsim_ip_smoke"
if ((Test-Path $work) -and -not $KeepWork) {
  Remove-Item -LiteralPath $work -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $work | Out-Null
$originalLocation = Get-Location
try {
Set-Location $work

$filelist = Join-Path $work "filelist_dsm_ip_abs.f"
$tbTop = Join-Path $repo "verif\tb\tb_dsm_ip_top_smoke.sv"
$tbAxi = Join-Path $repo "verif\tb\tb_dsm_ip_axi_smoke.sv"
$tbDpdV11 = Join-Path $repo "verif\block\dpd\tb\tb_dpd_v11.sv"
$tbBpAxi = Join-Path $repo "verif\tb\tx_bandpass_if\tb_dsm_ip_bp_axi_smoke.sv"

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
  "$repo\rtl\dpd\dpd_poly.v",
  "$repo\rtl\dpd\dpd_lut.v",
  "$repo\rtl\dpd\dpd_memory_poly.v",
  "$repo\rtl\dpd\dpd_observer.v",
  "$repo\rtl\dpd\dpd_seed_predictor.v",
  "$repo\rtl\dpd\dpd_tinyml_tree.v",
  "$repo\rtl\dpd\dpd_frontend.v",
  "$repo\rtl\duc\duc_fs4_merge.sv",
  "$repo\rtl\duc\duc_fs4_merge_signed.sv",
  "$repo\rtl\duc\duc_nco_mix_signed.v",
  "$repo\rtl\tx_bandpass_if\bp_fs4_iq_mixer.sv",
  "$repo\rtl\tx_bandpass_if\dsm_core_bp_single.sv",
  "$repo\rtl\tx_bandpass_if\dsm_core_bp_ef2.sv",
  "$repo\rtl\tx_bandpass_if\tx_bp_if_top.sv",
  "$repo\rtl\ip\dsm_ip_core.sv",
  "$repo\rtl\ip\dsm_ip_top.v",
  "$repo\rtl\axi\dsm_ip_axi_top.v"
)
Set-Content -Path $filelist -Value ($rtlFiles -join "`r`n") -Encoding ASCII

function Invoke-VivadoCmd($cmd) {
  $log = $null
  if ($cmd -like "xvlog *") {
    $log = Join-Path (Get-Location) "xvlog.log"
  } elseif ($cmd -like "xelab *") {
    $log = Join-Path (Get-Location) "xelab.log"
  } elseif ($cmd -like "xsim *") {
    $log = Join-Path (Get-Location) "xsim.log"
  }
  if ($log) {
    Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
  }

  $bat = "@echo off`r`n" +
         "call `"$vivadoSettings`" >nul`r`n" +
         "$cmd`r`n"
  $tmp = Join-Path $env:TEMP ("run_xsim_ip_smoke_" + [guid]::NewGuid().ToString() + ".cmd")
  Set-Content -Path $tmp -Value $bat -Encoding ASCII
  try {
    cmd.exe /c $tmp
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
    if ($log -and -not (Test-Path -LiteralPath $log)) {
      throw "Vivado command returned without producing a log: $cmd"
    }
    if ($log) {
      $errors = Select-String -LiteralPath $log -Pattern "ERROR:" -SimpleMatch
      if ($errors) {
        throw "Vivado reported errors while running: $cmd"
      }
      $fatals = Select-String -LiteralPath $log -Pattern "Fatal:" -SimpleMatch
      if ($fatals) {
        throw "Simulation reported fatal failures while running: $cmd"
      }
    }
  } finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "[xsim] compile DSM IP top smoke"
Invoke-VivadoCmd "xvlog -sv -f `"$filelist`" `"$tbTop`" `"$tbAxi`" `"$tbDpdV11`" `"$tbBpAxi`""

Write-Host "[xsim] elaborate DSM IP top smoke"
Invoke-VivadoCmd "xelab -debug typical tb_dsm_ip_top_smoke -s sim_tb_dsm_ip_top_smoke"

Write-Host "[xsim] run DSM IP top smoke"
Invoke-VivadoCmd "xsim sim_tb_dsm_ip_top_smoke -runall"

Write-Host "[xsim] elaborate DSM IP AXI smoke"
Invoke-VivadoCmd "xelab -debug typical tb_dsm_ip_axi_smoke -s sim_tb_dsm_ip_axi_smoke"

Write-Host "[xsim] run DSM IP AXI smoke"
Invoke-VivadoCmd "xsim sim_tb_dsm_ip_axi_smoke -runall"

Write-Host "[xsim] elaborate BP AXI route smoke"
Invoke-VivadoCmd "xelab -debug typical tb_dsm_ip_bp_axi_smoke -s sim_tb_dsm_ip_bp_axi_smoke"

Write-Host "[xsim] run BP AXI route smoke"
Invoke-VivadoCmd "xsim sim_tb_dsm_ip_bp_axi_smoke -runall"

Write-Host "[xsim] elaborate DPD v1.1 unit smoke"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_v11 -s sim_tb_dpd_v11"

Write-Host "[xsim] run DPD v1.1 unit smoke"
Invoke-VivadoCmd "xsim sim_tb_dpd_v11 -runall"

Write-Host "[xsim] DSM IP smoke PASS"
} finally {
  Set-Location $originalLocation
}
