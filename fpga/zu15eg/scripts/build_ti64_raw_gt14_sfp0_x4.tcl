# Build the XCZU15EG SFP0 Cartesian-x4/TI64/raw-GTH bring-up bitstream outside
# the repository. Usage: vivado -mode batch -source <this-script> -tclargs
# <out_dir>.  The GT Wizard IP is regenerated below <out_dir>/gt_ip.
if {[llength $argv] != 1} { error "usage: <out_dir>" }

set out_dir [file normalize [lindex $argv 0]]
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir .. .. ..]]
set gt_dir [file join $out_dir gt_ip]
set build_dir [file join $out_dir x4]
file mkdir $out_dir

set saved_argv $argv
set build_out_dir $out_dir
set argv [list $gt_dir]
source [file join $script_dir generate_ti64_raw_gt14_ip.tcl]
set argv $saved_argv
set out_dir $build_out_dir
close_project

set gt_xci [file join $gt_dir ti64_raw_gt14.srcs sources_1 ip ti64_raw_gt14 ti64_raw_gt14.xci]
if {![file exists $gt_xci]} { error "generated GT XCI missing: $gt_xci" }

create_project ti64_raw_gt14_sfp0_x4 $build_dir -part xczu15eg-ffvb1156-2-i -force
set_property target_language Verilog [current_project]
foreach f [glob -nocomplain [file join $repo_dir rtl dpd *.v]] { add_files -norecurse $f }
add_files -norecurse [list \
  [file join $repo_dir rtl dpd dpd_vector16_frontend.sv] \
  [file join $repo_dir rtl interp dsm_interp_x4_polyphase16.sv] \
  [file join $repo_dir rtl tx_bandpass_if ti32_lp1_fs4_dsm.sv] \
  [file join $repo_dir rtl gt gt_tx_user_bridge.sv] \
  [file join $repo_dir rtl gt gt_tx_raw64_boundary.sv] \
  [file join $repo_dir rtl tx_bandpass_if ti64_lp1_fs4_gt_tx.sv] \
  [file join $repo_dir rtl tx_bandpass_if ti64_cartesian_x4_frontend_tx.sv] \
  [file join $repo_dir fpga zu15eg rtl ti64_raw_gt14_sfp0_link.sv] \
  [file join $repo_dir fpga zu15eg rtl ti64_raw_gt14_sfp0_x4_top.sv] \
  $gt_xci \
]
add_files -fileset constrs_1 -norecurse \
  [file join $repo_dir fpga zu15eg constraints ti64_raw_gt14_sfp0_loopback.xdc]

create_ip -name ila -vendor xilinx.com -library ip -module_name ila_ti64_raw_gt14_x4
set ila_ip [get_ips ila_ti64_raw_gt14_x4]
set_property -dict [list \
  CONFIG.C_DATA_DEPTH {1024} CONFIG.C_NUM_OF_PROBES {5} \
  CONFIG.C_PROBE0_WIDTH {64} CONFIG.C_PROBE1_WIDTH {64} \
  CONFIG.C_PROBE2_WIDTH {1} CONFIG.C_PROBE3_WIDTH {1} CONFIG.C_PROBE4_WIDTH {1} \
] $ila_ip
generate_target all $ila_ip

set_property top ti64_raw_gt14_sfp0_x4_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
open_run impl_1
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
write_debug_probes -force [file join $out_dir ti64_raw_gt14_sfp0_x4.ltx]
write_bitstream -force [file join $out_dir ti64_raw_gt14_sfp0_x4.bit]
puts "TI64_RAW_GT14_SFP0_X4_BUILT=$out_dir"
