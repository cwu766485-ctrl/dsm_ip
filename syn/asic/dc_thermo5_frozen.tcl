set ROOT [file normalize [file join [file dirname [info script]] .. ..]]
set_host_options -max_cores 2
foreach v {DSM_ASIC_STDCELL_DB DSM_ASIC_RUN_DIR} {
  if {![info exists ::env($v)] || $::env($v) eq ""} {error "missing $v"}
}
set run [file normalize $::env(DSM_ASIC_RUN_DIR)]
file mkdir $run/reports $run/netlist $run/work
define_design_lib WORK -path $run/work
set db $::env(DSM_ASIC_STDCELL_DB)
set_app_var target_library [list $db]
set_app_var link_library [list * $db]
set_svf $run/synthesis.svf
set fd [open $ROOT/syn/asic/thermo_frontend_dc_sources.f r]
set sources {}
foreach line [split [read $fd] \n] {
  set line [string trim $line]
  if {$line ne ""} {lappend sources $ROOT/$line}
}
close $fd
lappend sources $ROOT/syn/rtl/thermo5_frozen_asic.sv
analyze -format sverilog $sources
elaborate thermo5_frozen_asic
current_design thermo5_frozen_asic
if {![link]} {error "unresolved reference at link"}
if {![check_design]} {error "precompile check_design failed"}
source $ROOT/syn/asic/thermo5_frozen.sdc
set_fix_multiple_port_nets -all -buffer_constants
# Expose fixed identity coefficient ties before technology mapping. Otherwise
# the classic bottom-up mapper synthesizes unused nonlinear multipliers first.
ungroup -all -flatten
compile_ultra
compile -incremental -only_hold_time
redirect -file $run/reports/check_design.rpt {check_design}
redirect -file $run/reports/check_timing.rpt {check_timing}
redirect -file $run/reports/qor.rpt {report_qor}
redirect -file $run/reports/area.rpt {report_area -hierarchy}
redirect -file $run/reports/timing_setup.rpt {report_timing -delay max -max_paths 20}
redirect -file $run/reports/timing_hold.rpt {report_timing -delay min -max_paths 20}
redirect -file $run/reports/constraints.rpt {report_constraint -all_violators}
redirect -file $run/reports/clocks.rpt {report_clock}
redirect -file $run/reports/ports.rpt {report_port -verbose}
redirect -file $run/reports/reference.rpt {report_reference -hierarchy}
redirect -file $run/reports/units.rpt {report_units}
write_file -format verilog -hierarchy -output $run/netlist/thermo5_frozen_asic_syn.v
write_file -format ddc -hierarchy -output $run/netlist/thermo5_frozen_asic.ddc
write_sdc $run/netlist/thermo5_frozen_asic.sdc
set_svf -off
set unmapped [get_cells -hierarchical -filter "is_unmapped == true"]
set f [open $run/mapping_status.txt w]
puts $f "unmapped_cells=[sizeof_collection $unmapped]"
close $f
if {[sizeof_collection $unmapped] != 0 || ![check_design]} {error "mapped design invalid"}
puts "THERMO5_FROZEN_MAPPED_COMPLETE"
exit
