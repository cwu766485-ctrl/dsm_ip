set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error
set sources [list [file join $repo rtl gt gt_tx_user_bridge.sv] [file join $repo rtl gt gt_tx_raw64_boundary.sv] [file join $repo rtl tx_bandpass_if tid32_cartesian_ef2_fs4_gt_tx.sv] [file join $repo dv uvm formal thermo5_ef2_32lane_equiv_harness.sv] -assert svaext]
read_file -top thermo5_ef2_32lane_equiv_harness -format sverilog -sva -vcs $sources
create_clock clk -period 10
create_reset rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 5m
set_fml_var fml_property_time_limit 2m
set_fml_var fml_max_mem 2GB
set_fml_var fml_cov_gen_trace on
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt
check_fv -block
report_fv -list > $out/properties.txt
report_fml_engines -list > $out/engines.txt
exit
