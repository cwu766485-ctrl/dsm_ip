# Post-route FPGA CDC audit for one explicit frozen-SKU checkpoint.
# Usage: vivado -mode batch -source syn/report_thermo5_cdc.tcl -tclargs <routed.dcp> <output-dir>
if {$argc != 2} { error "Expected routed checkpoint and output directory" }
set checkpoint [file normalize [lindex $argv 0]]
set output_dir [file normalize [lindex $argv 1]]
if {![file isfile $checkpoint]} { error "Checkpoint not found: $checkpoint" }
file mkdir $output_dir
open_checkpoint $checkpoint
report_cdc -details -file [file join $output_dir cdc.rpt]
report_clock_interaction -file [file join $output_dir clock_interaction.rpt]
report_timing_summary -file [file join $output_dir timing_summary.rpt]
puts "THERMO5_CDC_REPORTS_WRITTEN $output_dir"
close_design
