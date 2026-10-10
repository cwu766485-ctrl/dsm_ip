# Apply a post-route, data-path-only hold repair to a completed parent route.
# This preserves RTL, latency, fixed-point arithmetic and functional behavior.
if {[llength $argv] != 1} { error "usage: <parent_run_dir>" }
set out_dir [file normalize [lindex $argv 0]]
set routed_dcp [file join $out_dir routed.dcp]
if {![file exists $routed_dcp]} { error "Missing routed checkpoint: $routed_dcp" }

open_checkpoint $routed_dcp
phys_opt_design -hold_fix
report_timing_summary -file [file join $out_dir timing_summary_holdfix.rpt]
report_cdc -details -file [file join $out_dir cdc_holdfix.rpt]
check_timing -verbose -file [file join $out_dir check_timing_holdfix.rpt]
report_methodology -file [file join $out_dir methodology_holdfix.rpt]
report_drc -file [file join $out_dir drc_holdfix.rpt]
write_checkpoint -force [file join $out_dir routed_holdfix.dcp]
puts "THERMO5_QSFP_PARENT_HOLDFIX_COMPLETE=$out_dir"
