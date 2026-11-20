# Read-only routed-DCP STA audit with a narrowly justified XPM reset exception.
# This re-times the exact routed netlist; it does not re-place/route or save DCP.
if {[llength $argv] != 2} {error "usage: <routed-dcp> <new-output-dir>"}
set dcp [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
if {![file exists $dcp] || [file exists $out]} {error "missing DCP or output already exists"}
file mkdir $out
cd $out
set_param general.maxThreads 1
open_checkpoint $dcp

# AMD XPM FIFO reset request crosses from the opposite clock domain into
# stage zero of xpm_cdc_sync_rst. The XPM source marks syncstages_ff ASYNC_REG;
# only the asynchronous source-to-stage-zero D paths are excluded. Later
# synchronizer stages and all functional datapaths remain timed.
set stage0_cells {}
foreach c [get_cells -hier -filter {NAME =~ *xpm_fifo_rst_inst*syncstages_ff_reg*}] {
  set n [get_property NAME $c]
  if {[regexp {gen_rst_ic\.(rrst_wr_inst|wrst_rd_inst)/syncstages_ff_reg\[0\]$} $n]} {
    set attr [string toupper [get_property ASYNC_REG $c]]
    if {$attr ni {TRUE 1}} {error "XPM reset stage zero lacks ASYNC_REG: $n ($attr)"}
    lappend stage0_cells $c
  }
}
set stage0_cells [lsort -unique $stage0_cells]
if {[llength $stage0_cells] != 2} {error "expected exactly two XPM FIFO reset stage-zero cells, got [llength $stage0_cells]"}
set stage0_d [get_pins -of_objects $stage0_cells -filter {REF_PIN_NAME == D}]
if {[llength $stage0_d] != 2} {error "expected two stage-zero D pins, got [llength $stage0_d]"}
set_false_path -to $stage0_d
puts "RETIME_ONLY_XPM_FIFO_RESET_STAGE0_ENDPOINTS [llength $stage0_d]"

report_cdc -details -file routed_cdc_details.rpt
report_clock_interaction -delay_type min_max -file routed_clock_interaction.rpt
report_exceptions -file routed_exceptions.rpt
check_timing -verbose -file routed_check_timing.rpt
report_utilization -file routed_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file routed_timing_summary.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 -file routed_setup_worst20.rpt
report_timing -delay_type min -max_paths 20 -nworst 20 -file routed_hold_worst20.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 \
  -from [get_clocks core_clk] -to [get_clocks core_clk] \
  -file routed_core_setup_worst20.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 \
  -from [get_clocks core_clk] -to [get_clocks s_axis_aclk] \
  -file routed_core_to_axis_setup_worst20.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 \
  -from [get_clocks s_axil_aclk] -to [get_clocks core_clk] \
  -file routed_axil_to_core_setup_worst20.rpt
report_bus_skew -file routed_bus_skew.rpt
puts "RETIME_ONLY_AUDIT_COMPLETE; no DCP written"
