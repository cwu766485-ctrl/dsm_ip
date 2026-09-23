# Build the ZU15EG raw-GTH PRBS31 BERT top through route_design.
# Usage: vivado -mode batch -source <script> -tclargs <out_dir>
if {[llength $argv] != 1} { error "usage: <out_dir>" }
set out_dir [file normalize [lindex $argv 0]]
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir .. .. ..]]
set gt_dir [file join $out_dir gt_ip]
set saved_argv $argv
set argv [list $gt_dir]
source [file join $script_dir generate_ti64_raw_gt14_ip.tcl]
set argv $saved_argv
close_project

set xci [file join $gt_dir ti64_raw_gt14.srcs sources_1 ip ti64_raw_gt14 ti64_raw_gt14.xci]
create_project ti64_raw_gt14_sfp0_bert [file join $out_dir impl] \
  -part xczu15eg-ffvb1156-2-i -force
set_property target_language Verilog [current_project]
add_files -norecurse [list \
  [file join $repo_dir rtl axis dsm_async_fifo.sv] \
  [file join $repo_dir rtl gt gt_link_bringup_bist.sv] \
  [file join $repo_dir fpga zu15eg rtl ti64_raw_gt14_sfp0_link.sv] \
  [file join $repo_dir fpga zu15eg rtl ti64_raw_gt14_sfp0_bert_top.sv] \
  $xci]
add_files -fileset constrs_1 -norecurse \
  [file join $repo_dir fpga zu15eg constraints ti64_raw_gt14_sfp0_loopback.xdc]
set_property top ti64_raw_gt14_sfp0_bert_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "route_design Complete!"} {
  error "GT BERT implementation failed: [get_property STATUS [get_runs impl_1]]"
}
open_run impl_1
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
report_drc -file [file join $out_dir drc.rpt]
puts "TI64_RAW_GT14_SFP0_BERT_IMPL_DONE=$out_dir"
