# Reuse the identical optimized-EF1 synthesized DCP; never write the input.
if {[llength $argv] != 3 || [lindex $argv 0] ne "ef1" || [lindex $argv 2] ne "a"} {error "usage: ef1 NEW_DIR a"}
set out [file normalize [lindex $argv 1]]
if {[file exists $out]} {error "refusing to overwrite"}
set repo [file normalize [file join [file dirname [info script]] ../..]]
set checkpoint [file normalize [file join $repo .. thermo5_vcu118_cubic_optimization runs optimized_ppa_ef1_01 ef1 synthesized.dcp]]
if {![file exists $checkpoint]} {error "source optimized synthesized checkpoint missing"}
file mkdir $out
cd $out
set_param general.maxThreads 1
open_checkpoint $checkpoint
# A Q-pin startpoint segments paths; fail this experiment if that recurs.
set_msg_config -id {Constraints 18-515} -new_severity ERROR
set mailbox_src_cells [get_cells -hier -filter {NAME =~ *u_cfg/cfg_mailbox_q_reg*}]
set mailbox_dst_cells [get_cells -hier -filter {NAME =~ *u_cfg/cfg_pending_core_reg*}]
if {[llength $mailbox_src_cells] == 0 || [llength $mailbox_dst_cells] == 0} {error "empty mailbox cell selection"}
puts "MAILBOX_DATA_BOUND src=[llength $mailbox_src_cells] dst=[llength $mailbox_dst_cells] ns=4.0"
set_max_delay -datapath_only 4.000 -from $mailbox_src_cells -to $mailbox_dst_cells
report_exceptions -file exceptions.rpt
report_clock_interaction -delay_type min_max -file clock_interaction.rpt
check_timing -verbose -file check_timing.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file synth_timing_summary.rpt
opt_design
place_design
write_checkpoint placed.dcp
phys_opt_design
route_design
write_checkpoint routed.dcp
report_utilization -file routed_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file routed_timing_summary.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 -file setup_worst20.rpt
report_timing -delay_type min -max_paths 20 -nworst 20 -file hold_worst20.rpt
report_clock_interaction -delay_type min_max -file routed_clock_interaction.rpt
report_power -file power_default_activity.rpt
puts "PPA_ROUTED_COMPLETE case=ef1 mode=0 candidate=a"
