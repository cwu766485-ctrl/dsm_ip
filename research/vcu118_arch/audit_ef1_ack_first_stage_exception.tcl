# Explore exactly one first-stage async ACK exception on a routed checkpoint.
# This does not alter/re-route the DCP or sign off other CDC/RDC paths.
if {[llength $argv] != 2} {error "usage: <routed-dcp> <new-output-dir>"}
set dcp [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
if {![file exists $dcp] || [file exists $out]} {error "missing DCP or output exists"}
file mkdir $out
cd $out
set_param general.maxThreads 1
open_checkpoint $dcp
set src [get_cells -hier -filter {NAME =~ *u_cfg/cfg_ack_core_reg}]
set first [get_cells -hier -filter {NAME =~ *u_cfg/cfg_ack_sync1_reg}]
set second [get_cells -hier -filter {NAME =~ *u_cfg/cfg_ack_sync2_reg}]
foreach obj [list $src $first $second] {if {[llength $obj] != 1} {error "ACK endpoint selection is not unique"}}
set first_async [get_property ASYNC_REG $first]
set second_async [get_property ASYNC_REG $second]
puts "ACK_ASYNC_REG first=$first_async second=$second_async"
if {![string is boolean -strict $first_async] || ![string is boolean -strict $second_async]} {error "ACK synchronizer ASYNC_REG is not boolean"}
if {!$first_async || !$second_async} {error "ACK synchronizer ASYNC_REG property absent"}
set_false_path -from $src -to $first
report_exceptions -file exceptions.rpt
report_clock_interaction -delay_type min_max -file clock_interaction.rpt
report_timing -from $first -to $second -delay_type max -max_paths 5 -file ack_sync_stages_setup.rpt
report_timing -from $first -to $second -delay_type min -max_paths 5 -file ack_sync_stages_hold.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 -file setup_worst20.rpt
report_timing -delay_type min -max_paths 20 -nworst 20 -file hold_worst20.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file timing_summary.rpt
check_timing -verbose -file check_timing.rpt
puts "ACK_FIRST_STAGE_AUDIT_COMPLETE"
