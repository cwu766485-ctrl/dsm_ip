set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
fv_setup_config -check reset -disable
read_file -top thermo5_rdc_dpd_epoch_harness -format sverilog -sva -vcs [list $repo/rtl/dpd/dpd_poly.v $repo/rtl/dpd/dpd_memory_poly.v $repo/dv/uvm/formal/thermo5_rdc_dpd_epoch_harness.sv -assert svaext]
create_clock clk -period 8
create_reset boot_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_max_time 90s
set_fml_var fml_property_time_limit 60s
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt
check_fv -block
report_fv -list > $out/properties.txt
exit
