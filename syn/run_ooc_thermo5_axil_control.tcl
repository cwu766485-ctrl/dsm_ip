# OOC routed timing/resource check for the optional thermo5 AXI-Lite wrapper.
# This is an internal-path study with provisional clocks, not board I/O signoff.
if {[llength $argv] != 5} {
  error "usage: <part> <core_mhz> <axil_mhz> <out_dir> <quick|full>"
}
set part [lindex $argv 0]
set core_mhz [expr {double([lindex $argv 1])}]
set axil_mhz [expr {double([lindex $argv 2])}]
set out_dir [file normalize [lindex $argv 3]]
set implementation [lindex $argv 4]
if {$implementation ni {synth quick full timing}} { error "implementation must be synth, quick, full, or timing" }
set script_dir [file dirname [file normalize [info script]]]
set repo [file normalize [file join $script_dir ..]]
file mkdir $out_dir
cd $out_dir
create_project -in_memory -part $part

if {![info exists ::env(XILINX_VIVADO)]} { error "XILINX_VIVADO is required" }
set ::env(HRT_TCL_PATH) [string map {\\ /} [file normalize \
  [file join $::env(XILINX_VIVADO) scripts rt fpga_tcl]]]
set ::env(XILINX_REALTIMEFPGA) 1
catch {unset ::env(BUILTIN_SYNTH)}

set sources [list \
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
  [file join $repo rtl dpd dpd_poly.v] \
  [file join $repo rtl dpd dpd_memory_poly.v] \
  [file join $repo rtl dpd dpd_vector16_memory_poly.sv] \
  [file join $repo rtl dpd dpd_vector_elastic_buffer.sv] \
  [file join $repo rtl interp dsm_interp_x2_centered_cubic_vector.sv] \
  [file join $repo rtl interp dsm_interp_x2_polyphase_vector.sv] \
  [file join $repo rtl tx_bandpass_if tid32_cartesian_fs4_gt_tx.sv] \
  [file join $repo rtl tx_bandpass_if tid32_thermo5_fs4_multipa_tx.sv] \
  [file join $repo rtl tx_bandpass_if tid32_thermo5_frontend_tx.sv] \
  [file join $repo rtl tx_bandpass_if tid32_thermo5_axis_frontend_tx.sv] \
  [file join $repo rtl tx_bandpass_if thermo5_dpd_axi_lite_cfg.sv] \
  [file join $repo rtl tx_bandpass_if tid32_thermo5_axi_lite_axis_frontend_tx.sv]]
foreach source $sources {
  if {![file exists $source]} { error "source not found: $source" }
  read_verilog -sv $source
}

set_param general.maxThreads 1
set_param synth.maxThreads 1
catch {set_param synth.enableParallelSynthesis false}
catch {set_param synth.parallelSynthesis false}
synth_design -top tid32_thermo5_axi_lite_axis_frontend_tx \
  -part $part -mode out_of_context -flatten_hierarchy none \
  -directive AreaOptimized_high -generic {INTERP_TAPS=2 DPD_MAX_TAPS=4 FPGA_USE_XPM_FIFO=1}
puts "THERMO5_AXIL_OOC_STAGE=post_synth"

create_clock -name s_axis_aclk -period 8.000 [get_ports s_axis_aclk]
create_clock -name core_clk -period [expr {1000.0/$core_mhz}] [get_ports core_clk]
create_clock -name s_axil_aclk -period [expr {1000.0/$axil_mhz}] [get_ports s_axil_aclk]
# AXI-Stream FIFO CDC is asynchronous. AXI-Lite/core mailbox data is instead
# explicitly bounded below; only the single-bit control synchronizer inputs
# are false-pathed.
set_clock_groups -asynchronous \
  -group [get_clocks s_axis_aclk] -group [get_clocks core_clk]
set_clock_groups -asynchronous \
  -group [get_clocks s_axis_aclk] -group [get_clocks s_axil_aclk]

set_false_path -from [get_ports {s_axis_aresetn core_aresetn s_axil_aresetn}]
set cfg_src [get_cells -hier -filter {NAME =~ *u_cfg/cfg_mailbox_q_reg*}]
set cfg_dst [get_cells -hier -filter {NAME =~ *u_cfg/cfg_pending_core_reg*}]
set req_src [get_cells -hier -filter {NAME =~ *u_cfg/cfg_req_q_reg*}]
set req_dst [get_cells -hier -filter {NAME =~ *u_cfg/cfg_req_sync1_reg*}]
set ack_src [get_cells -hier -filter {NAME =~ *u_cfg/cfg_ack_core_reg*}]
set ack_dst [get_cells -hier -filter {NAME =~ *u_cfg/cfg_ack_sync1_reg*}]
set run_src [get_cells -hier -filter {NAME =~ *u_cfg/run_request_q_reg*}]
set run_dst [get_cells -hier -filter {NAME =~ *u_cfg/run_sync1_reg*}]
foreach {label collection} [list \
  cfg_mailbox_source $cfg_src cfg_pending_capture $cfg_dst \
  cfg_request_source $req_src cfg_request_sync1 $req_dst \
  cfg_ack_source $ack_src cfg_ack_sync1 $ack_dst \
  run_request_source $run_src run_request_sync1 $run_dst] {
  if {[llength $collection] == 0} { error "Could not resolve synthesized CDC collection: $label" }
}
set_false_path -from $req_src -to $req_dst
set_false_path -from $ack_src -to $ack_dst
set_false_path -from $run_src -to $run_dst
set_max_delay -datapath_only 10.000 -from $cfg_src -to $cfg_dst

report_utilization -file [file join $out_dir synth_utilization.rpt]
report_clocks -file [file join $out_dir clocks.rpt]
write_checkpoint -force [file join $out_dir synthesized.dcp]
if {$implementation eq "synth"} {
  puts "THERMO5_AXIL_SYNTH_STATUS=PASS"
  exit 0
} elseif {$implementation eq "full"} {
  opt_design
  place_design
  phys_opt_design
  route_design
} elseif {$implementation eq "timing"} {
  # Separate timing-driven candidate for designs where the area-oriented
  # baseline routes close to the 218.75-MHz limit.  Keep this as a distinct
  # run mode so baseline evidence remains reproducible.
  opt_design -directive Explore
  place_design -directive Explore
  phys_opt_design -directive AggressiveExplore
  route_design -directive Explore
  phys_opt_design -directive AggressiveExplore
  route_design -directive Explore
} else {
  place_design -directive Quick
  route_design -directive Quick
}
puts "THERMO5_AXIL_STAGE=route_complete"
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_timing -max_paths 30 -file [file join $out_dir timing_max_paths.rpt]
report_clock_interaction -file [file join $out_dir clock_interaction.rpt]
check_timing -verbose -file [file join $out_dir check_timing.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
write_checkpoint -force [file join $out_dir routed.dcp]

set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup] == 0 || [llength $hold] == 0} { error "No setup/hold timing path reported" }
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
if {$wns < 0.0} { set status FAIL_SETUP
} elseif {$whs < 0.0} { set status FAIL_HOLD
} else { set status PASS }
set f [open [file join $out_dir summary.csv] w]
puts $f "Part,Top,Axis_MHz,Core_MHz,Axil_MHz,Interp_Taps,Dpd_Max_Taps,Fifo,Implementation,Status,WNS_ns,WHS_ns"
puts $f "$part,tid32_thermo5_axi_lite_axis_frontend_tx,125.00,[format %.2f $core_mhz],[format %.2f $axil_mhz],2,4,XPM,$implementation,$status,[format %.3f $wns],[format %.3f $whs]"
close $f
puts "THERMO5_AXIL_OOC_STATUS=$status WNS=$wns WHS=$whs"
# CDC is a separate signoff report.  Keep it out of the timing-driven route
# candidate so the timing result/checkpoint has a bounded completion point;
# full/quick runs retain the detailed CDC report, after route artifacts exist.
if {$implementation ne "timing"} {
  report_cdc -details -file [file join $out_dir cdc.rpt]
}
