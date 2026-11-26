set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
set top thermo5_v14_cubic_chain_harness
file mkdir $out
set files [open [file join $repo dv uvm sim thermo5_sku_filelist.f] r]
set rtl [list]
foreach entry [split [read $files] "\n"] {
  set entry [string trim $entry]
  if {[string match rtl/* $entry]} { lappend rtl [file join $repo $entry] }
}
close $files
lappend rtl [file join $repo dv uvm formal ${top}.sv] -assert svaext
read_file -top $top -format sverilog -sva -vcs $rtl
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error
create_clock clk -period 4.572
create_reset rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_cov_gen_trace on
set_fml_var fml_max_time 4m
set_fml_var fml_property_time_limit 3m
set_fml_var fml_max_mem 8GB
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $out/setup.txt
check_fv -block
report_fv -list > $out/properties.txt
report_fml_engines -list -no_summary > $out/engines.txt
save_trace -dir $out/traces -full
