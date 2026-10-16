# Routed OOC timing/resource check for the frozen thermo5 AXI-Stream top.
# This runs the no-AXI-Lite, two-clock XPM configuration on ZU15EG. It is an
# internal-path OOC result only; parent I/O delays and system CDC/RDC are not
# implied by this flow.
if {[llength $argv] != 4} {
  error "usage: <part> <source_mhz> <core_mhz> <out_dir>"
}
set part [lindex $argv 0]
set source_mhz [expr {double([lindex $argv 1])}]
set core_mhz [expr {double([lindex $argv 2])}]
set out_dir [file normalize [lindex $argv 3]]
set script_dir [file dirname [file normalize [info script]]]
set repo [file normalize [file join $script_dir ".."]]
if {![info exists ::env(XILINX_VIVADO)]} {
  error "XILINX_VIVADO is required; source Vivado settings64.bat first"
}
set xpm_dir [file join $::env(XILINX_VIVADO) data ip xpm]
set ::env(HRT_TCL_PATH) [string map {\\ /} [file normalize \
  [file join $::env(XILINX_VIVADO) scripts rt fpga_tcl]]]
set ::env(XILINX_REALTIMEFPGA) 1
catch {unset ::env(BUILTIN_SYNTH)}
file mkdir $out_dir
cd $out_dir
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
  [file join $repo rtl interp dsm_interp_x2_polyphase_vector.sv] \
  [file join $repo rtl tx_bandpass_if tid32_cartesian_fs4_gt_tx.sv] \
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
report_clocks -file [file join $out_dir synth_clocks.rpt]
puts "THERMO5_AXIS_OOC_STAGE=post_synth"

create_clock -name s_axis_aclk -period [expr {1000.0/$source_mhz}] \
  [get_ports s_axis_aclk]
create_clock -name core_clk -period [expr {1000.0/$core_mhz}] \
  [get_ports core_clk]
set_clock_groups -asynchronous \
  -group [get_clocks s_axis_aclk] -group [get_clocks core_clk]
set_false_path -from [get_ports {s_axis_aresetn core_aresetn}]

opt_design
write_checkpoint -force [file join $out_dir optimized.dcp]
place_design
write_checkpoint -force [file join $out_dir placed.dcp]
phys_opt_design
write_checkpoint -force [file join $out_dir physopt.dcp]
route_design
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_timing -max_paths 30 -file [file join $out_dir timing_max_paths.rpt]
report_clock_interaction -file [file join $out_dir clock_interaction.rpt]
check_timing -verbose -file [file join $out_dir check_timing.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
report_cdc -details -file [file join $out_dir cdc.rpt]
write_checkpoint -force [file join $out_dir routed.dcp]

set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup] == 0 || [llength $hold] == 0} {
  error "No setup/hold timing path reported"
}
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
if {$wns < 0.0} { set status FAIL_SETUP
} elseif {$whs < 0.0} { set status FAIL_HOLD
} else { set status PASS }
set f [open [file join $out_dir summary.csv] w]
puts $f "Part,Top,Source_MHz,Core_MHz,Interp_Taps,Dpd_Max_Taps,Fifo,Status,WNS_ns,WHS_ns"
puts $f "$part,tid32_thermo5_axis_frontend_tx,[format %.2f $source_mhz],[format %.2f $core_mhz],2,1,XPM,$status,[format %.3f $wns],[format %.3f $whs]"
close $f
puts "THERMO5_AXIS_OOC_STATUS=$status WNS=$wns WHS=$whs"
