# Continue the matching parent run from its fresh synthesis checkpoint.
# The checkpoint carries its clock/I/O constraints from the source XDC.
if {[llength $argv] != 1} { error "usage: <parent_run_dir>" }
set out_dir [file normalize [lindex $argv 0]]
set synth_dcp [file join $out_dir synthesized.dcp]
if {![file exists $synth_dcp]} { error "Missing synth checkpoint: $synth_dcp" }
open_checkpoint $synth_dcp
if {[llength [get_clocks -quiet axi_clk125]] != 1 ||
    [llength [get_clocks -quiet freerun_clk200]] != 1 ||
    [llength [get_clocks -quiet core_clk218]] != 1} {
  error "Expected parent clock set missing from synthesized checkpoint"
}
set rx_user_clk [get_clocks -quiet *gtwiz_userclk_rx_inst_n_1]
if {[llength $rx_user_clk] != 1} {
  error "Expected one generated GTH RX user clock for gt_rxdata timing"
}
set_output_delay -clock $rx_user_clk -max 1.500 [get_ports {gt_rxdata[*]}]
set_output_delay -clock $rx_user_clk -min 0.000 [get_ports {gt_rxdata[*]}]
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
report_cdc -details -file [file join $out_dir cdc.rpt]
report_clock_interaction -file [file join $out_dir clock_interaction.rpt]
check_timing -verbose -file [file join $out_dir check_timing.rpt]
report_methodology -file [file join $out_dir methodology.rpt]
report_drc -file [file join $out_dir drc.rpt]
write_checkpoint -force [file join $out_dir routed.dcp]
puts "THERMO5_QSFP_PARENT_ROUTE_COMPLETE=$out_dir"
