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
add_files -fileset sim_1 -norecurse [file join $repo dv verif integration vcu118_arch tb_vcu118_gty14_pa_replay.sv]
add_files -fileset sim_1 -norecurse [file join $repo research vcu118_arch thermo5_frame_prefill_tx.sv]
set capture [file normalize [file join $repo .. thermo5_runtime_product runs runtime_qam281001 capture_xpm_fixed]]
add_files -fileset sim_1 -norecurse [file join $capture phase1_arch2_pa0.mem]
add_files -fileset sim_1 -norecurse [file join $capture phase1_arch2_pa1.mem]
set_property top tb_vcu118_gty14_pa_replay [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
run all
puts "GTY_SIM_RUN_FINISHED"
