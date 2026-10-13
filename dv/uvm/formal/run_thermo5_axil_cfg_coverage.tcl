set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
set top thermo5_axil_cfg_coverage_harness
file mkdir $out
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error
read_file -top $top -format sverilog -sva -vcs [list \
  $repo/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv \
  $repo/dv/uvm/formal/thermo5_axil_cfg_coverage_harness.sv]
create_clock axil_clk -period 10
create_clock core_clk -period 4.571
create_reset axil_rst_n -sense low
create_reset core_rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 5m
set_fml_var fml_property_time_limit 2m
set_fml_var fml_max_mem 8GB
set_fml_var fml_cov_gen_trace on
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt
check_fv -block
report_fv -list > $out/properties.txt
report_fml_engines -list -no_summary > $out/engines.txt
puts "THERMO5_AXIL_CFG_FORMAL_OUT=$out"
