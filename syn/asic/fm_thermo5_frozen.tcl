set ROOT [file normalize [file join [file dirname [info script]] .. ..]]
foreach v {DSM_ASIC_STDCELL_DB DSM_ASIC_RUN_DIR} {
  if {![info exists ::env($v)]} {error "missing $v"}
}
set run $::env(DSM_ASIC_RUN_DIR)
set mapped $run
if {[info exists ::env(DSM_ASIC_MAPPED_RUN_DIR)]} {
  set mapped $::env(DSM_ASIC_MAPPED_RUN_DIR)
}
file mkdir $run/reports
set_app_var synopsys_auto_setup true
set_svf $mapped/synthesis.svf
read_db $::env(DSM_ASIC_STDCELL_DB)
set fd [open $ROOT/syn/asic/thermo_frontend_dc_sources.f r]
set sources {}
foreach line [split [read $fd] \n] {
  set line [string trim $line]
  if {$line ne ""} {lappend sources $ROOT/$line}
}
close $fd
lappend sources $ROOT/syn/rtl/thermo5_frozen_asic.sv
read_sverilog -r $sources
set_top r:/WORK/thermo5_frozen_asic
read_verilog -i $mapped/netlist/thermo5_frozen_asic_syn.v
set_top i:/WORK/thermo5_frozen_asic
match
redirect -file $run/reports/fm_black_boxes.rpt {report_black_boxes -all}
redirect -file $run/reports/fm_unmatched.rpt {report_unmatched_points}
set passed [verify]
redirect -file $run/reports/fm_status.rpt {report_status}
redirect -file $run/reports/fm_failing.rpt {report_failing_points}
redirect -file $run/reports/fm_aborted.rpt {report_aborted_points}
save_session -replace $run/formality_session
if {!$passed} {error "RTL_NETLIST_EQUIVALENCE_FAIL"}
puts "THERMO5_RTL_NETLIST_EQUIVALENCE_PASS"
exit
