# Synthesis/resource check only. This is not routed timing or GTY signoff.
if {[llength $argv]!=2} {error "usage: <part> <new_out_dir>"}
set part [lindex $argv 0]
set out [file normalize [lindex $argv 1]]
if {[file exists $out]} {error "Refusing to overwrite existing output: $out"}
set repo [file normalize [file join [file dirname [info script]] ..]]
file mkdir $out
cd $out
create_project -in_memory -part $part
set ::env(HRT_TCL_PATH) [string map {\\ /} [file normalize [file join $::env(XILINX_VIVADO) scripts rt fpga_tcl]]]
set ::env(XILINX_REALTIMEFPGA) 1
catch {unset ::env(BUILTIN_SYNTH)}
set_property target_language Verilog [current_project]
foreach f {xpm_cdc xpm_memory xpm_fifo} {
 read_verilog -sv [file join $::env(XILINX_VIVADO) data ip xpm $f hdl ${f}.sv]
}
set fd [open [file join $repo dv uvm sim thermo5_sku_filelist.f] r]
foreach line [split [read $fd] \n] {
 set line [string trim $line]
 if {[string match rtl/* $line]} {read_verilog -sv [file join $repo $line]}
}
close $fd
synth_design -top tid32_thermo5_runtime_tx -part $part -mode out_of_context
report_utilization -file [file join $out synth_utilization.rpt]
write_checkpoint [file join $out synthesized.dcp]
puts "THERMO5_RUNTIME_SYNTH_PASS"
