set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
set top $::env(THERMO5_FORMAL_TOP)
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error
set sources [list $repo/rtl/axis/dsm_reset_sync.sv $repo/rtl/axis/dsm_async_fifo.sv \
  $repo/rtl/axis/dsm_xpm_async_fifo.sv $repo/rtl/axis/dsm_axis14_to_core8_cdc.sv \
  $repo/rtl/dpd/dpd_poly.v $repo/rtl/dpd/dpd_memory_poly.v \
  $repo/rtl/interp/dsm_interp_x2_polyphase_vector.sv \
  $repo/dv/uvm/formal/thermo5_gap_harness.sv \
  $repo/dv/uvm/formal/thermo5_convergence_harness.sv]
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
set_fml_var fml_max_mem 8GB
set_fml_var fml_cov_gen_trace on
if {[info exists ::env(THERMO5_AUTO_LEMMAS)]} {
  set_fml_var fml_max_time 1m
  set_fml_var fml_property_time_limit 30s
}
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt
check_fv -block
report_fv -list > $out/properties.txt
if {$top eq "thermo5_identity_lemmas_harness" && [info exists ::env(THERMO5_AUTO_LEMMAS)]} {
  set promoted {}
  for {set stage 1} {$stage <= 9} {incr stage} {
    set input [expr {$stage == 1 ? "$out/properties.txt" : "$out/properties_stage[expr {$stage-1}].txt"}]
    set fd [open $input]; set report [read $fd]; close $fd
    set new {}
    foreach line [split $report "\n"] {
      if {[regexp {\] proven .* -  (thermo5_identity_lemmas_harness\.a_\S+)} $line all name] && $name ni $promoted} {
        lappend new $name
      }
    }
    if {[llength $new] == 0} {break}
    set trace [open $out/promotions.txt a]
    foreach name $new {
      puts $trace "$stage $input $name"
      fvassume $name
      lappend promoted $name
    }
    close $trace
    check_fv -block
    report_fv -list > $out/properties_stage${stage}.txt
  }
  report_fv -list > $out/properties_compositional.txt
}
if {$top eq "thermo5_identity_lemmas_harness" && [info exists ::env(THERMO5_PROVEN_LEMMAS)]} {
  # Acyclic assume-guarantee: promote only independently proven assertions.
  foreach name $::env(THERMO5_PROVEN_LEMMAS) {
    fvassume $top.$name
  }
  check_fv -block
  report_fv -list > $out/properties_compositional.txt
}
