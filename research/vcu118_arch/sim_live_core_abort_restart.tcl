# Create a fresh GT Wizard simulation project; no board or routed signoff.
if {[llength $argv]!=1} {error "usage: <new-output-dir>"}
set out [file normalize [lindex $argv 0]]
if {[file exists $out]} {error "refusing to overwrite"}
set repo [file normalize [file join [file dirname [info script]] ../..]]
file mkdir $out
create_project gty_sim [file join $out project] -part xcvu9p-flga2104-2L-e
create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -module_name vcu118_gty14
set ip [get_ips vcu118_gty14]
set_property -dict [list CONFIG.CHANNEL_ENABLE {X1Y48 X1Y49} CONFIG.GT_DIRECTION {BOTH} CONFIG.GT_TYPE {GTY} \
 CONFIG.TX_DATA_ENCODING {RAW} CONFIG.TX_LINE_RATE {14.0} CONFIG.TX_REFCLK_FREQUENCY {125} \
 CONFIG.TX_USER_DATA_WIDTH {64} CONFIG.TX_INT_DATA_WIDTH {32} CONFIG.TX_BUFFER_MODE {1} \
 CONFIG.RX_DATA_DECODING {RAW} CONFIG.RX_LINE_RATE {14.0} CONFIG.RX_REFCLK_FREQUENCY {125} \
 CONFIG.RX_USER_DATA_WIDTH {64} CONFIG.RX_INT_DATA_WIDTH {32} CONFIG.RX_SLIDE_MODE {PMA} \
 CONFIG.ENABLE_OPTIONAL_PORTS {loopback_in rxslide_in} CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
 CONFIG.LOCATE_RX_USER_CLOCKING {CORE} CONFIG.LOCATE_RESET_CONTROLLER {CORE} CONFIG.FREERUN_FREQUENCY {200}] $ip
validate_ip $ip
generate_target simulation $ip
add_files -fileset sim_1 -norecurse [file join $repo dv verif integration vcu118_arch tb_vcu118_live_core_abort_restart.sv]
# Add the canonical product RTL and required XPM models. Keep the GTY core's
# TXUSRCLK2 as the runtime core clock, so there is no undocumented buffer CDC.
set f [open [file join $repo dv uvm sim thermo5_sku_filelist.f] r]
file mkdir [file join $out isolated_sources]
foreach line [split [read $f] "\n"] {
 set line [string trim $line]
 if {[string match rtl/* $line]} {
  if {$line eq "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv"} {
    set h [open [file join $repo research vcu118_arch thermo5_dpd_axi_lite_cfg_epoch_candidate3.sv] r]
    set data [string map {"module thermo5_dpd_axi_lite_cfg_epoch_candidate3 #( " "module thermo5_dpd_axi_lite_cfg #( "} [read $h]];close $h
    # Exact module spelling, no source or product-tree rewrite.
    set data [string map {"thermo5_dpd_axi_lite_cfg_epoch_candidate3 #( " "thermo5_dpd_axi_lite_cfg #( "} $data]
    set data [string map {"thermo5_dpd_axi_lite_cfg_epoch_candidate3 #(" "thermo5_dpd_axi_lite_cfg #("} $data]
    set path [file join $out isolated_sources thermo5_dpd_axi_lite_cfg.sv];set h [open $path w];puts -nonewline $h $data;close $h
    add_files -fileset sim_1 -norecurse $path
  } elseif {$line eq "rtl/tx_bandpass_if/tid32_thermo5_runtime_tx.sv"} {
    set h [open [file join $repo research vcu118_arch tid32_thermo5_runtime_abort_candidate.sv] r]
    set data [string map {"tid32_thermo5_runtime_abort_candidate #(" "tid32_thermo5_runtime_tx #("} [read $h]];close $h
    set path [file join $out isolated_sources tid32_thermo5_runtime_tx.sv];set h [open $path w];puts -nonewline $h $data;close $h
    add_files -fileset sim_1 -norecurse $path
  } else {add_files -fileset sim_1 -norecurse [file join $repo $line]}
 }
}
close $f
foreach x {xpm_cdc xpm_memory xpm_fifo} {
 add_files -fileset sim_1 -norecurse [file join $::env(XILINX_VIVADO) data ip xpm $x hdl ${x}.sv]
}
add_files -fileset sim_1 -norecurse [file join $repo research vcu118_arch thermo5_frame_prefill_tx.sv]
set vectors [file normalize [file join $repo .. thermo5_runtime_product runs runtime_qam281001 vectors]]
foreach n {arch2_pa0.mem arch2_pa1.mem axis_i_samples.mem axis_q_samples.mem} {
 add_files -fileset sim_1 -norecurse [file join $vectors $n]
}
add_files -fileset sim_1 -norecurse [file join $repo research vcu118_arch thermo5_axis_frame_prefill.sv]
set_property verilog_define {SOURCE_PREFILL} [get_filesets sim_1]
set_property top tb_vcu118_live_core_abort_restart [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
run all
puts "GTY_SIM_RUN_FINISHED"
