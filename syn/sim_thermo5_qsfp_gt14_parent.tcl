# Self-contained XSim setup for the ZU15EG four-lane thermo5 GT parent.
# This creates the real GT Wizard behavioral model but intentionally does not
# run synth_design, place/route, or claim physical link/board signoff.
if {[llength $argv] < 1 || [llength $argv] > 4} {
  error "usage: <parent_run_dir> ?skip_rx_compare(0|1)? ?scenario(Baseline|Stress|BadFrames)? ?stress_pattern(0..3)?"
}
set out_dir [file normalize [lindex $argv 0]]
set skip_rx_compare [expr {[llength $argv] >= 2 && [lindex $argv 1] eq "1"}]
set scenario [expr {[llength $argv] >= 3 ? [lindex $argv 2] : "Baseline"}]
set pattern [expr {[llength $argv] >= 4 ? [lindex $argv 3] : 2}]
if {$scenario ni {Baseline Stress BadFrames}} {
  error "unsupported thermo5 GT-parent scenario: $scenario"
}
if {![string is integer -strict $pattern] || $pattern < 0 || $pattern > 3} {
  error "stress pattern must be an integer from 0 through 3"
}
if {$scenario ne "Baseline" && !$skip_rx_compare} {
  error "Stress/BadFrames require RX comparison to be skipped while RX recovery is open"
}
set repo [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $out_dir project]
set project_file [file join $project_dir thermo5_qsfp_gt14_parent.xpr]
file mkdir $out_dir

if {[file exists $project_file]} {
  open_project $project_file
} else {
  create_project thermo5_qsfp_gt14_parent $project_dir \
    -part xczu15eg-ffvb1156-2-i
  set_property target_language Verilog [current_project]

  create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip \
    -module_name thermo5_qsfp_gt14_probe
  set gt_ip [get_ips thermo5_qsfp_gt14_probe]
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
    CONFIG.FREERUN_FREQUENCY {200} CONFIG.DISABLE_LOC_XDC {1}] $gt_ip
  generate_target all $gt_ip

  if {![info exists ::env(XILINX_VIVADO)]} {
    error "XILINX_VIVADO is required to generate GT simulation sources"
  }
  set ::env(HRT_TCL_PATH) [string map {\\ /} [file normalize \
    [file join $::env(XILINX_VIVADO) scripts rt fpga_tcl]]]
  set ::env(XILINX_REALTIMEFPGA) 1
  catch {unset ::env(BUILTIN_SYNTH)}

  set rtl_files [list \
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
    [file join $repo rtl interp dsm_interp_x2_centered_cubic_vector.sv] \
    [file join $repo rtl interp dsm_interp_x2_polyphase_vector.sv] \
    [file join $repo rtl tx_bandpass_if tid32_cartesian_fs4_gt_tx.sv] \
    [file join $repo rtl tx_bandpass_if tid32_cartesian_ef2_fs4_gt_tx.sv] \
    [file join $repo rtl tx_bandpass_if tid32_thermo5_fs4_multipa_tx.sv] \
    [file join $repo rtl tx_bandpass_if tid32_thermo5_frontend_tx.sv] \
    [file join $repo rtl tx_bandpass_if thermo5_dpd_axi_lite_cfg.sv] \
    [file join $repo rtl tx_bandpass_if tid32_thermo5_axi_lite_axis_frontend_tx.sv] \
    [file join $repo fpga zu15eg rtl thermo5_qsfp_gt14_parent.sv]]
  foreach file $rtl_files {
    if {![file exists $file]} { error "Missing RTL/model source: $file" }
    add_files -norecurse $file
  }
}

set tb [file join $repo dv verif integration gt_parent tb_thermo5_qsfp_gt14_parent.sv]
add_files -fileset sim_1 -norecurse $tb
set_property top tb_thermo5_qsfp_gt14_parent [get_filesets sim_1]
set_property -name xsim.simulate.runtime -value all -objects [get_filesets sim_1]
set sim_plusargs [list]
if {$skip_rx_compare} { lappend sim_plusargs -testplusarg SKIP_RX_COMPARE }
if {$scenario eq "Stress"} {
  lappend sim_plusargs -testplusarg RUN_GT_STRESS
  lappend sim_plusargs -testplusarg GT_PATTERN=$pattern
}
if {$scenario eq "BadFrames"} { lappend sim_plusargs -testplusarg RUN_GT_BAD_FRAMES }
if {[llength $sim_plusargs] > 0} {
  set_property -name xsim.simulate.xsim.more_options \
    -value [join $sim_plusargs " "] -objects [get_filesets sim_1]
}
update_compile_order -fileset sim_1
launch_simulation -mode behavioral
# XSim keeps simulate.log buffered until Vivado exits. The launcher verifies
# the PASS marker only after this process has completed.
puts "THERMO5_QSFP_GT14_PARENT_SIM_FINISHED=$out_dir"
