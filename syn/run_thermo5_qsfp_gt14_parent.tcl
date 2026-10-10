# Prospective four-GTH parent. The 125-MHz MGT reference is an unverified
# external assumption. Results are OOC digital evidence, not a board claim.
if {[llength $argv] != 2} { error "usage: <out_dir> <synth|route>" }
set out_dir [file normalize [lindex $argv 0]]
set stage [lindex $argv 1]
if {$stage ni {synth route}} { error "stage must be synth or route" }
set repo [file normalize [file join [file dirname [info script]] ..]]
file mkdir $out_dir
create_project thermo5_qsfp_gt14_parent [file join $out_dir project] \
  -part xczu15eg-ffvb1156-2-i -force
set_property target_language Verilog [current_project]

create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip \
  -module_name thermo5_qsfp_gt14_probe
set ip [get_ips thermo5_qsfp_gt14_probe]
set_property -dict [list \
  CONFIG.CHANNEL_ENABLE {X0Y4 X0Y5 X0Y6 X0Y7} \
  CONFIG.GT_DIRECTION {BOTH} CONFIG.GT_TYPE {GTH} \
  CONFIG.TX_DATA_ENCODING {RAW} CONFIG.TX_LINE_RATE {14.0} \
  CONFIG.TX_REFCLK_FREQUENCY {125} CONFIG.TX_USER_DATA_WIDTH {64} \
  CONFIG.TX_INT_DATA_WIDTH {32} CONFIG.TX_BUFFER_MODE {1} \
  CONFIG.RX_DATA_DECODING {RAW} CONFIG.RX_LINE_RATE {14.0} \
  CONFIG.RX_REFCLK_FREQUENCY {125} CONFIG.RX_USER_DATA_WIDTH {64} \
  CONFIG.RX_INT_DATA_WIDTH {32} CONFIG.RX_SLIDE_MODE {PMA} \
  CONFIG.ENABLE_OPTIONAL_PORTS {loopback_in rxslide_in} \
  CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
  CONFIG.LOCATE_RX_USER_CLOCKING {CORE} CONFIG.LOCATE_RESET_CONTROLLER {CORE} \
  CONFIG.FREERUN_FREQUENCY {200} CONFIG.DISABLE_LOC_XDC {1}] $ip
generate_target all $ip
set_property generate_synth_checkpoint false [get_files *.xci]

if {![info exists ::env(XILINX_VIVADO)]} { error "XILINX_VIVADO is required" }
set ::env(HRT_TCL_PATH) [string map {\\ /} [file normalize \
  [file join $::env(XILINX_VIVADO) scripts rt fpga_tcl]]]
set ::env(XILINX_REALTIMEFPGA) 1
catch {unset ::env(BUILTIN_SYNTH)}
foreach file [list \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_cdc hdl xpm_cdc.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_memory hdl xpm_memory.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_fifo hdl xpm_fifo.sv] \
  [file join $repo rtl axis dsm_reset_sync.sv] \
  [file join $repo rtl axis dsm_frame_power_ctrl.sv] \
  [file join $repo rtl axis dsm_xpm_async_fifo.sv] \
  [file join $repo rtl axis dsm_axis14_to_core8_cdc.sv] \
  [file join $repo rtl frontend dsm_frame_gain_vector.sv] \
  [file join $repo rtl gt gt_tx_user_bridge.sv] \
  [file join $repo rtl gt gt_tx_raw64_boundary.sv] \
  [file join $repo rtl gt thermo5_raw64_continuous_tx.sv] \
  [file join $repo rtl dpd dpd_poly.v] \
  [file join $repo rtl dpd dpd_memory_poly.v] \
  [file join $repo rtl dpd dpd_vector16_memory_poly.sv] \
  [file join $repo rtl dpd dpd_vector_elastic_buffer.sv] \
  [file join $repo rtl interp dsm_interp_x2_polyphase_vector.sv] \
  [file join $repo rtl tx_bandpass_if tid32_cartesian_fs4_gt_tx.sv] \
  [file join $repo rtl tx_bandpass_if tid32_thermo5_fs4_multipa_tx.sv] \
  [file join $repo rtl tx_bandpass_if tid32_thermo5_frontend_tx.sv] \
  [file join $repo rtl tx_bandpass_if tid32_thermo5_axis_frontend_tx.sv] \
  [file join $repo fpga zu15eg rtl thermo5_qsfp_gt14_parent.sv]] {
  if {![file exists $file]} { error "Missing RTL: $file" }
  add_files -norecurse $file
}
add_files -fileset constrs_1 -norecurse \
  [file join $repo fpga zu15eg constraints thermo5_qsfp_gt14_parent.xdc]
set_property top thermo5_qsfp_gt14_parent [current_fileset]
update_compile_order -fileset sources_1
set_param general.maxThreads 1
set_param synth.maxThreads 1
catch {set_param synth.enableParallelSynthesis false}
catch {set_param synth.parallelSynthesis false}
# Avoid Vivado 2024.1's crashing child realtime helper by synthesizing the
# generated IP and parent in the current Vivado process, as in the routed
# frontend OOC flow.
synth_design -top thermo5_qsfp_gt14_parent -part xczu15eg-ffvb1156-2-i \
  -mode out_of_context -flatten_hierarchy none
# The Wizard-derived RX user clock is available only after synth elaborates
# the GT IP. Apply the provisional downstream budget before checkpoint/route.
set rx_user_clk [get_clocks -quiet *gtwiz_userclk_rx_inst_n_1]
if {[llength $rx_user_clk] != 1} {
  error "Expected one generated GTH RX user clock for gt_rxdata timing"
}
set_output_delay -clock $rx_user_clk -max 1.500 [get_ports {gt_rxdata[*]}]
set_output_delay -clock $rx_user_clk -min 0.000 [get_ports {gt_rxdata[*]}]
# AXI, GT-reset free-run, and the GT-reference family have no guaranteed
# phase relationship. Keep every clock *within* the GT family related; CDC
# and reset paths are audited separately rather than timed as synchronous.
set gt_clocks [get_clocks -include_generated_clocks mgtrefclk125]
if {[llength $gt_clocks] < 2 ||
    [llength [get_clocks -quiet core_clk218]] != 1} {
  error "Expected GT clock family or core_clk218 is missing"
}
set_clock_groups -asynchronous -group [get_clocks axi_clk125] \
  -group [get_clocks freerun_clk200] -group $gt_clocks
report_utilization -file [file join $out_dir synth_utilization.rpt]
report_clocks -file [file join $out_dir synth_clocks.rpt]
write_checkpoint -force [file join $out_dir synthesized.dcp]
puts "THERMO5_QSFP_PARENT_SYNTH_PASS=$out_dir"
if {$stage eq "route"} {
  opt_design
  place_design
  phys_opt_design
  route_design
  report_timing_summary -file [file join $out_dir timing_summary.rpt]
  report_utilization -file [file join $out_dir utilization.rpt]
  report_cdc -details -file [file join $out_dir cdc.rpt]
  report_clock_interaction -file [file join $out_dir clock_interaction.rpt]
  check_timing -verbose -file [file join $out_dir check_timing.rpt]
  write_checkpoint -force [file join $out_dir routed.dcp]
  puts "THERMO5_QSFP_PARENT_ROUTE_COMPLETE=$out_dir"
}
