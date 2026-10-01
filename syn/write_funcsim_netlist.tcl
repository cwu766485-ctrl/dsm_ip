# Export an OOC routed checkpoint as a functional simulation netlist.
#
# Usage: vivado -mode batch -source write_funcsim_netlist.tcl -tclargs \
#          <routed.dcp> <output_funcsim.v>
#
# The generated file is an implementation artifact and belongs under runs/.
if {[llength $argv] != 2} {
  error "usage: <routed_dcp> <output_funcsim_verilog>"
}
set routed_dcp [file normalize [lindex $argv 0]]
set output_netlist [file normalize [lindex $argv 1]]
if {![file exists $routed_dcp]} {
  error "routed checkpoint does not exist: $routed_dcp"
}
file mkdir [file dirname $output_netlist]
open_checkpoint $routed_dcp
write_verilog -force -mode funcsim $output_netlist
puts "FUNCSIM_NETLIST=$output_netlist"
close_design
exit
