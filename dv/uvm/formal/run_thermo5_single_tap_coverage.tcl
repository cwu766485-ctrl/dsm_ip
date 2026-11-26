set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
read_file -top thermo5_single_tap_coverage_harness -format sverilog -sva -vcs [list \
  [file join $repo rtl dpd dpd_poly.v] \
  [file join $repo rtl dpd dpd_memory_poly.v] \
  [file join $repo dv uvm formal thermo5_single_tap_coverage_harness.sv] -assert svaext]
create_clock clk -period 10
create_reset rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_max_time 2m
set_fml_var fml_property_time_limit 1m
check_fv -block
report_fv -list > properties.txt
