set_fml_appmode FPV
set root $::env(THERMO5_FORMAL_ROOT)
set out $::env(THERMO5_FORMAL_OUT)
if {[file exists $out]} {error "output exists: $out"}
file mkdir $out
set sources [list [file join $root rtl dpd dpd_poly.v] [file join $root rtl dpd dpd_memory_poly.v] [file join $root research vcu118_arch formal_dpd_reset_epoch.sv] -assert svaext]
read_file -top formal_dpd_reset_epoch -format sverilog -sva -vcs $sources
create_clock clk -period 10
create_reset por_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 5m
set_fml_var fml_property_time_limit 3m
set_fml_var fml_max_mem 2GB
check_fv_setup -check {reset clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > [file join $out setup.txt]
check_fv -block
report_fv -list > [file join $out properties.txt]
