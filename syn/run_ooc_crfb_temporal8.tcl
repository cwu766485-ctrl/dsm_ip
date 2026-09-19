if {[llength $argv] != 4} {error "usage: <part> <target_mhz> <steps> <out_dir>"}
set part [lindex $argv 0]; set target_mhz [lindex $argv 1]; set steps [lindex $argv 2]; set out_dir [file normalize [lindex $argv 3]]
set root [file normalize [file join [file dirname [info script]] ..]]; file mkdir $out_dir
read_verilog -sv [file join $root rtl tx_bandpass_if crfb_smash2_temporal8.sv]
read_verilog -sv [file join $root syn rtl crfb_smash2_temporal8_ooc.sv]
synth_design -top crfb_smash2_temporal8_ooc -part $part -mode out_of_context -flatten_hierarchy none -generic STEPS=$steps
set period_ns [expr {1000.0/$target_mhz}]; create_clock -name clk -period $period_ns [get_ports clk]
opt_design
# The scalar exact path misses by less than 1 ns.  Use the strongest standard
# placement/routing search before concluding that arithmetic restructuring is
# required; this does not alter the transition or its latency.
place_design -directive Explore
phys_opt_design -directive AggressiveExplore
route_design -directive Explore
phys_opt_design -directive AggressiveExplore
report_timing_summary -file [file join $out_dir timing_summary.rpt]; report_utilization -file [file join $out_dir utilization.rpt]
set wns [get_property SLACK [get_timing_paths -max_paths 1 -delay_type max]]; set whs [get_property SLACK [get_timing_paths -max_paths 1 -delay_type min]]
set status [expr {$wns >= 0 && $whs >= 0 ? "PASS" : "FAIL"}]; set fp [open [file join $out_dir summary.csv] w]
puts $fp "part,top,steps,target_mhz,status,wns_ns,whs_ns"; puts $fp "$part,crfb_smash2_temporal8_ooc,$steps,$target_mhz,$status,$wns,$whs"; close $fp
puts "CRFB_TEMPORAL8_OOC_STATUS=$status"
