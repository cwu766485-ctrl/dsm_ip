# Re-time a routed diagnostic DCP with only the declared asynchronous
# AXI/core relationship. This does not change placement or routing.
if {[llength $argv] != 1} { error "usage: <parent_run_dir>" }
set out_dir [file normalize [lindex $argv 0]]
set dcp [file join $out_dir routed.dcp]
if {![file exists $dcp]} { error "Missing routed checkpoint: $dcp" }
open_checkpoint $dcp
if {[llength [get_clocks -quiet axi_clk125]] != 1 ||
    [llength [get_clocks -quiet core_clk218]] != 1} {
  error "Expected AXI and GT-user clocks missing from routed DCP"
}
set_clock_groups -asynchronous -group [get_clocks axi_clk125] \
  -group [get_clocks core_clk218]
report_timing_summary -file [file join $out_dir timing_async_group.rpt]
report_clock_interaction -file [file join $out_dir clock_interaction_async_group.rpt]
check_timing -verbose -file [file join $out_dir check_timing_async_group.rpt]
puts "THERMO5_QSFP_ASYNC_GROUP_TIMING_COMPLETE=$out_dir"
