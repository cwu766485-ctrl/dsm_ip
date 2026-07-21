# DSM IP ZU15EG PS-DMA-ILA block-design template.
#
# Usage:
#   1. Create a Vivado project for the target ZU15EG board.
#   2. Create/configure the Zynq UltraScale+ PS using the board/vendor flow.
#   3. Package the DSM IP:
#        powershell -NoProfile -ExecutionPolicy Bypass -File ./ip/package_vivado_ip.ps1
#   4. Source this script from Vivado Tcl.
#
# The script intentionally does not configure DDR/MIO. That setup is
# board-specific and must come from the board vendor reference flow.

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".." ".."]]
set ip_repo [file join $repo_root "ip" "ip_repo"]

set_property ip_repo_paths [list $ip_repo] [current_project]
update_ip_catalog

if {[llength [get_bd_designs -quiet]] == 0} {
  create_bd_design dsm_zu15eg_bringup
}

current_bd_design [lindex [get_bd_designs] 0]

set ps [get_bd_cells -quiet zynq_ultra_ps_e_0]
if {[llength $ps] == 0} {
  error "Create and configure zynq_ultra_ps_e_0 first using the board/vendor PS preset."
}

set clk_pin [get_bd_pins -quiet $ps/pl_clk0]
set raw_rst_pin [get_bd_pins -quiet $ps/pl_resetn0]
set rst_pin [get_bd_pins -quiet rst_ps8_0_96M/peripheral_aresetn]
if {[llength $rst_pin] == 0} {
  set rst_pin $raw_rst_pin
}
set hpm_pin [get_bd_intf_pins -quiet $ps/M_AXI_HPM0_FPD]
set ps_slave_pin ""
foreach candidate {S_AXI_HPC0_FPD S_AXI_HP0_FPD S_AXI_HPC1_FPD S_AXI_HP1_FPD S_AXI_HP2_FPD S_AXI_HP3_FPD} {
  set pin [get_bd_intf_pins -quiet $ps/$candidate]
  if {[llength $pin] > 0} {
    set ps_slave_pin $pin
    break
  }
}

if {[llength $clk_pin] == 0 || [llength $rst_pin] == 0} {
  error "PS pl_clk0/pl_resetn0 pins are required."
}
if {[llength $hpm_pin] == 0} {
  error "Enable PS M_AXI_HPM0_FPD for AXI-Lite register access."
}
if {$ps_slave_pin eq ""} {
  puts "WARNING: Enable a PS S_AXI_HP*_FPD or S_AXI_HPC*_FPD slave port for AXI DMA memory reads."
}

create_bd_cell -type ip -vlnv dsm.local:communication:dsm_ip:1.0 dsm_ip_0
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma axi_dma_0
create_bd_cell -type ip -vlnv xilinx.com:ip:ila ila_dsm_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant axis_tuser_zero
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant obs_tdata_zero
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant obs_control_zero

set clk_freq [get_property CONFIG.FREQ_HZ $clk_pin]
if {$clk_freq eq ""} {
  set clk_freq [get_property FREQ_HZ $clk_pin]
}
if {$clk_freq ne ""} {
  foreach obj [list \
    [get_bd_pins dsm_ip_0/aclk] \
    [get_bd_intf_pins dsm_ip_0/s_axis] \
    [get_bd_intf_pins dsm_ip_0/s_axi] \
  ] {
    catch {set_property CONFIG.FREQ_HZ $clk_freq $obj}
    catch {set_property FREQ_HZ $clk_freq $obj}
  }
}

set_property -dict [list \
  CONFIG.c_include_sg {0} \
  CONFIG.c_include_mm2s {1} \
  CONFIG.c_include_s2mm {0} \
  CONFIG.c_sg_length_width {23} \
  CONFIG.c_m_axis_mm2s_tdata_width {32} \
] [get_bd_cells axi_dma_0]

set_property -dict [list \
  CONFIG.C_MONITOR_TYPE {Native} \
  CONFIG.C_NUM_OF_PROBES {10} \
  CONFIG.C_PROBE0_WIDTH {1} \
  CONFIG.C_PROBE1_WIDTH {1} \
  CONFIG.C_PROBE2_WIDTH {32} \
  CONFIG.C_PROBE3_WIDTH {1} \
  CONFIG.C_PROBE4_WIDTH {1} \
  CONFIG.C_PROBE5_WIDTH {1} \
  CONFIG.C_PROBE6_WIDTH {16} \
  CONFIG.C_PROBE7_WIDTH {1} \
  CONFIG.C_PROBE8_WIDTH {8} \
  CONFIG.C_PROBE9_WIDTH {8} \
] [get_bd_cells ila_dsm_0]

set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {0}] [get_bd_cells axis_tuser_zero]
set_property -dict [list CONFIG.CONST_WIDTH {32} CONFIG.CONST_VAL {0}] [get_bd_cells obs_tdata_zero]
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {0}] [get_bd_cells obs_control_zero]

connect_bd_net $clk_pin [get_bd_pins dsm_ip_0/aclk]
connect_bd_net $clk_pin [get_bd_pins axi_dma_0/s_axi_lite_aclk]
connect_bd_net $clk_pin [get_bd_pins axi_dma_0/m_axi_mm2s_aclk]
set dma_axis_clk [get_bd_pins -quiet axi_dma_0/m_axis_mm2s_aclk]
if {[llength $dma_axis_clk] > 0} {
  connect_bd_net $clk_pin $dma_axis_clk
}
connect_bd_net $clk_pin [get_bd_pins ila_dsm_0/clk]

connect_bd_net $rst_pin [get_bd_pins dsm_ip_0/aresetn]
connect_bd_net $rst_pin [get_bd_pins axi_dma_0/axi_resetn]

connect_bd_net [get_bd_pins axi_dma_0/m_axis_mm2s_tdata]  [get_bd_pins dsm_ip_0/s_axis_tdata]
connect_bd_net [get_bd_pins axi_dma_0/m_axis_mm2s_tvalid] [get_bd_pins dsm_ip_0/s_axis_tvalid]
connect_bd_net [get_bd_pins axi_dma_0/m_axis_mm2s_tready] [get_bd_pins dsm_ip_0/s_axis_tready]
connect_bd_net [get_bd_pins axi_dma_0/m_axis_mm2s_tlast]  [get_bd_pins dsm_ip_0/s_axis_tlast]
connect_bd_net [get_bd_pins axis_tuser_zero/dout]         [get_bd_pins dsm_ip_0/s_axis_tuser]
connect_bd_net [get_bd_pins obs_tdata_zero/dout]          [get_bd_pins dsm_ip_0/s_axis_obs_tdata]
connect_bd_net [get_bd_pins obs_control_zero/dout]        [get_bd_pins dsm_ip_0/s_axis_obs_tlast]
connect_bd_net [get_bd_pins obs_control_zero/dout]        [get_bd_pins dsm_ip_0/s_axis_obs_tuser]
connect_bd_net [get_bd_pins obs_control_zero/dout]        [get_bd_pins dsm_ip_0/s_axis_obs_tvalid]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config [list Clk_master $clk_pin Clk_slave $clk_pin Clk_xbar $clk_pin Master $hpm_pin Slave [get_bd_intf_pins dsm_ip_0/s_axi]] \
  [get_bd_intf_pins dsm_ip_0/s_axi]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config [list Clk_master $clk_pin Clk_slave $clk_pin Clk_xbar $clk_pin Master $hpm_pin Slave [get_bd_intf_pins axi_dma_0/S_AXI_LITE]] \
  [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

if {$ps_slave_pin ne ""} {
  create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect dma_mem_smc
  set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells dma_mem_smc]
  connect_bd_net $clk_pin [get_bd_pins dma_mem_smc/aclk]
  connect_bd_net $rst_pin [get_bd_pins dma_mem_smc/aresetn]
  connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins dma_mem_smc/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins dma_mem_smc/M00_AXI] $ps_slave_pin
}

connect_bd_net [get_bd_pins dsm_ip_0/s_axis_tvalid] [get_bd_pins ila_dsm_0/probe0]
connect_bd_net [get_bd_pins dsm_ip_0/s_axis_tready] [get_bd_pins ila_dsm_0/probe1]
connect_bd_net [get_bd_pins dsm_ip_0/s_axis_tdata]  [get_bd_pins ila_dsm_0/probe2]
connect_bd_net [get_bd_pins dsm_ip_0/s_axis_tlast]  [get_bd_pins ila_dsm_0/probe3]
connect_bd_net [get_bd_pins dsm_ip_0/s_axis_tuser]  [get_bd_pins ila_dsm_0/probe4]
connect_bd_net [get_bd_pins dsm_ip_0/rf_valid]      [get_bd_pins ila_dsm_0/probe5]
connect_bd_net [get_bd_pins dsm_ip_0/rf_signed]     [get_bd_pins ila_dsm_0/probe6]
connect_bd_net [get_bd_pins dsm_ip_0/dsm_valid]     [get_bd_pins ila_dsm_0/probe7]
connect_bd_net [get_bd_pins dsm_ip_0/i_yout]        [get_bd_pins ila_dsm_0/probe8]
connect_bd_net [get_bd_pins dsm_ip_0/q_yout]        [get_bd_pins ila_dsm_0/probe9]

assign_bd_address
validate_bd_design
save_bd_design

puts "DSM ZU15EG bring-up BD template applied. Review address map and PS HP/HPC connectivity before implementation."
