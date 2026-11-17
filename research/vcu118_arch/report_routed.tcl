# Non-destructive post-route analysis of a single completed study DCP.
if {[llength $argv]!=2} {error "usage: <routed.dcp> <new-output-dir>"}
set dcp [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
if {![file exists $dcp]} {error "routed checkpoint missing"}
if {[file exists $out]} {error "refusing to overwrite output"}
file mkdir $out
open_checkpoint $dcp
set core [get_clocks core_clk]
set paths [get_timing_paths -from $core -to $core -delay_type max -max_paths 1]
if {[llength $paths]!=1} {error "missing core setup path"}
set slack [get_property SLACK [lindex $paths 0]]
set period [get_property PERIOD $core]
set denominator [expr {$period-$slack}]
if {$denominator<=0} {error "invalid core Fmax denominator"}
set f [open [file join $out core_fmax.csv] w]
puts $f "core_period_ns,core_setup_wns_ns,estimated_core_fmax_mhz"
puts $f "$period,$slack,[expr {1000.0/$denominator}]"
close $f
report_timing -from $core -to $core -delay_type max -max_paths 20 -nworst 20 -file [file join $out core_setup_worst20.rpt]
report_timing -from $core -to $core -delay_type min -max_paths 20 -nworst 20 -file [file join $out core_hold_worst20.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out timing_summary.rpt]
report_exceptions -file [file join $out exceptions.rpt]
puts "ROUTED_CORE_ANALYSIS_COMPLETE period_ns=$period core_wns=$slack core_fmax_mhz=[expr {1000.0/$denominator}]"
