# Prospective physical GT pins on XCZU15EG-FFVB1156. The board SI5341
# bank-128 output is *assumed* to have been changed to 125 MHz; this XDC
# cannot program or measure the clock generator.
set_property PACKAGE_PIN R27 [get_ports mgtrefclk125_p]
set_property PACKAGE_PIN R28 [get_ports mgtrefclk125_n]
create_clock -name mgtrefclk125 -period 8.000 [get_ports mgtrefclk125_p]
create_clock -name axi_clk125 -period 8.000 [get_ports axi_clk125]
create_clock -name axil_clk100 -period 10.000 [get_ports axil_clk100]
create_clock -name freerun_clk200 -period 5.000 [get_ports freerun_clk200]

# Provisional parent-interface budgets for routed digital STA. These are
# explicit assumptions (not measured board numbers): the AXI producer launches
# within 0.20..2.00 ns of axi_clk125, and synchronous status consumers allow
# 0.00..1.50 ns after their sampling edge. Replace with the real SoC/board
# timing contract before system or board signoff. reset_n is asynchronous and
# is intentionally excluded from ordinary data I/O delays.
set axi_inputs [get_ports {s_axis_tvalid s_axis_tlast s_axis_frame_start s_axis_frame_gain[*] s_axis_i_vec[*] s_axis_q_vec[*]}]
set_input_delay -clock [get_clocks axi_clk125] -max 2.000 $axi_inputs
set_input_delay -clock [get_clocks axi_clk125] -min 0.200 $axi_inputs

set axil_inputs [get_ports {s_axil_awaddr[*] s_axil_awvalid s_axil_wdata[*] s_axil_wstrb[*] s_axil_wvalid s_axil_bready s_axil_araddr[*] s_axil_arvalid s_axil_rready}]
set_input_delay -clock [get_clocks axil_clk100] -max 2.000 $axil_inputs
set_input_delay -clock [get_clocks axil_clk100] -min 0.200 $axil_inputs

set reset_ctrl_inputs [get_ports fabric_clocks_stable]
set_input_delay -clock [get_clocks freerun_clk200] -max 2.000 $reset_ctrl_inputs
set_input_delay -clock [get_clocks freerun_clk200] -min 0.200 $reset_ctrl_inputs

set axi_outputs [get_ports {s_axis_tready s_axis_fifo_full}]
set_output_delay -clock [get_clocks axi_clk125] -max 1.500 $axi_outputs
set_output_delay -clock [get_clocks axi_clk125] -min 0.000 $axi_outputs

set axil_outputs [get_ports {s_axil_awready s_axil_wready s_axil_bresp[*] s_axil_bvalid s_axil_arready s_axil_rdata[*] s_axil_rresp[*] s_axil_rvalid}]
set_output_delay -clock [get_clocks axil_clk100] -max 1.500 $axil_outputs
set_output_delay -clock [get_clocks axil_clk100] -min 0.000 $axil_outputs

set core_outputs [get_ports {core_underflow core_protocol_error stream_fault pa_enable}]
set_output_delay -clock [get_clocks core_clk218] -max 1.500 $core_outputs
set_output_delay -clock [get_clocks core_clk218] -min 0.000 $core_outputs

set_output_delay -clock [get_clocks freerun_clk200] -max 1.500 [get_ports link_ready]
set_output_delay -clock [get_clocks freerun_clk200] -min 0.000 [get_ports link_ready]

# The diagnostic gt_rxdata output budget is applied after synthesis in the
# parent Tcl flow, once the Wizard has created its RX user clock. Serial QSFP
# pins are GT hard PHY ports and are audited through transceiver constraints.

set_property PACKAGE_PIN T29 [get_ports {qsfp_tx_p[0]}]
set_property PACKAGE_PIN T30 [get_ports {qsfp_tx_n[0]}]
set_property PACKAGE_PIN R31 [get_ports {qsfp_tx_p[1]}]
set_property PACKAGE_PIN R32 [get_ports {qsfp_tx_n[1]}]
set_property PACKAGE_PIN P29 [get_ports {qsfp_tx_p[2]}]
set_property PACKAGE_PIN P30 [get_ports {qsfp_tx_n[2]}]
set_property PACKAGE_PIN M29 [get_ports {qsfp_tx_p[3]}]
set_property PACKAGE_PIN M30 [get_ports {qsfp_tx_n[3]}]
set_property PACKAGE_PIN T33 [get_ports {qsfp_rx_p[0]}]
set_property PACKAGE_PIN T34 [get_ports {qsfp_rx_n[0]}]
set_property PACKAGE_PIN P33 [get_ports {qsfp_rx_p[1]}]
set_property PACKAGE_PIN P34 [get_ports {qsfp_rx_n[1]}]
set_property PACKAGE_PIN N31 [get_ports {qsfp_rx_p[2]}]
set_property PACKAGE_PIN N32 [get_ports {qsfp_rx_n[2]}]
set_property PACKAGE_PIN M33 [get_ports {qsfp_rx_p[3]}]
set_property PACKAGE_PIN M34 [get_ports {qsfp_rx_n[3]}]

# AXI payloads belong to a future SoC parent, not board pins. Their delays
# above are explicit provisional budgets; replace them with measured SoC I/O
# timing before system signoff. No asynchronous-reset false path is applied.
