# Research-only implementation comparison; not system timing/CDC signoff.
# Narrow exceptions terminate only at reviewed first-stage synchronizers or
# asynchronous reset CLR pins. All synchronizer second stages and Core logic
# remain timed. The request crosses two Core synchronizer stages before the
# pending-bank capture; the minimum phase leaves about 9.14 ns for the stable
# bundled payload, so 8 ns is the provisional data-only bound.
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
read_verilog -sv [file join $repo research vcu118_arch thermo5_ppa_abort_candidate.sv]
synth_design -top thermo5_ppa_top -part xcvu9p-flga2104-2L-e -mode out_of_context -generic PPA_MODE=$mode
create_clock -name core_clk -period 4.571428571 [get_ports core_clk]
create_clock -name s_axis_aclk -period 8.000 [get_ports s_axis_aclk]
create_clock -name s_axil_aclk -period 10.000 [get_ports s_axil_aclk]
# Provisional symmetrical 0.2 ns I/O budgets are explicit study assumptions.
foreach p [get_ports -filter {DIRECTION == IN && NAME !~ *clk*}] {
 set n [get_property NAME $p]
 if {$n in {s_axil_aresetn s_axis_aresetn core_aresetn}} {continue}
 if {[string match s_axil_* $n]} {set c s_axil_aclk} elseif {[string match s_axis_* $n]} {set c s_axis_aclk} else {set c core_clk}
 set_input_delay 0.2 -clock [get_clocks $c] $p
}
foreach p [get_ports -filter {DIRECTION == OUT}] {
 set n [get_property NAME $p]
 if {[string match s_axil_* $n] || $n in {cfg_busy cfg_done cfg_error dsm_switch_busy}} {set c s_axil_aclk} elseif {[string match s_axis_* $n] || $n eq "source_epoch_aresetn"} {set c s_axis_aclk} else {set c core_clk}
 set_output_delay 0.2 -clock [get_clocks $c] $p
}
# CDC exceptions below are limited to reviewed structures in the candidate RTL.
# Async reset recovery/removal is handled by the destination reset synchronizer;
# cut only asynchronous reset pins of those synchronizer flops.
set reset_sync_cells [get_cells -hier -filter {NAME =~ *sync_q_reg*}]
if {[llength $reset_sync_cells] == 0} {error "no reset synchronizer cells found"}
set reset_sync_clr [get_pins -of_objects $reset_sync_cells -filter {REF_PIN_NAME == CLR}]
if {[llength $reset_sync_clr] == 0} {error "no reset synchronizer CLR pins found"}
set_false_path -to $reset_sync_clr
puts "RESET_SYNC_ASYNC_ASSERT_ENDPOINTS [llength $reset_sync_clr]"

# One-bit asynchronous controls are timed through their first destination
# synchronizer stage only. The second stage and all destination-domain logic
# remain timed.
proc required_sync1_d {patterns} {
  set cells {}
  foreach pattern $patterns {
    set found [get_cells -hier -filter "NAME =~ $pattern"]
    if {[llength $found] == 0} {error "required CDC synchronizer not found: $pattern"}
    set cells [concat $cells $found]
  }
  set pins [get_pins -of_objects $cells -filter {REF_PIN_NAME == D}]
  if {[llength $pins] == 0} {error "required CDC synchronizer D pins not found"}
  return $pins
}
set axil_to_core_d [required_sync1_d {*cfg_req_sync1_reg* *run_sync1_reg* *arch_req_c1_reg*}]
set core_to_axil_d [required_sync1_d {*cfg_ack_sync1_reg* *tx_active_sync1_reg* *draining_sync1_reg* *arch_ack_a1_reg* *arch_error_a1_reg*}]
set fifo_axis_to_core_d [required_sync1_d {*wr_gray_rd_sync1_q_reg*}]
set fifo_core_to_axis_d [required_sync1_d {*rd_gray_wr_sync1_q_reg*}]
set_false_path -from [get_clocks s_axil_aclk] -to $axil_to_core_d
set_false_path -from [get_clocks core_clk] -to $core_to_axil_d
set_false_path -from [get_clocks s_axis_aclk] -to $fifo_axis_to_core_d
set_false_path -from [get_clocks core_clk] -to $fifo_core_to_axis_d
puts "CDC_FIRST_STAGE_PINS axil_core=[llength $axil_to_core_d] core_axil=[llength $core_to_axil_d] axis_core_fifo=[llength $fifo_axis_to_core_d] core_axis_fifo=[llength $fifo_core_to_axis_d]"

# Bundled-data mailboxes are held stable from request through returned ACK and
# captured only after the synchronized request. Bound each payload bit's
# data-only flight to 8 ns; no clock-phase assumption or broad clock cut.
proc bound_mailbox {src_pattern dst_pattern label} {
  set src_cells [get_cells -hier -filter "NAME =~ $src_pattern"]
  set dst_cells [get_cells -hier -filter "NAME =~ $dst_pattern"]
  if {[llength $src_cells] == 0 || [llength $dst_cells] == 0} {error "empty $label mailbox pin selection"}
  set src [get_pins -of_objects $src_cells -filter {REF_PIN_NAME == Q}]
  set dst [get_pins -of_objects $dst_cells -filter {REF_PIN_NAME == D}]
  if {[llength $src] == 0 || [llength $dst] == 0} {error "empty $label mailbox Q/D pins"}
  set_max_delay -datapath_only 8.000 -from $src -to $dst
  puts "MAILBOX_BOUNDED $label src=[llength $src] dst=[llength $dst] max_ns=8.000"
}
bound_mailbox *u_cfg/cfg_mailbox_q_reg* *u_cfg/cfg_pending_core_reg* config
bound_mailbox *u_cfg/arch_mailbox_reg* *u_cfg/arch_pending_core_reg* architecture
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
report_timing -delay_type max -from [get_clocks s_axil_aclk] -to [get_clocks core_clk] -max_paths 20 -nworst 20 -file axil_to_core_paths.rpt
report_timing -delay_type max -from [get_clocks core_clk] -to [get_clocks s_axil_aclk] -max_paths 20 -nworst 20 -file core_to_axil_paths.rpt
report_timing -delay_type max -from [get_clocks s_axis_aclk] -to [get_clocks core_clk] -max_paths 20 -nworst 20 -file axis_to_core_paths.rpt
report_timing -delay_type max -from [get_clocks core_clk] -to [get_clocks s_axis_aclk] -max_paths 20 -nworst 20 -file core_to_axis_paths.rpt
report_timing -delay_type min -max_paths 20 -nworst 20 -file hold_worst20.rpt
report_clock_interaction -delay_type min_max -file routed_clock_interaction.rpt
report_power -file power_default_activity.rpt
puts "PPA_ROUTED_COMPLETE case=$kind mode=$mode candidate=$candidate"
