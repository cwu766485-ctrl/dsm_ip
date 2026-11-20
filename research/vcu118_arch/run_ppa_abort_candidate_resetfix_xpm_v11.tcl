# Research-only routed comparison with the product XPM asynchronous FIFO.
# v11 additionally constrains the exact XPM-generated reset synchronizer
# stage-zero D pins that v9's wrapper-name patterns did not match.
# Synchronizer/control cuts are narrow. Held-data mailbox buses and XPM
# Gray-pointer buses receive datapath bounds and bus-skew checks; they are
# not false-pathed. Local asynchronous-reset synchronizer CLR pins are
# excluded from recovery/removal because reset release is re-synchronized in
# each destination domain.
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
  if {$line eq "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv"} {continue}
  if {$line eq "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv"} {read_verilog -sv [file join $repo research vcu118_arch cubic_midpoint_candidate_${candidate}.sv]} else {read_verilog -sv [file join $repo $line]}
 }}
close $f
read_verilog -sv [file join $repo research vcu118_arch thermo5_dpd_axi_lite_cfg_epoch_candidate3.sv]
read_verilog -sv [file join $repo research vcu118_arch thermo5_ppa_frontend_candidate3.sv]
read_verilog -sv [file join $repo research vcu118_arch thermo5_ppa_abort_candidate_v4.sv]
synth_design -top thermo5_ppa_top_v4 -part xcvu9p-flga2104-2L-e -mode out_of_context -generic PPA_MODE=$mode
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
foreach pattern {*rd_reset_in_wr_reg* *wr_reset_in_rd_reg*} {
  set cells [get_cells -hier -filter "NAME =~ $pattern"]
  set reset_sync_cells [concat $reset_sync_cells $cells]
}
set reset_sync_cells [lsort -unique $reset_sync_cells]
if {[llength $reset_sync_cells] == 0} {error "no reset synchronizer cells found"}
foreach c $reset_sync_cells {
  set async_attr [string toupper [get_property ASYNC_REG $c]]
  # Vivado 2026.1 reports this Boolean property as 1 in synthesized DCPs.
  if {$async_attr ni {TRUE 1}} {error "refusing reset CLR exception for non-ASYNC_REG cell [get_property NAME $c] (ASYNC_REG=$async_attr)"}
}
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
set axis_to_core_d [required_sync1_d {*arch_locked_c1_reg*}]
set_false_path -from [get_clocks s_axil_aclk] -to $axil_to_core_d
set_false_path -from [get_clocks core_clk] -to $core_to_axil_d
set_false_path -from [get_clocks s_axis_aclk] -to $axis_to_core_d

# XPM_CDC_SYNC_RST receives asynchronous FIFO reset requests from the remote
# clock/reset domain. Only the first synchronizer D pins are asynchronous;
# later stages remain timed to their destination clocks. AMD's XPM source
# declares syncstages_ff with ASYNC_REG=TRUE. Resolve both FIFO directions
# from the elaborated netlist and fail closed if the expected cells or
# attributes are absent. This does not cut the high-fanout reset net globally.
set xpm_reset_first_stage_d {}
foreach pattern {*rd_reset_sync_reg* *wr_reset_sync_reg*} {
  foreach c [get_cells -hier -filter "NAME =~ $pattern"] {
    set n [get_property NAME $c]
    if {![regexp {(rd|wr)_reset_sync_reg\[0\]$} $n]} {continue}
    set async_attr [string toupper [get_property ASYNC_REG $c]]
    if {$async_attr ni {TRUE 1}} {
      error "refusing asynchronous-reset first-stage exception for non-ASYNC_REG cell $n (ASYNC_REG=$async_attr)"
    }
    set d_pin [get_pins -of_objects $c -filter {REF_PIN_NAME == D}]
    if {[llength $d_pin] != 1} {error "expected one first-stage D pin at $n"}
    lappend xpm_reset_first_stage_d $d_pin
  }
}
set xpm_reset_first_stage_d [lsort -unique $xpm_reset_first_stage_d]
if {[llength $xpm_reset_first_stage_d] == 0} {
  error "no XPM asynchronous-reset synchronizer first-stage D pins found"
}
set_false_path -to $xpm_reset_first_stage_d
puts "XPM_RESET_ASYNC_SOURCE_FIRST_STAGE_D_ENDPOINTS [llength $xpm_reset_first_stage_d]"

# The routed hierarchy can expose xpm_cdc_sync_rst's first stage as
# syncstages_ff_reg[0], rather than the wrapper rd_reset_sync_reg[0].
# Resolve exactly the two XPM FIFO reset synchronizer stage-zero D pins, verify
# their ASYNC_REG attributes, and fail closed on a hierarchy/count mismatch.
set xpm_generated_reset_stage0_d {}
foreach c [get_cells -hier -filter {NAME =~ *syncstages_ff_reg*}] {
  set n [get_property NAME $c]
  if {![regexp {xpm_fifo_rst_inst/.*gen_rst_ic\.(rrst_wr_inst|wrst_rd_inst)/syncstages_ff_reg\[0\]$} $n]} {continue}
  set attr [string toupper [get_property ASYNC_REG $c]]
  if {$attr ni {TRUE 1}} {error "refusing XPM reset stage-zero exception for non-ASYNC_REG cell $n (ASYNC_REG=$attr)"}
  set d_pin [get_pins -of_objects $c -filter {REF_PIN_NAME == D}]
  if {[llength $d_pin] != 1} {error "expected one D pin at XPM reset stage-zero cell $n"}
  lappend xpm_generated_reset_stage0_d $d_pin
  puts "VERIFIED_XPM_RESET_STAGE0_CELL cell=$n ASYNC_REG=$attr D=$d_pin"
}
set xpm_generated_reset_stage0_d [lsort -unique $xpm_generated_reset_stage0_d]
if {[llength $xpm_generated_reset_stage0_d] != 2} {
  error "expected exactly two XPM FIFO reset synchronizer stage-zero D pins, found [llength $xpm_generated_reset_stage0_d]"
}
set_false_path -to $xpm_generated_reset_stage0_d
puts "XPM_GENERATED_RESET_STAGE0_EXCLUDED_ENDPOINTS [llength $xpm_generated_reset_stage0_d]"

# DPD coefficients and runtime architecture use four-phase bundled-data
# handshakes. The source mailbox is held until the synchronized request is
# captured, applied, and acknowledged. Bound source-clock-pin to capture-D
# delay to one Core period, shorter than the request synchronizer/capture
# latency, and audit bus skew. This is a protocol-derived bound, not a clock
# group or false path. Formal proof covers the DPD candidate mailbox; runtime
# architecture capture still requires its own proof before product signoff.
proc bound_mailbox_bundle {src_pattern dst_pattern label limit_ns} {
  set src_cells [get_cells -hier -filter "NAME =~ $src_pattern"]
  set dst_cells [get_cells -hier -filter "NAME =~ $dst_pattern"]
  if {[llength $src_cells] == 0 || [llength $dst_cells] == 0} {
    error "mailbox bundle endpoints not found: $label"
  }
  set src_c [get_pins -of_objects $src_cells -filter {REF_PIN_NAME == C}]
  set dst_d [get_pins -of_objects $dst_cells -filter {REF_PIN_NAME == D}]
  if {[llength $src_c] == 0 || [llength $dst_d] == 0} {
    error "mailbox bundle clock/data pins not found: $label"
  }
  set_max_delay -datapath_only $limit_ns -from $src_c -to $dst_d
  set_bus_skew $limit_ns -from $src_c -to $dst_d
  puts "BUNDLED_MAILBOX_BOUNDED name=$label src_cells=[llength $src_cells] dst_cells=[llength $dst_cells] limit_ns=$limit_ns"
}
set core_period_ns [get_property PERIOD [get_clocks core_clk]]
bound_mailbox_bundle {*u_cfg/cfg_mailbox_q_reg*} {*u_cfg/cfg_pending_core_reg*} dpd_cfg $core_period_ns
if {[llength [get_cells -hier -filter {NAME =~ *u_cfg/arch_mailbox_reg*}]] > 0} {
  bound_mailbox_bundle {*u_cfg/arch_mailbox_reg*} {*u_cfg/arch_pending_core_reg*} runtime_arch $core_period_ns
}

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
  set_max_delay -datapath_only $max_ns -from $src_c -to $dst_d
  set_bus_skew $max_ns -from $src_c -to $dst_d
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
# Split out the true Core datapath and the remaining Core-to-AXIS boundary so
# an inter-clock CDC endpoint cannot hide the internal routed critical path.
report_timing -delay_type max -max_paths 20 -nworst 20 \
  -from [get_clocks core_clk] -to [get_clocks core_clk] \
  -file routed_core_setup_worst20.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 \
  -from [get_clocks core_clk] -to [get_clocks s_axis_aclk] \
  -file routed_core_to_axis_setup_worst20.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 \
  -from [get_clocks s_axil_aclk] -to [get_clocks core_clk] \
  -file routed_axil_to_core_setup_worst20.rpt
report_clock_interaction -delay_type min_max -file routed_clock_interaction.rpt
report_exceptions -file routed_exceptions.rpt
report_bus_skew -file routed_bus_skew.rpt
report_power -file power_default_activity.rpt
puts "PPA_ROUTED_COMPLETE case=$kind mode=$mode candidate=$candidate"
