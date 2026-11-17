# Real VCU118 GTY Wizard feasibility probe; separate fresh output per refclock.
if {[llength $argv]!=2} {error "usage: <refclk_MHz> <new_output_dir>"}
set ref [lindex $argv 0]
set out [file normalize [lindex $argv 1]]
if {[file exists $out]} {error "refusing to overwrite"}
file mkdir $out
create_project gty14 [file join $out project] -part xcvu9p-flga2104-2L-e
# Candidate GTY coordinates only; board connector allocation is not assumed.
set channels {X0Y4 X0Y5}
create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -module_name vcu118_gty14
set ip [get_ips vcu118_gty14]
set_property -dict [list CONFIG.CHANNEL_ENABLE $channels CONFIG.GT_DIRECTION {BOTH} CONFIG.GT_TYPE {GTY} \
 CONFIG.TX_DATA_ENCODING {RAW} CONFIG.TX_LINE_RATE {14.0} CONFIG.TX_REFCLK_FREQUENCY $ref \
 CONFIG.TX_USER_DATA_WIDTH {64} CONFIG.TX_INT_DATA_WIDTH {32} CONFIG.TX_BUFFER_MODE {1} \
 CONFIG.RX_DATA_DECODING {RAW} CONFIG.RX_LINE_RATE {14.0} CONFIG.RX_REFCLK_FREQUENCY $ref \
 CONFIG.RX_USER_DATA_WIDTH {64} CONFIG.RX_INT_DATA_WIDTH {32} CONFIG.RX_SLIDE_MODE {PMA} \
 CONFIG.ENABLE_OPTIONAL_PORTS {loopback_in rxslide_in} CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
 CONFIG.LOCATE_RX_USER_CLOCKING {CORE} CONFIG.LOCATE_RESET_CONTROLLER {CORE} CONFIG.FREERUN_FREQUENCY {200}] $ip
validate_ip $ip
report_property -all $ip -file [file join $out gty_properties.rpt]
generate_target all $ip
puts "GTY_WIZARD_CANDIDATE_PASS ref_mhz=$ref channels=$channels serial_gbps=14.000 width=64 raw=1"
