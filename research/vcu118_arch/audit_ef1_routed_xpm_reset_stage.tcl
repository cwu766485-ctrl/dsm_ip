# Read-only timing audit for the EF1 routed OOC DCP. Apply a false path only
# to the verified stage-0 D pins of the two AMD XPM_CDC_SYNC_RST instances
# that transfer remote FIFO reset indications into the opposite clock domain.
if {[llength $argv] != 2} {error "usage: <routed-dcp> <new-output-dir>"}
set dcp [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
if {![file isfile $dcp]} {error "routed DCP not found: $dcp"}
if {[file exists $out]} {error "refusing to overwrite output directory: $out"}
file mkdir $out
open_checkpoint $dcp

set stage0_cells {}
foreach c [get_cells -hier -filter {NAME =~ *syncstages_ff_reg*}] {
  set n [get_property NAME $c]
  if {![regexp {xpm_fifo_rst_inst/.*gen_rst_ic\.(rrst_wr_inst|wrst_rd_inst)/syncstages_ff_reg\[0\]$} $n]} {
    continue
  }
  set attr [string toupper [get_property ASYNC_REG $c]]
  if {$attr ni {TRUE 1}} {error "stage-0 XPM reset cell lacks ASYNC_REG: $n ($attr)"}
  lappend stage0_cells $c
}
if {[llength $stage0_cells] != 2} {
  error "expected exactly two FIFO remote-reset XPM stage-0 cells, found [llength $stage0_cells]"
}
set stage0_d {}
foreach c $stage0_cells {
  set d [get_pins -of_objects $c -filter {REF_PIN_NAME == D}]
  if {[llength $d] != 1} {error "expected one D pin for [get_property NAME $c]"}
  lappend stage0_d $d
  puts "VERIFIED_XPM_RESET_STAGE0 cell=[get_property NAME $c] ASYNC_REG=[get_property ASYNC_REG $c] D=$d"
}
set_false_path -to $stage0_d
puts "EXACT_XPM_RESET_STAGE0_FALSE_PATHS [llength $stage0_d]"

report_exceptions -file [file join $out exceptions.rpt]
report_clock_interaction -delay_type min_max -file [file join $out clock_interaction.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out routed_timing_summary.rpt]
report_timing -delay_type max -max_paths 20 -nworst 20 -file [file join $out setup_worst20.rpt]
report_timing -delay_type min -max_paths 20 -nworst 20 -file [file join $out hold_worst20.rpt]
report_timing -delay_type max -max_paths 20 -nworst 20 \
  -from [get_clocks core_clk] -to [get_clocks core_clk] \
  -file [file join $out core_setup_worst20.rpt]
report_bus_skew -file [file join $out bus_skew.rpt]
puts "EF1_ROUTED_XPM_RESET_AUDIT_COMPLETE"
