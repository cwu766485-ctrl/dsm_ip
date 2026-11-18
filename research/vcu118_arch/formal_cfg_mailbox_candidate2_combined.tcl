set_fml_appmode FPV
set root $::env(MAILBOX_FORMAL_ROOT)
set out $::env(MAILBOX_FORMAL_OUT)
file mkdir $out
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error -verbosity verbose
set sources [list [file join $root rtl axis dsm_reset_sync.sv] [file join $root research vcu118_arch thermo5_dpd_axi_lite_cfg_epoch_candidate2.sv] [file join $root research vcu118_arch formal_cfg_mailbox_candidate2_combined.sv] -assert svaext]
read_file -top formal_cfg_mailbox_candidate2_combined -format sverilog -sva -vcs $sources
# Core 218.75 MHz and AXI-Lite 100 MHz, exact period ratio 16:35.
create_clock axil_clk -period 35
create_clock core_clk -period 16
create_reset rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 18m
set_fml_var fml_property_time_limit 15m
set_fml_var fml_max_mem 2GB
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > [file join $out setup.txt]
check_fv -block
report_fv -list > [file join $out properties.txt]
