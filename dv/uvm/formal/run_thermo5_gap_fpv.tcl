set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
if {![info exists ::env(THERMO5_FORMAL_TOP)] || ![info exists ::env(THERMO5_FORMAL_OUT)]} {
  error "Set THERMO5_FORMAL_TOP and THERMO5_FORMAL_OUT"
}
set top $::env(THERMO5_FORMAL_TOP)
set out $::env(THERMO5_FORMAL_OUT)
file mkdir $out
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error -verbosity verbose
set sources [list [file join $repo rtl axis dsm_reset_sync.sv] \
  [file join $repo rtl dpd dpd_poly.v] \
  [file join $repo rtl dpd dpd_memory_poly.v] \
  [file join $repo rtl axis dsm_async_fifo.sv] \
  [file join $repo rtl axis dsm_axis14_to_core8_cdc.sv] \
  [file join $repo dv uvm formal thermo5_gap_harness.sv] -assert svaext]
read_file -top $top -format sverilog -sva -vcs $sources
if {$top eq "thermo5_cdc_residual_harness"} {
  # Exact 7:4 period ratio (125:218.75 MHz), scaled to integral periods.
  # The rounded 4.572-ns period creates a large unnecessary formal time grid.
  create_clock s_axis_aclk -period 14
  create_clock core_clk -period 8
} else {
  create_clock clk -period 10
}
if {$top eq "thermo5_reset_gap_harness"} {
  create_reset boot_n -sense low
} else {
  create_reset rst_n -sense low
}
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 5m
set_fml_var fml_property_time_limit 1m
set_fml_var fml_max_mem 8GB
set_fml_var fml_cov_gen_trace on
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt
check_fv -block
report_fv -list > $out/properties.txt
report_fml_engines -list -no_summary > $out/engines.txt
