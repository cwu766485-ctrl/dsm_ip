create_clock -name clk -period 10.000 [get_ports clk]

# This OOC run is a proxy for core-internal PPA comparison.  Top-level pin
# timing is intentionally excluded because the final SoC/board shell owns
# input/output registers, placement, and HD.CLK_SRC/PARTPIN constraints.
set_false_path -from [get_ports -quiet {rst_n enable use_nco in_valid phase_inc[*] i_data[*] q_data[*]}]
set_false_path -to [all_outputs]
