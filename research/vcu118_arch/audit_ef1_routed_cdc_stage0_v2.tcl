# Read-only CDC/STA audit for a routed EF1 OOC DCP. Newly excluded paths end
# only at verified first-stage D pins of explicitly asynchronous CDC chains.
# Existing routed-DCP constraints already cut the arch_locked_c1 first stage.
if {[llength $argv] != 2} {error "usage: <routed-dcp> <new-output-dir>"}
set dcp [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
if {![file isfile $dcp]} {error "routed DCP not found: $dcp"}
if {[file exists $out]} {error "refusing to overwrite output directory: $out"}
file mkdir $out
open_checkpoint $dcp

proc require_async_stage0_d {pattern label} {
  set cells [get_cells -hier -filter "NAME =~ $pattern"]
  if {[llength $cells] != 1} {error "$label: expected one synchronizer cell, found [llength $cells]"}
  set c [lindex $cells 0]
  set attr [string toupper [get_property ASYNC_REG $c]]
  if {$attr ni {TRUE 1}} {error "$label: cell lacks ASYNC_REG: [get_property NAME $c] ($attr)"}
  set d [get_pins -of_objects $c -filter {REF_PIN_NAME == D}]
  if {[llength $d] != 1} {error "$label: expected one D pin"}
  puts "VERIFIED_ASYNC_STAGE0 label=$label cell=[get_property NAME $c] ASYNC_REG=$attr D=$d"
  return $d
}

set stage0_d {}
foreach c [get_cells -hier -filter {NAME =~ *syncstages_ff_reg*}] {
  set n [get_property NAME $c]
  if {![regexp {xpm_fifo_rst_inst/.*gen_rst_ic\.(rrst_wr_inst|wrst_rd_inst)/syncstages_ff_reg\[0\]$} $n]} {continue}
  set attr [string toupper [get_property ASYNC_REG $c]]
  if {$attr ni {TRUE 1}} {error "XPM FIFO reset stage lacks ASYNC_REG: $n ($attr)"}
  set d [get_pins -of_objects $c -filter {REF_PIN_NAME == D}]
  if {[llength $d] != 1} {error "XPM FIFO reset stage expected one D pin: $n"}
  lappend stage0_d $d
  puts "VERIFIED_ASYNC_STAGE0 label=xpm_fifo_reset cell=$n ASYNC_REG=$attr D=$d"
}
if {[llength $stage0_d] != 2} {error "expected two XPM FIFO reset stage-0 cells, found [llength $stage0_d]"}

foreach {pattern label} {
  *run_s1_reg axil_run_to_axis
  *arch_lock_s1_reg axil_mode_busy_to_axis
  *ingress_closed_c1_reg axis_drain_status_to_core
  *source_error_c1_reg axis_error_status_to_core
  *arch_locked_c1_reg axis_mode_lock_to_core
} {
  lappend stage0_d [require_async_stage0_d $pattern $label]
}
set_false_path -to $stage0_d
puts "EXACT_ASYNC_STAGE0_FALSE_PATH_ENDPOINTS [llength $stage0_d]"

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
puts "EF1_ROUTED_CDC_STAGE0_AUDIT_V2_COMPLETE"
