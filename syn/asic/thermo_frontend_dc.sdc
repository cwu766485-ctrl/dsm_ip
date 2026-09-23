create_clock -name clk125 -period 8.000 [get_ports clk125]
create_clock -name clk218 -period 4.571428 [get_ports clk218]
set_clock_groups -asynchronous -group [get_clocks clk125] -group [get_clocks clk218]
set_false_path -from [get_ports {rst125_n rst218_n}]
