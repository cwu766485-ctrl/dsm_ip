set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
set top thermo5_source_frame_contract_harness
file mkdir $out
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error -verbosity verbose
read_file -top $top -format sverilog -sva -vcs [list \
  $repo/rtl/axis/dsm_reset_sync.sv \
  $repo/rtl/axis/dsm_async_fifo.sv \
  $repo/rtl/axis/dsm_axis14_to_core8_cdc.sv \
  $repo/rtl/frontend/dsm_frame_gain_vector.sv \
  $repo/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv \
  $repo/rtl/interp/dsm_interp_x2_polyphase_vector.sv \
  $repo/rtl/dpd/dpd_poly.v \
  $repo/rtl/dpd/dpd_memory_poly.v \
  $repo/rtl/dpd/dpd_vector16_memory_poly.sv \
  $repo/rtl/gt/gt_tx_user_bridge.sv \
  $repo/rtl/gt/gt_tx_raw64_boundary.sv \
  $repo/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv \
  $repo/rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv \
  $repo/rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv \
  $repo/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv \
  $repo/rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv \
  $repo/dv/uvm/formal/thermo5_source_frame_contract_harness.sv]
create_clock axil_clk -period 35
create_clock source_clk -period 28
create_clock core_clk -period 16
create_reset rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 8m
set_fml_var fml_property_time_limit 5m
set_fml_var fml_max_mem 8GB
set_fml_var fml_cov_gen_trace on
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt
check_fv -block
report_fv -list > $out/properties.txt
report_fml_engines -list -no_summary > $out/engines.txt
puts "THERMO5_SOURCE_FRAME_CONTRACT_OUT=$out"
