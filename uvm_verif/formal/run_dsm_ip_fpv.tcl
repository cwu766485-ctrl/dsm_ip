set_fml_appmode FPV

set design dsm_ip_formal_harness
set report_dir uvm_verif/formal/out/dsm_ip_fpv
file mkdir $report_dir

# core_rst_n includes the AXI-programmable soft reset.  It is intentionally
# allowed to assert after initialization and is checked by dedicated SVA.
# The generic setup reset check assumes initialization-only resets, so keep
# every other setup check enabled as an error and exclude only that category.
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} \
  -enable -severity error -verbosity verbose

read_file -top $design -format sverilog -sva -vcs \
  {-f uvm_verif/formal/dsm_formal_filelist.f -assert svaext}

create_clock aclk -period 10
create_reset aresetn -sense low

sim_run -stable
sim_save_reset

set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 10m
set_fml_var fml_property_time_limit 2m
set_fml_var fml_max_mem 8GB
set_fml_var fml_cov_gen_trace on

check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > $report_dir/report_fv_setup.txt

check_fv -block
report_fv -list > $report_dir/report_fv.txt
report_fml_engines -list -no_summary > $report_dir/report_engines.txt
file delete -force $report_dir/counterexamples
file delete -force $report_dir/counterexample_fsdb
set report_fd [open $report_dir/report_fv.txt r]
set report_text [read $report_fd]
close $report_fd
if {[regexp {falsified|inconclusive|undetermined|unprocessed} $report_text]} {
  if {[catch {
    save_trace -dir $report_dir/counterexamples -filter {type == assert}
  } save_error]} {
    puts stderr "WARNING: failed to save assertion traces: $save_error"
  }
  file mkdir $report_dir/counterexample_fsdb
  foreach {trace_name property_name} {
    bank_ack       dsm_ip_formal_harness.control_sva.a_bank_change_is_acknowledged
    bank_guard     dsm_ip_formal_harness.control_sva.a_bank_change_requires_commit
    epoch_guard    dsm_ip_formal_harness.control_sva.a_epoch_change_requires_success
    epoch_update   dsm_ip_formal_harness.control_sva.a_commit_success_updates_epoch
    failure_bank   dsm_ip_formal_harness.control_sva.a_failed_commit_keeps_bank
  } {
    if {[catch {
      fvtrace -property $property_name -composite \
        -file $report_dir/counterexample_fsdb/$trace_name.fsdb
    } trace_error]} {
      puts stderr "WARNING: failed to export $property_name: $trace_error"
    }
  }
}

puts "DSM_IP_FPV_REPORT=$report_dir/report_fv.txt"
