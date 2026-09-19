# Build the actual TID32 payload through the existing dual-SFP 14-Gb/s GTH.
# The payload source is deterministic board bring-up data; see its top-level
# comment for the deliberate boundary before 256-QAM board qualification.
if {[llength $argv] != 1} { error "usage: <out_dir>" }
set out_dir [file normalize [lindex $argv 0]]
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir .. .. ..]]
set gt_dir [file join $out_dir gt_ip]
set build_dir [file join $out_dir payload]
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
create_project tid32_cartesian_gt14_dual_sfp_payload $build_dir -part xczu15eg-ffvb1156-2-i -force
set_property target_language Verilog [current_project]
add_files -norecurse [list \
  [file join $repo_dir rtl gt gt_tx_user_bridge.sv] \
  [file join $repo_dir rtl gt gt_tx_raw64_boundary.sv] \
  [file join $repo_dir rtl tx_bandpass_if tid32_cartesian_fs4_gt_tx.sv] \
  [file join $repo_dir fpga zu15eg rtl ti64_raw_gt14_dual_sfp_link.sv] \
  [file join $repo_dir fpga zu15eg rtl tid32_cartesian_gt14_dual_sfp_payload_top.sv] \
  $gt_xci \
]
add_files -fileset constrs_1 -norecurse [file join $repo_dir fpga zu15eg constraints ti64_raw_gt14_dual_sfp_loopback.xdc]
create_ip -name ila -vendor xilinx.com -library ip -module_name ila_ti64_raw_gt14_dual_loopback
set ila_ip [get_ips ila_ti64_raw_gt14_dual_loopback]
set_property -dict [list CONFIG.C_DATA_DEPTH {1024} CONFIG.C_NUM_OF_PROBES {4} CONFIG.C_PROBE0_WIDTH {64} CONFIG.C_PROBE1_WIDTH {64} CONFIG.C_PROBE2_WIDTH {1} CONFIG.C_PROBE3_WIDTH {1}] $ila_ip
generate_target all $ila_ip
set_property top tid32_cartesian_gt14_dual_sfp_payload_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
open_run impl_1
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
write_debug_probes -force [file join $out_dir tid32_cartesian_gt14_dual_sfp_payload.ltx]
write_bitstream -force [file join $out_dir tid32_cartesian_gt14_dual_sfp_payload.bit]
puts "TID32_CARTESIAN_GT14_DUAL_SFP_PAYLOAD_BUILT=$out_dir"
