# Build the XCZU15EG SFP0 raw-GTH known-word loopback bitstream outside the
# source tree.  Usage: vivado -mode batch -source <this-script> -tclargs
# <out_dir>.  The raw GT Wizard IP is regenerated below <out_dir>/gt_ip.
if {[llength $argv] != 1} { error "usage: <out_dir>" }

set out_dir [file normalize [lindex $argv 0]]
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir .. .. ..]]
set gt_dir [file join $out_dir gt_ip]
set build_dir [file join $out_dir loopback]
file mkdir $out_dir

# Reuse the source-controlled GT configuration and keep generated files out
# of the repository.
set saved_argv $argv
set build_out_dir $out_dir
set argv [list $gt_dir]
source [file join $script_dir generate_ti64_raw_gt14_ip.tcl]
set argv $saved_argv
set out_dir $build_out_dir
close_project

set gt_xci [file join $gt_dir ti64_raw_gt14.srcs sources_1 ip ti64_raw_gt14 ti64_raw_gt14.xci]
if {![file exists $gt_xci]} { error "generated GT XCI missing: $gt_xci" }

create_project ti64_raw_gt14_sfp0_loopback $build_dir -part xczu15eg-ffvb1156-2-i -force
set_property target_language Verilog [current_project]

add_files -norecurse [list \
  [file join $repo_dir fpga zu15eg rtl ti64_raw_gt14_sfp0_link.sv] \
  [file join $repo_dir fpga zu15eg rtl ti64_raw_gt14_sfp0_loopback_top.sv] \
  $gt_xci \
]
add_files -fileset constrs_1 -norecurse \
  [file join $repo_dir fpga zu15eg constraints ti64_raw_gt14_sfp0_loopback.xdc]

create_ip -name ila -vendor xilinx.com -library ip -module_name ila_ti64_raw_gt14_loopback
set ila_ip [get_ips ila_ti64_raw_gt14_loopback]
set_property -dict [list \
  CONFIG.C_DATA_DEPTH {1024} \
  CONFIG.C_NUM_OF_PROBES {3} \
  CONFIG.C_PROBE0_WIDTH {64} \
  CONFIG.C_PROBE1_WIDTH {1} \
  CONFIG.C_PROBE2_WIDTH {1} \
] $ila_ip
generate_target all $ila_ip

set_property top ti64_raw_gt14_sfp0_loopback_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
open_run impl_1
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
write_debug_probes -force [file join $out_dir ti64_raw_gt14_sfp0_loopback.ltx]
write_bitstream -force [file join $out_dir ti64_raw_gt14_sfp0_loopback.bit]
puts "TI64_RAW_GT14_SFP0_LOOPBACK_BUILT=$out_dir"
