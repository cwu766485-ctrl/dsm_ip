# Synthesis-only mapping of the frozen thermo5 AXI-Stream SKU to VCU118.
# This is an OOC synthesis/resource estimate, not placement, routing, or board signoff.
if {[llength $argv] != 2} {
  error "usage: <part> <out_dir>"
}
set part [lindex $argv 0]
set out_dir [file normalize [lindex $argv 1]]
set script_dir [file dirname [file normalize [info script]]]
set repo [file normalize [file join $script_dir ..]]

if {![info exists ::env(XILINX_VIVADO)]} {
  error "XILINX_VIVADO is required; invoke vivado.bat from the selected installation"
}
set xpm_dir [file join $::env(XILINX_VIVADO) data ip xpm]
file mkdir $out_dir
cd $out_dir

puts "THERMO5_VCU118_PART=$part"
puts "THERMO5_VCU118_VIVADO_VERSION=[version -short]"
create_project -in_memory -part $part

set sources [list \
  [file join $xpm_dir xpm_cdc hdl xpm_cdc.sv] \
  [file join $xpm_dir xpm_memory hdl xpm_memory.sv] \
  [file join $xpm_dir xpm_fifo hdl xpm_fifo.sv] \
  [file join $repo rtl axis dsm_reset_sync.sv] \
  [file join $repo rtl axis dsm_frame_power_ctrl.sv] \
  [file join $repo rtl axis dsm_xpm_async_fifo.sv] \
  [file join $repo rtl axis dsm_axis14_to_core8_cdc.sv] \
  [file join $repo rtl frontend dsm_frame_gain_vector.sv] \
  [file join $repo rtl gt gt_tx_user_bridge.sv] \
  [file join $repo rtl gt gt_tx_raw64_boundary.sv] \
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
  [file join $repo rtl tx_bandpass_if tid32_thermo5_axis_frontend_tx.sv]]
foreach source $sources {
  if {![file exists $source]} { error "source not found: $source" }
  read_verilog -sv $source
}

set_param general.maxThreads 1
set_param synth.maxThreads 1
catch {set_param synth.enableParallelSynthesis false}
catch {set_param synth.parallelSynthesis false}
synth_design -top tid32_thermo5_axis_frontend_tx -part $part \
  -mode out_of_context -flatten_hierarchy none -directive AreaOptimized_high \
  -generic {INTERP_TAPS=2 DPD_MAX_TAPS=1 FPGA_USE_XPM_FIFO=1 ENABLE_LOW_POWER_CTRL=0}
write_checkpoint -force [file join $out_dir synthesized.dcp]
report_utilization -file [file join $out_dir synth_utilization.rpt]

create_clock -name s_axis_aclk -period 8.000 [get_ports s_axis_aclk]
create_clock -name core_clk -period [expr {1000.0/218.75}] [get_ports core_clk]
set_clock_groups -asynchronous \
  -group [get_clocks s_axis_aclk] -group [get_clocks core_clk]
set_false_path -from [get_ports {s_axis_aresetn core_aresetn}]
report_clocks -file [file join $out_dir synth_clocks.rpt]
report_timing_summary -file [file join $out_dir synth_timing_summary.rpt]
report_timing -max_paths 30 -file [file join $out_dir synth_timing_paths.rpt]
check_timing -verbose -file [file join $out_dir synth_check_timing.rpt]

puts "THERMO5_VCU118_SYNTH_STATUS=PASS"
