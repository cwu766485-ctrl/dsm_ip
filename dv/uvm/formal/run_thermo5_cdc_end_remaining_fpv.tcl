set_fml_appmode FPV
set repo $::env(THERMO5_FORMAL_REPO)
set out $::env(THERMO5_FORMAL_OUT)
file mkdir $out
set sources [list \
  [file join $repo rtl axis dsm_reset_sync.sv] \
  [file join $repo rtl axis dsm_async_fifo.sv] \
  [file join $repo rtl axis dsm_axis14_to_core8_cdc.sv] \
  [file join $repo dv uvm formal thermo5_cdc_end_remaining_harness.sv]]
lappend sources -assert svaext
set top thermo5_cdc_end_remaining_harness
set scope $top
if {[info exists ::env(THERMO5_CDC_VARIABLE_CORE_CONTROL)] &&
    $::env(THERMO5_CDC_VARIABLE_CORE_CONTROL) eq "1"} {
  set top thermo5_v14_cdc_end_with_stall_harness
  set scope "$top.check_end"
}
if {[info exists ::env(THERMO5_CDC_SOURCE_GAPS)] && $::env(THERMO5_CDC_SOURCE_GAPS) eq "1"} {
  set top thermo5_v14_cdc_end_with_gaps_harness
  set scope "$top.check_end"
}
read_file -top $top -format sverilog -sva -vcs $sources
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error -verbosity verbose
create_clock s_axis_aclk -period 14
create_clock core_clk -period 8
create_reset rst_n -sense low
sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_cov_gen_trace on
set_fml_var fml_max_time 5m
set_fml_var fml_property_time_limit 1m
set_fml_var fml_max_mem 8GB
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > [file join $out setup.txt]
check_fv -block
report_fv -list > [file join $out properties.txt]
report_fml_engines -list -no_summary > [file join $out engines.txt]
if {$scope ne $top} {
  set report [file join $out properties.txt]
  foreach lemma {a_write_phase a_residual_at_pop a_tlast_pop_phase} {
    set name "$scope.g_variable_control.$lemma"
    set file [open $report r]
    set evidence [read $file]
    close $file
    foreach line [split $evidence "\n"] {
      if {[string first {] proven } $line] >= 0 && [lindex $line end] eq $name} {
        fvassume $name
        check_fv -block
        set report [file join $out "properties_$lemma.txt"]
        report_fv -list > $report
        break
      }
    }
  }
}
save_trace -dir [file join $out traces] -full
fvtrace -property "${scope}.c_target_false_arm" \
  -file [file join $out traces c_target_false_arm.fsdb]
