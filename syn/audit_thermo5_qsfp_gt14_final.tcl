# Read-only post-route audit for the exact four-GTH parent checkpoint.
if {[llength $argv] != 1} { error "usage: <parent_run_dir>" }
set out_dir [file normalize [lindex $argv 0]]
set dcp [file join $out_dir routed.dcp]
if {![file exists $dcp]} { error "Missing routed checkpoint: $dcp" }
open_checkpoint $dcp
report_methodology -file [file join $out_dir methodology.rpt]
report_drc -file [file join $out_dir drc.rpt]
report_timing -delay_type max -max_paths 10 \
  -file [file join $out_dir worst_setup_paths.rpt]
report_timing -delay_type min -max_paths 10 \
  -file [file join $out_dir worst_hold_paths.rpt]
puts "THERMO5_QSFP_FINAL_AUDIT_COMPLETE=$out_dir"
