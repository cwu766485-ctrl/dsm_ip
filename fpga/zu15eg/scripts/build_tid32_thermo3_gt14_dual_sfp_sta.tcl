# Route the two raw code planes through the real dual-SFP GTH target.
if {[llength $argv] != 1} { error "usage: <out_dir>" }
set out_dir [file normalize [lindex $argv 0]]
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir .. .. ..]]
set gt_dir [file join $out_dir gt_ip]
set build_dir [file join $out_dir sta]
file mkdir $out_dir
set saved_argv $argv
set requested_out_dir $out_dir
set argv [list $gt_dir]
source [file join $script_dir generate_ti64_raw_gt14_dual_ip.tcl]
set argv $saved_argv
set out_dir $requested_out_dir
close_project
set gt_xci [file join $gt_dir ti64_raw_gt14_dual.srcs sources_1 ip ti64_raw_gt14_dual ti64_raw_gt14_dual.xci]
if {![file exists $gt_xci]} { error "generated GT XCI missing: $gt_xci" }
create_project tid32_thermo3_gt14_dual_sfp_sta $build_dir -part xczu15eg-ffvb1156-2-i -force
set_property target_language Verilog [current_project]
add_files -norecurse [list \
  [file join $repo_dir rtl gt gt_tx_user_bridge.sv] \
  [file join $repo_dir rtl gt gt_tx_raw64_boundary.sv] \
  [file join $repo_dir rtl tx_bandpass_if tid32_cartesian_fs4_gt_tx.sv] \
  [file join $repo_dir rtl tx_bandpass_if tid32_thermo3_fs4_multipa_tx.sv] \
  [file join $repo_dir fpga zu15eg rtl ti64_raw_gt14_dual_sfp_link.sv] \
  [file join $repo_dir fpga zu15eg rtl tid32_thermo3_gt14_dual_sfp_payload_top.sv] \
  $gt_xci \
]
add_files -fileset constrs_1 -norecurse [file join $repo_dir fpga zu15eg constraints tid32_thermo3_gt14_dual_sfp.xdc]
set_property top tid32_thermo3_gt14_dual_sfp_payload_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
open_run impl_1
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
write_bitstream -force [file join $out_dir tid32_thermo3_gt14_dual_sfp_sta.bit]
puts "TID32_THERMO3_GT14_DUAL_SFP_STA_BUILT=$out_dir"
