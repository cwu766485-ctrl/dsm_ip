set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set work_dir [file normalize [file join $script_dir "build" "vivado_pack"]]
set ip_dir [file normalize [file join $script_dir "ip_repo" "dsm_ip_1_0"]]

file delete -force $work_dir
file delete -force $ip_dir
file mkdir $work_dir
file mkdir $ip_dir

set part "xc7z020clg400-1"
set files [list \
  [file join $repo_root rtl axis axis_skid_buffer.sv] \
  [file join $repo_root rtl dsm singlebit dsm_core.sv] \
  [file join $repo_root rtl dsm singlebit dsm_core_dsm2.sv] \
  [file join $repo_root rtl dsm singlebit dsm_core_ef1.sv] \
  [file join $repo_root rtl dsm singlebit dsm_core_ef2.sv] \
  [file join $repo_root rtl dsm singlebit dsm_core_mash11.sv] \
  [file join $repo_root rtl dsm singlebit dsm_core_mash111.sv] \
  [file join $repo_root rtl dsm singlebit dsm_core_mash22.sv] \
  [file join $repo_root rtl dsm multibit dsm_core_multibit.sv] \
  [file join $repo_root rtl dsm multibit dsm_core_multibit_lp1.sv] \
  [file join $repo_root rtl dsm multibit dsm_core_multibit_lp2.sv] \
  [file join $repo_root rtl dsm multibit dsm_core_multibit_ef1.sv] \
  [file join $repo_root rtl dsm multibit dsm_core_multibit_ef2.sv] \
  [file join $repo_root rtl dsm multibit dsm_core_multibit_mash11.sv] \
  [file join $repo_root rtl dsm multibit dsm_core_multibit_mash111.sv] \
  [file join $repo_root rtl dsm multibit dsm_core_multibit_mash22.sv] \
  [file join $repo_root rtl interp dsm_interp_fir_fixed.sv] \
  [file join $repo_root rtl interp dsm_interp2_halfband.sv] \
  [file join $repo_root rtl interp dsm_interp_frontend.sv] \
  [file join $repo_root rtl dpd dpd_poly.v] \
  [file join $repo_root rtl dpd dpd_lut.v] \
  [file join $repo_root rtl dpd dpd_memory_poly.v] \
  [file join $repo_root rtl dpd dpd_observer.v] \
  [file join $repo_root rtl dpd dpd_seed_predictor.v] \
  [file join $repo_root rtl dpd dpd_tinyml_tree.v] \
  [file join $repo_root rtl dpd dpd_frontend.v] \
  [file join $repo_root rtl duc duc_fs4_merge.sv] \
  [file join $repo_root rtl duc duc_fs4_merge_signed.sv] \
  [file join $repo_root rtl duc duc_nco_mix_signed.v] \
  [file join $repo_root rtl tx_bandpass_if bp_fs4_iq_mixer.sv] \
  [file join $repo_root rtl tx_bandpass_if dsm_core_bp_single.sv] \
  [file join $repo_root rtl tx_bandpass_if dsm_core_bp_ef2.sv] \
  [file join $repo_root rtl tx_bandpass_if tx_bp_if_top.sv] \
  [file join $repo_root rtl ip dsm_ip_core.sv] \
  [file join $repo_root rtl ip dsm_ip_top.v] \
  [file join $repo_root rtl axi dsm_ip_axi_top.v] \
]

create_project dsm_ip_pack $work_dir -part $part
add_files -norecurse $files
set_property top dsm_ip_axi_top [get_filesets sources_1]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $ip_dir -vendor dsm.local -library communication -taxonomy /UserIP -import_files -force
set core [ipx::current_core]
set_property name dsm_ip $core
set_property display_name {DSM All-Digital Transmitter IP} $core
set_property description {AXI-Lite controlled, AXI-Stream input all-digital Cartesian DSM transmitter IP with LPDSM, EFDSM, MASH, and exploratory multibit Cartesian DSM variants. Default target clock 100 MHz.} $core
set_property version 1.0 $core
set_property supported_families {zynq Production zynquplus Production artix7 Production kintex7 Production} $core

set aclk_intf [ipx::get_bus_interfaces aclk -of_objects $core]
if {[llength $aclk_intf] > 0} {
  set associated_busif [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $aclk_intf]
  if {[llength $associated_busif] > 0} {
    set_property value {s_axi:s_axis:s_axis_obs} $associated_busif
  }
}

set component_name_param [ipx::get_user_parameters Component_Name -of_objects $core]
if {[llength $component_name_param] > 0} {
  set_property value dsm_ip $component_name_param
}

ipx::update_checksums $core
ipx::save_core $core
close_project

puts "Packaged DSM IP: [file join $ip_dir component.xml]"
