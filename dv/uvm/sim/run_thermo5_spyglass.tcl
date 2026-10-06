# Frozen generic ASIC/DV SKU, no vendor models or RTL suppressions.
set ROOT [file normalize [file join [file dirname [info script]] .. .. ..]]
if {![info exists ::env(THERMO5_LINT_RUN)]} {error "missing THERMO5_LINT_RUN"}
set run [file normalize $::env(THERMO5_LINT_RUN)]
file mkdir $run
new_project $run/thermo5_frozen.prj
set_option enableSV yes
set_option top thermo5_frozen_asic
# TID has 1024 x 17-bit architectural state: elaborate the real memory.
set_option mthresh 32768
set fd [open $ROOT/syn/asic/thermo_frontend_dc_sources.f r]
set sources {}
foreach line [split [read $fd] \n] {
  set line [string trim $line]
  if {$line ne ""} {lappend sources $ROOT/$line}
}
close $fd
lappend sources $ROOT/syn/rtl/thermo5_frozen_asic.sv
read_file -type verilog $sources
current_goal lint/lint_rtl
run_goal
write_report moresimple > $run/moresimple.rpt
exit
