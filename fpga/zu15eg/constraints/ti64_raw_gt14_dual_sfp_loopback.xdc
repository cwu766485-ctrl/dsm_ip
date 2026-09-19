# XCZU15EG raw-GTH dual-SFP loopback constraints. The GT Wizard fixes
# X1Y12/X1Y13 in quad 230; both channels share this dedicated 125-MHz refclk.
set_property PACKAGE_PIN AL5 [get_ports pl_ddr4_clk_n]
set_property PACKAGE_PIN AL6 [get_ports pl_ddr4_clk_p]
set_property IOSTANDARD LVDS [get_ports {pl_ddr4_clk_n pl_ddr4_clk_p}]
create_clock -name pl_ddr4_clk_p -period 5.000 [get_ports pl_ddr4_clk_p]

set_property PACKAGE_PIN C7 [get_ports gty_230_clk_n]
set_property PACKAGE_PIN C8 [get_ports gty_230_clk_p]
# The GT reference is buffered by IBUFDS_GTE4 in the link wrapper. A primary
# clock belongs on the board input port; Vivado then derives the GTE/QPLL and
# unique 218.75-MHz TX/RX user clocks. Do not create clocks on the GTE output
# or the Wizard user-clock outputs: both forms create invalid related clocks.
create_clock -name gty_230_refclk -period 8.000 [get_ports gty_230_clk_p]

# The transmitter user clock is reference-derived while RXUSRCLK2 is
# recovered by the receiver CDR.  They are asynchronous domains; all debug
# observability crossings use the marked two-flop synchronizer in the top.
set_clock_groups -asynchronous \
  -group [get_clocks u_gtwizard_n_2] \
  -group [get_clocks rx_usrclk2]

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
