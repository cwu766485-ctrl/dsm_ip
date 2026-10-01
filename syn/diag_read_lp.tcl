set root [file normalize [file join [file dirname [file normalize [info script]]] ..]]
set part xczu15eg-ffvb1156-2-i
catch {unset ::env(BUILTIN_SYNTH)}
catch {unset ::env(XILINX_REALTIMEFPGA)}
create_project -in_memory -part $part
if {![info exists ::env(XILINX_VIVADO)]} { error "XILINX_VIVADO is not set" }
foreach xpm_file [list \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_cdc hdl xpm_cdc.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_memory hdl xpm_memory.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_fifo hdl xpm_fifo.sv]] {
  read_verilog -sv $xpm_file
}
foreach file [list \
  [file join $root rtl axis dsm_reset_sync.sv] \
  [file join $root rtl axis dsm_frame_power_ctrl.sv] \
  [file join $root rtl axis dsm_xpm_async_fifo.sv] \
  [file join $root rtl axis dsm_axis14_to_core8_cdc.sv] \
  [file join $root rtl frontend dsm_frame_gain_vector.sv] \
  [file join $root rtl gt gt_tx_user_bridge.sv] \
  [file join $root rtl gt gt_tx_raw64_boundary.sv] \
  [file join $root rtl dpd dpd_poly.v] \
  [file join $root rtl dpd dpd_memory_poly.v] \
  [file join $root rtl dpd dpd_vector16_memory_poly.sv] \
  [file join $root rtl dpd dpd_vector_elastic_buffer.sv] \
  [file join $root rtl interp dsm_interp_x2_polyphase_vector.sv] \
  [file join $root rtl tx_bandpass_if tid32_cartesian_fs4_gt_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo3_fs4_multipa_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo3_frontend_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo3_axis_frontend_tx.sv] \
  [file join $root syn rtl tid32_thermo_axis_frontend_ooc.sv]] {
  read_verilog -sv $file
}
synth_design -rtl -top tid32_thermo3_axis_frontend_tx_lp_ooc -part $part
puts "LP_RTL_ELAB_PASS"
exit
