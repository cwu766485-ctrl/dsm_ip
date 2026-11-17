# Corrected standalone MASH only; unlike the old wrapper this uses explicit
# provisional 0.2 ns I/O budgets and handshaked, weighted PA output.
if {[llength $argv]!=1} {error "usage: <new-output-directory>"}
set out [file normalize [lindex $argv 0]]
if {[file exists $out]} {error "refusing to overwrite"}
set repo [file normalize [file join [file dirname [info script]] ../..]]
file mkdir $out
cd $out
create_project -in_memory -part xcvu9p-flga2104-2L-e
set ::env(HRT_TCL_PATH) [string map {\\ /} [file normalize [file join $::env(XILINX_VIVADO) scripts rt fpga_tcl]]]
set ::env(XILINX_REALTIMEFPGA) 1
catch {unset ::env(BUILTIN_SYNTH)}
set_param general.maxThreads 1
set_param synth.maxThreads 1
set f [open [file join $repo dv uvm sim thermo5_sku_filelist.f] r]
foreach line [split [read $f] \n] {set line [string trim $line];if {[string match rtl/* $line]} {read_verilog -sv [file join $repo $line]}}
close $f
read_verilog -sv [file join $repo research vcu118_arch corrected_mash_ooc.sv]
synth_design -top corrected_mash_ooc -part xcvu9p-flga2104-2L-e -mode out_of_context -directive AreaOptimized_high
create_clock -name core_clk -period 4.571428571 [get_ports clk]
set_input_delay 0.2 -clock core_clk [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_output_delay 0.2 -clock core_clk [get_ports -filter {DIRECTION == OUT}]
report_exceptions -file exceptions.rpt
check_timing -verbose -file check_timing.rpt
report_utilization -file synth_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file synth_timing_summary.rpt
write_checkpoint synthesized.dcp
opt_design
place_design
phys_opt_design
route_design
write_checkpoint routed.dcp
report_utilization -file routed_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file routed_timing_summary.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 -file setup_worst20.rpt
report_timing -delay_type min -max_paths 20 -nworst 20 -file hold_worst20.rpt
report_power -file power_default_activity.rpt
puts "CORRECTED_MASH_OOC_ROUTED_COMPLETE"
