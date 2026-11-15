# Read-only timing/root-cause audit for an existing routed thermo5 checkpoint.
# Usage: vivado -mode batch -source this_file.tcl -tclargs <routed.dcp> <out_dir>
if {[llength $argv] != 2} {
  error "usage: <routed.dcp> <out_dir>"
}
set checkpoint [file normalize [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
if {![file exists $checkpoint]} { error "checkpoint not found: $checkpoint" }
file mkdir $out_dir
cd $out_dir
set_param general.maxThreads 1
open_checkpoint $checkpoint

set report_args [list -max_paths 20 -path_type full_clock_expanded]
report_timing {*}$report_args -delay_type max -file [file join $out_dir worst20_setup.rpt]
report_timing_summary -max_paths 20 -report_unconstrained \
  -file [file join $out_dir timing_summary.rpt]
report_clock_interaction -file [file join $out_dir clock_interaction.rpt]
report_clocks -file [file join $out_dir clocks.rpt]
report_exceptions -file [file join $out_dir exceptions.rpt]
check_timing -verbose -file [file join $out_dir check_timing.rpt]
catch {report_cdc -details -file [file join $out_dir cdc.rpt]} cdc_status
if {[info exists cdc_status] && $cdc_status ne ""} {
  set f [open [file join $out_dir cdc_command_status.txt] w]
  puts $f $cdc_status
  close $f
}
catch {report_methodology -file [file join $out_dir methodology.rpt]} methodology_status
if {[info exists methodology_status] && $methodology_status ne ""} {
  set f [open [file join $out_dir methodology_command_status.txt] w]
  puts $f $methodology_status
  close $f
}

set path_file [open [file join $out_dir worst20_setup.csv] w]
puts $path_file "Index,Slack_ns,Startpoint,Endpoint,StartClock,EndClock,DataPathDelay_ns,LogicLevels,ClockSkew_ns,CellDelay_ns,NetDelay_ns"
set paths [get_timing_paths -delay_type max -max_paths 20 -quiet]
set index 0
foreach path $paths {
  incr index
  set values {}
  foreach property {SLACK STARTPOINT_PIN ENDPOINT_PIN STARTPOINT_CLOCK ENDPOINT_CLOCK DATAPATH_DELAY LOGIC_LEVELS CLOCK_PATH_SKEW LOGIC_DELAY NET_DELAY} {
    set value "NA"
    catch {set value [get_property $property $path]}
    lappend values $value
  }
  # LOGIC_DELAY and NET_DELAY are available on current Vivado path objects;
  # retain NA on older releases rather than manufacturing a split.
  puts $path_file "$index,[lindex $values 0],[lindex $values 1],[lindex $values 2],[lindex $values 3],[lindex $values 4],[lindex $values 5],[lindex $values 6],[lindex $values 7],[lindex $values 8],[lindex $values 9]"
}
close $path_file

set cfg_file [open [file join $out_dir audit_configuration.txt] w]
puts $cfg_file "CHECKPOINT=$checkpoint"
puts $cfg_file "DESIGN=[get_property NAME [current_design]]"
puts $cfg_file "PART=[get_property PART [current_design]]"
foreach clock_name {s_axis_aclk core_clk s_axil_aclk} {
  set clocks [get_clocks -quiet $clock_name]
  if {[llength $clocks] == 0} {
    puts $cfg_file "CLOCK_${clock_name}=MISSING"
  } else {
    set clock [lindex $clocks 0]
    puts $cfg_file "CLOCK_${clock_name}_PERIOD=[get_property PERIOD $clock]"
    puts $cfg_file "CLOCK_${clock_name}_SOURCE=[get_property SOURCE_PINS $clock]"
  }
}
close $cfg_file
puts "THERMO5_TIMING_AUDIT_PASS checkpoint=$checkpoint out=$out_dir paths=[llength $paths]"
exit 0
