set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set top thermo5_cdc_end_branch_harness
set out $::env(THERMO5_FORMAL_OUT)
file mkdir $out
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error -verbosity verbose
set sources [list [file join $repo rtl axis dsm_reset_sync.sv] \
  [file join $repo rtl axis dsm_async_fifo.sv] \
  [file join $repo rtl axis dsm_axis14_to_core8_cdc.sv] \
  [file join $repo dv uvm formal thermo5_cdc_end_branch_harness.sv]]
lappend sources -assert svaext
read_file -top $top -format sverilog -sva -vcs $sources
create_clock s_axis_aclk -period 14
create_clock core_clk -period 8
create_reset rst_n -sense low
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
