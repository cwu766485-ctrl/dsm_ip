set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
file mkdir $out
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error
read_file -top thermo5_gain_metadata_v2_harness -format sverilog -sva -vcs [list \
  $repo/rtl/frontend/dsm_frame_gain_vector.sv \
  $repo/dv/uvm/formal/thermo5_gain_metadata_v2_harness.sv -assert svaext]
create_clock clk -period 8
create_reset rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 3m
set_fml_var fml_property_time_limit 90s
set_fml_var fml_max_mem 8GB
set_fml_var fml_cov_gen_trace on
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt
check_fv -block
report_fv -list > $out/properties.txt
report_fml_engines -list > $out/engines.txt
