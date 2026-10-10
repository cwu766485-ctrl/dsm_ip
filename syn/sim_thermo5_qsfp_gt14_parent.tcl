if {[llength $argv] < 1 || [llength $argv] > 2} { error "usage: <parent_run_dir> ?skip_rx_compare(0|1)?" }
set out_dir [file normalize [lindex $argv 0]]
set skip_rx_compare [expr {[llength $argv] == 2 && [lindex $argv 1] eq "1"}]
set repo [file normalize [file join [file dirname [info script]] ..]]
set project_file [file join $out_dir project thermo5_qsfp_gt14_parent.xpr]
if {![file exists $project_file]} { error "Missing parent project: $project_file" }
open_project $project_file
set tb [file join $repo dv verif subsystem tx_frontend tb tb_thermo5_qsfp_gt14_parent.sv]
add_files -fileset sim_1 -norecurse $tb
set_property top tb_thermo5_qsfp_gt14_parent [get_filesets sim_1]
set_property -name xsim.simulate.runtime -value all -objects [get_filesets sim_1]
if {$skip_rx_compare} {
  set_property -name xsim.simulate.xsim.more_options -value "-testplusarg SKIP_RX_COMPARE" -objects [get_filesets sim_1]
}
update_compile_order -fileset sim_1
launch_simulation -mode behavioral
# XSim keeps simulate.log buffered until Vivado exits. The launcher verifies
# its PASS marker only after this process has completed.
puts "THERMO5_QSFP_GT14_PARENT_SIM_FINISHED=$out_dir"
