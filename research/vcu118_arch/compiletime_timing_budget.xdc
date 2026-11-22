# Provisional compile-time-top clock budget for the VCU118 architecture study.
# This native XDC contains only clocks and is read before synth_design. The PPA
# Tcl applies the modeled 0.2 ns interface delays after elaboration. This is
# not a board XDC.
create_clock -name core_clk -period 4.571428571 [get_ports core_clk]
create_clock -name s_axis_aclk -period 8.000 [get_ports s_axis_aclk]
create_clock -name s_axil_aclk -period 10.000 [get_ports s_axil_aclk]
