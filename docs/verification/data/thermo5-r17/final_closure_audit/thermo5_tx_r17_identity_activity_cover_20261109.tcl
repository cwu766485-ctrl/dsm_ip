set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
set top $::env(THERMO5_FORMAL_TOP)
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error
set sources [list $repo/rtl/axis/dsm_reset_sync.sv $repo/rtl/axis/dsm_async_fifo.sv \
  $repo/rtl/axis/dsm_xpm_async_fifo.sv $repo/rtl/axis/dsm_axis14_to_core8_cdc.sv \
  $repo/rtl/dpd/dpd_poly.v $repo/rtl/dpd/dpd_memory_poly.v \
  $repo/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv \
  $repo/rtl/interp/dsm_interp_x2_polyphase_vector.sv]
switch -- $top {
  thermo5_identity_lemmas_harness {
    lappend sources $repo/dv/uvm/formal/thermo5_dpd_identity_harness.sv \
      $::env(THERMO5_FORMAL_OUT)/harness_activity.sv
  }
  thermo5_identity_nostall_harness {
    lappend sources $repo/dv/uvm/formal/thermo5_dpd_identity_nostall_harness.sv
  }
  thermo5_interp_bounds_harness {
    lappend sources $repo/dv/uvm/formal/thermo5_interp_bounds_harness.sv
  }
  thermo5_xpm_fwft_harness - thermo5_xpm_reset_contract_harness - thermo5_xpm_cdc_residual_harness {
    lappend sources $repo/dv/uvm/formal/thermo5_xpm_fifo_harness.sv
  }
  default { error "Unknown thermo5 convergence formal top: $top" }
}
if {[string match *xpm* $top]} {
  set vendor $::env(THERMO5_XPM_ROOT)
  lappend sources $vendor/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv \
    $vendor/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv \
    $vendor/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv
}
lappend sources -assert svaext
read_file -top $top -format sverilog -sva -vcs $sources
if {$top eq "thermo5_xpm_reset_contract_harness" || $top eq "thermo5_xpm_fwft_harness"} {
  create_clock wr_clk -period 14
  create_clock rd_clk -period 8
  create_reset boot_n -sense low
} elseif {$top eq "thermo5_xpm_cdc_residual_harness"} {
  create_clock s_axis_aclk -period 14
  create_clock core_clk -period 8
  create_reset rst_n -sense low
} else {
  create_clock clk -period 10
  create_reset rst_n -sense low
}
if {$top eq "thermo5_xpm_fwft_harness"} {
  # The wrapper's reset synchronizers are synchronous; -stable alone can stop
  # at a fixed point before reset has crossed both clocks into vendor state.
  sim_run 40
}
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 2m
set_fml_var fml_property_time_limit 1m
if {$top eq "thermo5_identity_lemmas_harness"} {
  set_fml_var fml_max_time 1m
  set_fml_var fml_property_time_limit 30s
}
if {$top eq "thermo5_identity_nostall_harness"} {
  set_fml_var fml_max_time 2m
  set_fml_var fml_property_time_limit 1m
}
set_fml_var fml_max_mem 8GB
set_fml_var fml_cov_gen_trace on
if {[info exists ::env(THERMO5_AUTO_LEMMAS)]} {
  set_fml_var fml_max_time 1m
  set_fml_var fml_property_time_limit 30s
}
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt
set witness_props {
 thermo5_identity_lemmas_harness.c_stage7_transfer_active
 thermo5_identity_lemmas_harness.c_stage7_identity_active
 thermo5_identity_lemmas_harness.c_stage8_identity_active
 thermo5_identity_lemmas_harness.c_stage9_identity_active
 thermo5_identity_lemmas_harness.c_stage10_identity_active
}
set_fml_var fml_witness_on true
check_fv -property $witness_props  -block
report_fv -list > $out/activity_witnesses.txt
