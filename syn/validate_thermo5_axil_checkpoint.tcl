# Read-only validation of a completed thermo5 AXI-Lite synthesis checkpoint.
if {[llength $argv] != 2} {
  error "usage: <synthesized.dcp> <utilization_report.rpt>"
}
set checkpoint [file normalize [lindex $argv 0]]
set report [file normalize [lindex $argv 1]]
if {![file exists $checkpoint]} { error "checkpoint not found: $checkpoint" }
open_checkpoint $checkpoint
report_utilization -file $report
puts "THERMO5_AXIL_CHECKPOINT_VALIDATED=[current_design]"
close_design
exit 0
