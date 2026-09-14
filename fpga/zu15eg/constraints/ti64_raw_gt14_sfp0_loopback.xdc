# XCZU15EG SFP0 raw-GTH loopback constraints, verified against the vendor
# SFP loopback project's port.xdc.  The GTH Wizard selects X1Y12 (quad 230).

# 200 MHz PL_DDR4 differential clock: reset-controller freerun clock.
set_property PACKAGE_PIN AL5 [get_ports pl_ddr4_clk_n]
set_property PACKAGE_PIN AL6 [get_ports pl_ddr4_clk_p]
set_property IOSTANDARD LVDS [get_ports {pl_ddr4_clk_n pl_ddr4_clk_p}]
create_clock -name pl_ddr4_clk_p -period 5.000 [get_ports pl_ddr4_clk_p]

# 125 MHz dedicated GTH reference clock, quad 230, refclk 0.
set_property PACKAGE_PIN C7 [get_ports gty_230_clk_n]
set_property PACKAGE_PIN C8 [get_ports gty_230_clk_p]
create_clock -name gty_230_clk_p -period 8.000 [get_ports gty_230_clk_p]

# SFP0 serial lane (GTH X1Y12).
set_property PACKAGE_PIN D1 [get_ports sfp0_rx_n]
set_property PACKAGE_PIN D2 [get_ports sfp0_rx_p]
set_property PACKAGE_PIN E3 [get_ports sfp0_tx_n]
set_property PACKAGE_PIN E4 [get_ports sfp0_tx_p]

# SFP0 optical transmitter disable, active high.
set_property PACKAGE_PIN AN12 [get_ports sfp0_tx_disable]
set_property IOSTANDARD LVCMOS33 [get_ports sfp0_tx_disable]
