param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$OutFile
)

$lines = @(
  "$RepoRoot\rtl\mem\rom_reader.sv",
  "$RepoRoot\rtl\axis\axis_skid_buffer.sv",
  "$RepoRoot\rtl\dsm\singlebit\dsm_core.sv",
  "$RepoRoot\rtl\dsm\singlebit\dsm_core_dsm2.sv",
  "$RepoRoot\rtl\dsm\singlebit\dsm_core_ef1.sv",
  "$RepoRoot\rtl\dsm\singlebit\dsm_core_ef2.sv",
  "$RepoRoot\rtl\dsm\singlebit\dsm_core_mash11.sv",
  "$RepoRoot\rtl\dsm\singlebit\dsm_core_mash111.sv",
  "$RepoRoot\rtl\dsm\singlebit\dsm_core_mash22.sv",
  "$RepoRoot\rtl\dsm\multibit\dsm_core_multibit.sv",
  "$RepoRoot\rtl\dsm\multibit\dsm_core_multibit_lp1.sv",
  "$RepoRoot\rtl\dsm\multibit\dsm_core_multibit_lp2.sv",
  "$RepoRoot\rtl\dsm\multibit\dsm_core_multibit_ef1.sv",
  "$RepoRoot\rtl\dsm\multibit\dsm_core_multibit_ef2.sv",
  "$RepoRoot\rtl\dsm\multibit\dsm_core_multibit_mash11.sv",
  "$RepoRoot\rtl\dsm\multibit\dsm_core_multibit_mash111.sv",
  "$RepoRoot\rtl\dsm\multibit\dsm_core_multibit_mash22.sv",
  "$RepoRoot\rtl\interp\dsm_interp_fir_fixed.sv",
  "$RepoRoot\rtl\interp\dsm_interp2_halfband.sv",
  "$RepoRoot\rtl\interp\dsm_interp_frontend.sv",
  "$RepoRoot\rtl\dpd\dpd_poly.v",
  "$RepoRoot\rtl\dpd\dpd_lut.v",
  "$RepoRoot\rtl\dpd\dpd_frontend.v",
  "$RepoRoot\rtl\duc\duc_fs4_merge.sv",
  "$RepoRoot\rtl\duc\duc_fs4_merge_signed.sv",
  "$RepoRoot\rtl\duc\duc_nco_mix_signed.v",
  "$RepoRoot\rtl\ip\dsm_ip_core.sv",
  "$RepoRoot\rtl\ip\dsm_ip_top.v",
  "$RepoRoot\rtl\axi\dsm_ip_axi_top.v",
  "$RepoRoot\rtl\top\p0_top_lp1.v",
  "$RepoRoot\rtl\top\p0_top_lp2.v",
  "$RepoRoot\rtl\top\p0_top_ef1.v",
  "$RepoRoot\rtl\top\p0_top_ef2.v",
  "$RepoRoot\rtl\top\p0_top_mash11_mb.v",
  "$RepoRoot\rtl\top\p0_top_mash111_mb.v",
  "$RepoRoot\rtl\top\p0_top_mash22_mb.v"
)

Set-Content -Path $OutFile -Value ($lines -join "`r`n") -Encoding ASCII
