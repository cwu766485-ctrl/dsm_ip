# Research-only routed comparison with the product XPM asynchronous FIFO.
# Synchronizer/control cuts are deliberately narrow. XPM Gray-pointer buses
# are bounded from their source Gray flops to stage 0 D and bus-skewed by the
# source period; they are not false-pathed.
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
# Reset recovery/removal is excluded only at the asynchronous CLR pins of
# local reset synchronizer flops. Release is synchronized in each local domain.
set reset_sync_cells [get_cells -hier -filter {NAME =~ *sync_q_reg*}]
if {[llength $reset_sync_cells] == 0} {error "no reset synchronizer cells found"}
set reset_sync_clr [get_pins -of_objects $reset_sync_cells -filter {REF_PIN_NAME == CLR}]
if {[llength $reset_sync_clr] == 0} {error "no reset synchronizer CLR pins found"}
set_false_path -to $reset_sync_clr
puts "RESET_SYNC_ASYNC_ASSERT_ENDPOINTS [llength $reset_sync_clr]"

# Single-bit asynchronous controls are cut only to their first destination D.
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
set_false_path -from [get_clocks s_axil_aclk] -to $axil_to_core_d
set_false_path -from [get_clocks core_clk] -to $core_to_axil_d

# Find XPM_CDC_GRAY source flops and stage-zero destination flops by their
# preserved XPM instance hierarchy. Apply datapath-only max-delay and bus-skew
# constraints, derived from each launch clock's period. No cross-clock group
# is cut and no Gray-pointer data crossing is hidden.
set gray_sources [get_cells -hier -filter {NAME =~ *src_gray_ff_reg*}]
set gray_dest_all [get_cells -hier -filter {NAME =~ *dest_graysync_ff_reg*}]
if {[llength $gray_sources] == 0 || [llength $gray_dest_all] == 0} {
  error "XPM Gray CDC flops not found; inspect synthesized hierarchy before timing"
}
set gray_pairs 0
set gray_seen {}
foreach src_cell $gray_sources {
  set src_name [get_property NAME $src_cell]
  regsub {/src_gray_ff_reg.*$} $src_name "" inst
  if {[lsearch -exact $gray_seen $inst] >= 0} {continue}
  lappend gray_seen $inst
  set dst_cells {}
  foreach dst_cell $gray_dest_all {
    set dst_name [get_property NAME $dst_cell]
    if {![string match "${inst}/dest_graysync_ff_reg*" $dst_name]} {continue}
    if {[regexp {dest_graysync_ff_reg\[0\]($|\[)} $dst_name]} {lappend dst_cells $dst_cell}
  }
  if {[llength $dst_cells] == 0} {continue}
  set src_group [get_cells -hier -filter "NAME =~ ${inst}/src_gray_ff_reg*"]
  set src_q [get_pins -of_objects $src_group -filter {REF_PIN_NAME == Q}]
  set src_c [get_pins -of_objects $src_group -filter {REF_PIN_NAME == C}]
  set dst_d [get_pins -of_objects $dst_cells -filter {REF_PIN_NAME == D}]
  set launch_clks [get_clocks -of_objects $src_c]
  if {[llength $launch_clks] != 1 || [llength $src_q] == 0 || [llength $dst_d] == 0} {
    error "cannot resolve XPM Gray CDC pins/clocks at $inst"
  }
  set max_ns [get_property PERIOD [lindex $launch_clks 0]]
  set_max_delay -datapath_only $max_ns -from $src_q -to $dst_d
  set_bus_skew $max_ns -from $src_q -to $dst_d
  incr gray_pairs
  puts "XPM_GRAY_CDC_BOUNDED instance=$inst launch=[get_property NAME [lindex $launch_clks 0]] period_ns=$max_ns src_bits=[llength $src_q] stage0_bits=[llength $dst_d]"
}
if {$gray_pairs == 0} {error "no paired XPM Gray synchronizer instances found"}
puts "XPM_GRAY_CDC_INSTANCE_COUNT $gray_pairs"
report_cdc -file synthesized_cdc.rpt
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
report_cdc -file routed_cdc.rpt
report_utilization -file routed_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file routed_timing_summary.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 -file setup_worst20.rpt
report_timing -delay_type min -max_paths 20 -nworst 20 -file hold_worst20.rpt
report_clock_interaction -delay_type min_max -file routed_clock_interaction.rpt
report_exceptions -file routed_exceptions.rpt
report_power -file power_default_activity.rpt
puts "PPA_ROUTED_COMPLETE case=$kind mode=$mode candidate=$candidate"
