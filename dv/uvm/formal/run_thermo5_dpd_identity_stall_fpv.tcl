set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
set top thermo5_dpd_identity_stall_harness
file mkdir $out

fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error -verbosity verbose
read_file -top $top -format sverilog -sva -vcs [list \
  $repo/rtl/dpd/dpd_poly.v \
  $repo/rtl/dpd/dpd_memory_poly.v \
  $repo/dv/uvm/formal/$top.sv]
create_clock clk -period 10
create_reset rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 2m
set_fml_var fml_property_time_limit 60s
set_fml_var fml_max_mem 8GB
set_fml_var fml_cov_gen_trace on
set_fml_var fml_effort high
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt

# First prove every listed internal lemma against RTL with only the legal
# source ready/valid contract. The four public output/saturation properties
# are intentionally excluded from this promotion list.
check_fv -block
report_fv -list > $out/properties_base.txt
set fd [open $out/properties_base.txt r]
set base [read $fd]
close $fd
set lemmas {
  a_coeff0 a_coeff1 a_coeff2 a_coeff3 a_coeff4
  a_cross_i7 a_cross_q7
  a_gain5 a_gain6 a_gain_c5_zero5
  a_i0 a_i1 a_i2 a_i3 a_i4 a_i5 a_i6
  a_q0 a_q1 a_q2 a_q3 a_q4 a_q5 a_q6
  a_pair_i9 a_pair_q9
  a_prod_i7 a_prod_q7
  a_sum_i10 a_sum_q10
  a_term_i8 a_term_q8
  a_v0 a_v1 a_v2 a_v3 a_v4 a_v5 a_v6 a_v7
  a_valid_latency
}
if {[llength $lemmas] != 41} {
  error "internal lemma allowlist changed: expected 41, got [llength $lemmas]"
}
foreach name $lemmas {
  set full "$top.$name"
  set pattern [format {\][[:space:]]*proven.*-[[:space:]]+%s($|[[:space:]])} $full]
  if {![regexp $pattern $base]} {
    error "refusing to assume internal lemma not proven in base run: $full"
  }
}
set fd [open $out/promoted_lemmas.txt w]
foreach name $lemmas {
  set full "$top.$name"
  puts $fd $full
  fvassume $full
}
close $fd

# Re-run with only the 41 previously proven internal facts as compositional
# assumptions. The public output and saturation assertions remain active goals.
check_fv -block
report_fv -list > $out/properties_composed.txt
report_fml_engines -list -no_summary > $out/engines.txt
