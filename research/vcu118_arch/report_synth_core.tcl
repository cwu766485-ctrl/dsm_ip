if {[llength $argv]!=2} {error "usage: <synthesized.dcp> <new-output-dir>"}
set dcp [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
if {[file exists $out]} {error "refusing to overwrite"}
file mkdir $out
open_checkpoint $dcp
set core [get_clocks core_clk]
report_timing -from $core -to $core -delay_type max -max_paths 20 -nworst 20 -file [file join $out core_setup_worst20.rpt]
report_timing -from $core -to $core -delay_type min -max_paths 20 -nworst 20 -file [file join $out core_hold_worst20.rpt]
puts "SYNTH_CORE_DIAGNOSTIC_COMPLETE no_routed_claim=1"
