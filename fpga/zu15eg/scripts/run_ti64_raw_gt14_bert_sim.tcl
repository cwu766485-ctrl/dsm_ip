# Generate the concrete ZU15EG GT IP and run its vendor behavioral simulation.
# Usage: vivado -mode batch -source <script> -tclargs <out_dir>
if {[llength $argv] != 1} { error "usage: <out_dir>" }
set out_dir [file normalize [lindex $argv 0]]
set run_out_dir $out_dir
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir .. .. ..]]
set gt_dir [file join $out_dir gt_ip]
file mkdir $out_dir

set saved_argv $argv
set argv [list $gt_dir]
source [file join $script_dir generate_ti64_raw_gt14_ip.tcl]
set argv $saved_argv
close_project
set out_dir $run_out_dir

set xci [file join $gt_dir ti64_raw_gt14.srcs sources_1 ip ti64_raw_gt14 ti64_raw_gt14.xci]
create_project ti64_raw_gt14_bert_sim [file join $out_dir sim] \
  -part xczu15eg-ffvb1156-2-i -force
set_property target_language Verilog [current_project]
add_files -norecurse [list \
  [file join $repo_dir rtl axis dsm_async_fifo.sv] \
  [file join $repo_dir rtl gt gt_link_bringup_bist.sv] \
  [file join $repo_dir fpga zu15eg rtl ti64_raw_gt14_sfp0_link.sv] \
  [file join $repo_dir fpga zu15eg rtl ti64_raw_gt14_sfp0_bert_top.sv] \
  $xci]
add_files -fileset sim_1 -norecurse \
  [file join $repo_dir verif block gt tb_ti64_raw_gt14_sfp0_bert.sv]
set_property top tb_ti64_raw_gt14_sfp0_bert [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
close_sim
set sim_log [file join $out_dir sim ti64_raw_gt14_bert_sim.sim sim_1 behav xsim simulate.log]
set fh [open $sim_log r]
set sim_text [read $fh]
close $fh
if {![string match *TI64_RAW_GT14_VENDOR_BERT_PASS* $sim_text]} {
  error "vendor GT BERT simulation did not emit PASS marker: $sim_log"
}
if {[regexp -line {^\s*(Fatal:|Error:)} $sim_text]} {
  error "vendor GT BERT simulation reported a fatal/error: $sim_log"
}
puts "TI64_RAW_GT14_VENDOR_BERT_SIM_DONE=$out_dir"
