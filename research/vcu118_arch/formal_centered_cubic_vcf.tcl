set_fml_appmode FPV
set root $::env(CUBIC_FORMAL_ROOT)
set out $::env(CUBIC_FORMAL_OUT)
file mkdir $out
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error -verbosity verbose
set sources [list [file join $root research vcu118_arch centered_cubic_midpoint_candidate.sv] [file join $root research vcu118_arch formal_centered_cubic_clocked.sv]]
read_file -top formal_centered_cubic_clocked -format sverilog -sva -vcs $sources
create_clock clk -period 10
sim_run -stable
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 5m
set_fml_var fml_property_time_limit 4m
set_fml_var fml_max_mem 4GB
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > [file join $out setup.txt]
check_fv -block
report_fv -list > [file join $out properties.txt]
