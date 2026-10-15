# Read-only validation/reporting for a thermo5 AXI-Lite synthesis checkpoint.
if {[llength $argv] ni {2 5}} {
  error "usage: <synthesized.dcp> <utilization_report.rpt> ?timing_summary.rpt timing_paths.rpt check_timing.rpt?"
}
set checkpoint [file normalize [lindex $argv 0]]
set report [file normalize [lindex $argv 1]]
if {![file exists $checkpoint]} { error "checkpoint not found: $checkpoint" }
open_checkpoint $checkpoint
report_utilization -file $report
if {[llength $argv] == 5} {
  set timing_summary [file normalize [lindex $argv 2]]
  set timing_paths [file normalize [lindex $argv 3]]
  set timing_checks [file normalize [lindex $argv 4]]
  report_timing_summary -report_unconstrained -file $timing_summary
  report_timing -max_paths 30 -file $timing_paths
  check_timing -verbose -file $timing_checks
}
puts "THERMO5_AXIL_CHECKPOINT_VALIDATED=[current_design]"
close_design
exit 0
