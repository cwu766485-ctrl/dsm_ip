set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
file mkdir $out
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error
read_file -top thermo5_dpd_invalid_zero_harness -format sverilog -sva -vcs [list $repo/rtl/dpd/dpd_poly.v $repo/rtl/dpd/dpd_memory_poly.v $repo/dv/uvm/formal/thermo5_dpd_invalid_zero_harness.sv]
create_clock clk -period 4.571
create_reset rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_max_time 2m
set_fml_var fml_property_time_limit 60s
set_fml_var fml_max_mem 8GB
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt
check_fv -block
report_fv -list > $out/properties.txt
report_fml_engines -list -no_summary > $out/engines.txt

# Promote only lemmas independently proven in the unassumed base run.
set fd [open $out/properties.txt r]
set results [read $fd]
close $fd
set lemmas {a_enable0 a_enable1 a_enable2 a_enable3 a_enable4 a_enable5 a_enable6 a_enable7 a_invalid_term_zero a_invalid_pair_zero}
foreach name $lemmas {
  set pattern [format {\][[:space:]]*proven.*-[[:space:]]+thermo5_dpd_invalid_zero_harness.%s($|[[:space:]])} $name]
  if {![regexp $pattern $results]} {error "Unproven alignment lemma: $name"}
}
foreach name $lemmas {fvassume thermo5_dpd_invalid_zero_harness.$name}
check_fv -block
report_fv -list > $out/properties_composed.txt
report_fml_engines -list -no_summary > $out/engines_composed.txt
