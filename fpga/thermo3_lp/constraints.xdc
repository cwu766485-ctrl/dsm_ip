create_clock -name s_axis_aclk -period 8.000 [get_ports clk125]
create_clock -name core_clk -period 4.571428571 [get_ports clk218]
set_clock_groups -asynchronous -group [get_clocks s_axis_aclk] -group [get_clocks core_clk]
set_false_path -from [get_ports {rst125_n rst218_n run_request}]
