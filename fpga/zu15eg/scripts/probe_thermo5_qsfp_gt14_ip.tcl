# Feasibility probe only: actual board schematic maps QSFP1 TX1..4 to bank 128.
# Do not treat IP generation as routed STA or board output validation.
if {[llength $argv] != 3} { error "usage: <out_dir> <line_rate_gbps> <refclk_mhz>" }
set out_dir [file normalize [lindex $argv 0]]
set line_rate [lindex $argv 1]
set refclk_mhz [lindex $argv 2]
file mkdir $out_dir
create_project thermo5_qsfp_gt14_probe [file join $out_dir project] \
  -part xczu15eg-ffvb1156-2-i -force
set_property target_language Verilog [current_project]
create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip \
  -module_name thermo5_qsfp_gt14_probe
set ip [get_ips thermo5_qsfp_gt14_probe]
set_property -dict [list \
  CONFIG.CHANNEL_ENABLE {X0Y4 X0Y5 X0Y6 X0Y7} \
  CONFIG.GT_DIRECTION {BOTH} \
  CONFIG.GT_TYPE {GTH} \
  CONFIG.TX_DATA_ENCODING {RAW} \
  CONFIG.TX_LINE_RATE $line_rate \
  CONFIG.TX_REFCLK_FREQUENCY $refclk_mhz \
  CONFIG.TX_USER_DATA_WIDTH {64} \
  CONFIG.TX_INT_DATA_WIDTH {32} \
  CONFIG.TX_BUFFER_MODE {1} \
  CONFIG.RX_DATA_DECODING {RAW} \
  CONFIG.RX_LINE_RATE $line_rate \
  CONFIG.RX_REFCLK_FREQUENCY $refclk_mhz \
  CONFIG.RX_USER_DATA_WIDTH {64} \
  CONFIG.RX_INT_DATA_WIDTH {32} \
  CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
  CONFIG.LOCATE_RX_USER_CLOCKING {CORE} \
  CONFIG.LOCATE_RESET_CONTROLLER {CORE} \
  CONFIG.FREERUN_FREQUENCY {200} \
  CONFIG.DISABLE_LOC_XDC {1} \
] $ip
generate_target all $ip
report_property -all $ip -file [file join $out_dir gt_properties.rpt]
puts "THERMO5_QSFP_GT_IP_GENERATED=$out_dir RATE=$line_rate REFCLK=$refclk_mhz"
