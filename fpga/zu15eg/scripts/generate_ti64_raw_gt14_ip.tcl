# Generate, outside the source tree, the board-specific raw GTH serializer IP.
# Usage: vivado -mode batch -source generate_ti64_raw_gt14_ip.tcl -tclargs <out_dir>
if {[llength $argv] != 1} { error "usage: <out_dir>" }
set out_dir [file normalize [lindex $argv 0]]
file mkdir $out_dir
create_project ti64_raw_gt14 $out_dir -part xczu15eg-ffvb1156-2-i -force
set_property target_language Verilog [current_project]
create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -module_name ti64_raw_gt14
set ip [get_ips ti64_raw_gt14]
set_property -dict [list \
  CONFIG.CHANNEL_ENABLE {X1Y12} \
  CONFIG.GT_DIRECTION {BOTH} \
  CONFIG.GT_TYPE {GTH} \
  CONFIG.TX_DATA_ENCODING {RAW} \
  CONFIG.TX_LINE_RATE {14.0} \
  CONFIG.TX_REFCLK_FREQUENCY {125} \
  CONFIG.TX_USER_DATA_WIDTH {64} \
  CONFIG.TX_INT_DATA_WIDTH {32} \
  CONFIG.TX_BUFFER_MODE {1} \
  CONFIG.RX_DATA_DECODING {RAW} \
  CONFIG.RX_LINE_RATE {14.0} \
  CONFIG.RX_REFCLK_FREQUENCY {125} \
  CONFIG.RX_USER_DATA_WIDTH {64} \
  CONFIG.RX_INT_DATA_WIDTH {32} \
  CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
  CONFIG.LOCATE_RX_USER_CLOCKING {CORE} \
  CONFIG.LOCATE_RESET_CONTROLLER {CORE} \
  CONFIG.FREERUN_FREQUENCY {200} \
  CONFIG.DISABLE_LOC_XDC {1} \
] $ip
generate_target all $ip
export_ip_user_files -of_objects $ip -no_script -sync -force -quiet
report_property -all $ip
puts "TI64_RAW_GT14_IP_GENERATED=$out_dir"
