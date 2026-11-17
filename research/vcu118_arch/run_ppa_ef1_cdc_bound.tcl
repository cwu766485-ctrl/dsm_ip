# Equal-boundary research OOC implementation. No clock groups or false paths.
# PPA_MODE -1 selects runtime, 0/1/2 prune the inactive backends. The static
# proxies retain the AXI-Lite logic and are implementation comparisons only.
if {[llength $argv] != 3} {error "usage: <case> <new-output-dir> <a|b>"}
set candidate [lindex $argv 2]
if {$candidate ni {a b}} {error "invalid candidate"}
set kind [lindex $argv 0]
set out [file normalize [lindex $argv 1]]
if {$kind ni {ef1 ef2 mash runtime}} {error "unknown case"}
if {[file exists $out]} {error "refusing to overwrite output directory"}
set mode [dict get {ef1 0 ef2 1 mash 2 runtime -1} $kind]
set repo [file normalize [file join [file dirname [info script]] ../..]]
file mkdir $out
cd $out
create_project -in_memory -part xcvu9p-flga2104-2L-e
set ::env(HRT_TCL_PATH) [string map {\\ /} [file normalize [file join $::env(XILINX_VIVADO) scripts rt fpga_tcl]]]
set ::env(XILINX_REALTIMEFPGA) 1
catch {unset ::env(BUILTIN_SYNTH)}
set_param general.maxThreads 1
set_param synth.maxThreads 1
catch {set_param synth.enableParallelSynthesis false}
catch {set_param synth.parallelSynthesis false}
foreach x {xpm_cdc xpm_memory xpm_fifo} {read_verilog -sv [file join $::env(XILINX_VIVADO) data ip xpm $x hdl ${x}.sv]}
set f [open [file join $repo dv uvm sim thermo5_sku_filelist.f] r]
foreach line [split [read $f] \n] {set line [string trim $line];if {[string match rtl/* $line]} {
  if {$line eq "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv"} {read_verilog -sv [file join $repo research vcu118_arch cubic_midpoint_candidate_${candidate}.sv]} else {read_verilog -sv [file join $repo $line]}
 }}
close $f
read_verilog -sv [file join $repo research vcu118_arch thermo5_ppa_frontend.sv]
read_verilog -sv [file join $repo research vcu118_arch thermo5_ppa_top.sv]
synth_design -top thermo5_ppa_top -part xcvu9p-flga2104-2L-e -mode out_of_context -generic PPA_MODE=$mode
create_clock -name core_clk -period 4.571428571 [get_ports core_clk]
create_clock -name s_axis_aclk -period 8.000 [get_ports s_axis_aclk]
create_clock -name s_axil_aclk -period 10.000 [get_ports s_axil_aclk]
# Provisional symmetrical 0.2 ns I/O budgets are explicit study assumptions.
foreach p [get_ports -filter {DIRECTION == IN && NAME !~ *clk*}] {
 set n [get_property NAME $p]
 if {[string match s_axil_* $n]} {set c s_axil_aclk} elseif {[string match s_axis_* $n]} {set c s_axis_aclk} else {set c core_clk}
 set_input_delay 0.2 -clock [get_clocks $c] $p
}
foreach p [get_ports -filter {DIRECTION == OUT}] {
 set n [get_property NAME $p]
 if {[string match s_axil_* $n] || $n in {cfg_busy cfg_done cfg_error dsm_switch_busy}} {set c s_axil_aclk} elseif {[string match s_axis_* $n]} {set c s_axis_aclk} else {set c core_clk}
 set_output_delay 0.2 -clock [get_clocks $c] $p
}
# Research candidate: bundled-data mailbox. Request traverses two core
# synchronizer flops before a subsequent capture edge. 4 ns is below one
# nominal 4.571 ns core period and bounds the data path without false paths.
# Valid only if the common-reset hold/capture contract and physical CDC review
# apply; this does not waive unrelated CDC paths or constitute signoff.
if {$kind ne "ef1"} {error "CDC-bound experiment is EF1-only"}
set mailbox_src_cells [get_cells -hier -filter {NAME =~ *u_cfg/cfg_mailbox_q_reg*}]
set mailbox_dst_cells [get_cells -hier -filter {NAME =~ *u_cfg/cfg_pending_core_reg*}]
set mailbox_src [get_pins -of_objects $mailbox_src_cells -filter {REF_PIN_NAME == Q}]
set mailbox_dst [get_pins -of_objects $mailbox_dst_cells -filter {REF_PIN_NAME == D}]
if {[llength $mailbox_src] == 0 || [llength $mailbox_dst] == 0} {error "empty mailbox pin selection"}
puts "MAILBOX_DATA_BOUND src=[llength $mailbox_src] dst=[llength $mailbox_dst] ns=4.0"
set_max_delay -datapath_only 4.000 -from $mailbox_src -to $mailbox_dst
report_exceptions -file exceptions.rpt
report_clock_interaction -delay_type min_max -file clock_interaction.rpt
check_timing -verbose -file check_timing.rpt
report_utilization -file synth_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file synth_timing_summary.rpt
write_checkpoint synthesized.dcp
opt_design
place_design
write_checkpoint placed.dcp
phys_opt_design
route_design
write_checkpoint routed.dcp
report_utilization -file routed_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file routed_timing_summary.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 -file setup_worst20.rpt
report_timing -delay_type min -max_paths 20 -nworst 20 -file hold_worst20.rpt
report_clock_interaction -delay_type min_max -file routed_clock_interaction.rpt
report_power -file power_default_activity.rpt
puts "PPA_ROUTED_COMPLETE case=$kind mode=$mode candidate=$candidate"
