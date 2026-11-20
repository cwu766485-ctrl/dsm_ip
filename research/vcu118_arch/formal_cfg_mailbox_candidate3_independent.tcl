set_fml_appmode FPV
set root $::env(MAILBOX_FORMAL_ROOT)
set out $::env(MAILBOX_FORMAL_OUT)
file mkdir $out
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error -verbosity verbose
set sources [list [file join $root rtl axis dsm_reset_sync.sv] [file join $root research vcu118_arch thermo5_dpd_axi_lite_cfg_epoch_candidate3.sv] [file join $root research vcu118_arch formal_cfg_mailbox_candidate3_independent.sv] -assert svaext]
read_file -top formal_cfg_mailbox_candidate3_independent -format sverilog -sva -vcs $sources
# User contract treats clocks as unrelated. This run uses fixed periods/phase
# because the selected VC Formal engine requires explicit clock waveforms.
create_clock axil_clk -period 35 -waveform {0 17}
create_clock core_clk -period 16 -waveform {5 13}
create_reset axil_rst_n -sense low
create_reset core_rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 60m
set_fml_var fml_property_time_limit 50m
set_fml_var fml_max_mem 6GB
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > [file join $out setup.txt]
check_fv -block
report_fv -list > [file join $out properties.txt]
