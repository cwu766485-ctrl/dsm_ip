# Constraints for the dual-SFP three-level Cartesian TID GTH target.
# The payload top intentionally has no TX/RX fabric data crossing, so no
# hierarchy-dependent asynchronous clock-group command is required here.
set_property PACKAGE_PIN AL5 [get_ports pl_ddr4_clk_n]
set_property PACKAGE_PIN AL6 [get_ports pl_ddr4_clk_p]
set_property IOSTANDARD LVDS [get_ports {pl_ddr4_clk_n pl_ddr4_clk_p}]
create_clock -name pl_ddr4_clk_p -period 5.000 [get_ports pl_ddr4_clk_p]

set_property PACKAGE_PIN C7 [get_ports gty_230_clk_n]
set_property PACKAGE_PIN C8 [get_ports gty_230_clk_p]
create_clock -name gty_230_refclk -period 8.000 [get_ports gty_230_clk_p]

set_property PACKAGE_PIN D1 [get_ports sfp0_rx_n]
set_property PACKAGE_PIN D2 [get_ports sfp0_rx_p]
set_property PACKAGE_PIN E3 [get_ports sfp0_tx_n]
set_property PACKAGE_PIN E4 [get_ports sfp0_tx_p]
set_property PACKAGE_PIN AN12 [get_ports sfp0_tx_disable]

set_property PACKAGE_PIN C3 [get_ports sfp1_rx_n]
set_property PACKAGE_PIN C4 [get_ports sfp1_rx_p]
set_property PACKAGE_PIN D5 [get_ports sfp1_tx_n]
set_property PACKAGE_PIN D6 [get_ports sfp1_tx_p]
set_property PACKAGE_PIN AP12 [get_ports sfp1_tx_disable]
set_property IOSTANDARD LVCMOS33 [get_ports {sfp0_tx_disable sfp1_tx_disable}]
