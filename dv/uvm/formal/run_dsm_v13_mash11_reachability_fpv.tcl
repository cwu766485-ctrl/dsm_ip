set_fml_appmode FPV
set repo $::env(DSM_V13_FORMAL_REPO)
set out $::env(DSM_V13_FORMAL_OUT)
set top dsm_v13_mash11_reachability_harness
file mkdir $out

read_file -top $top -format sverilog -sva -vcs [list \
  $repo/rtl/tx_bandpass_if/tid32_mash11_weighted_pa_tx.sv \
  $repo/dv/uvm/formal/dsm_v13_mash11_reachability_harness.sv]
create_clock clk -period 10
create_reset formal_reset_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 2m
set_fml_var fml_property_time_limit 60s
set_fml_var fml_max_mem 8GB
set_fml_var fml_cov_gen_trace on
set_fml_var fml_effort high
check_fv -block
report_fv -list > $out/properties.txt
report_fml_engines -list -no_summary > $out/engines.txt
