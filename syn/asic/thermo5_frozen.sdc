# Assumed IP boundary budgets, not measured parent/board timing.
create_clock -name clk125 -period 8.000 [get_ports clk125]
create_clock -name clk218 -period 4.571428571 [get_ports clk218]
set_clock_uncertainty -setup 0.10 [all_clocks]
set_clock_uncertainty -hold 0.05 [all_clocks]
set_clock_transition 0.10 [all_clocks]
set_clock_groups -asynchronous -group clk125 -group clk218
set_input_delay -max 0.40 -clock clk125 [get_ports {s_valid s_frame_start s_i_vec* s_q_vec* s_frame_gain* rst125_n}]
set_input_delay -min 0.10 -clock clk125 [get_ports {s_valid s_frame_start s_i_vec* s_q_vec* s_frame_gain* rst125_n}]
set_input_delay -max 0.40 -clock clk218 [get_ports {core_enable pa_ready* rst218_n}]
set_input_delay -min 0.10 -clock clk218 [get_ports {core_enable pa_ready* rst218_n}]
set_input_transition 0.10 [remove_from_collection [all_inputs] [get_ports {clk125 clk218}]]
set_output_delay -max 0.40 -clock clk125 [get_ports {s_ready s_fifo_full}]
set_output_delay -min 0.10 -clock clk125 [get_ports {s_ready s_fifo_full}]
set_output_delay -max 0.40 -clock clk218 [get_ports {core_underflow core_protocol_error pa_valid* pa0_data* pa1_data* pa2_data* pa3_data*}]
set_output_delay -min 0.10 -clock clk218 [get_ports {core_underflow core_protocol_error pa_valid* pa0_data* pa1_data* pa2_data* pa3_data*}]
# Library capacitance units: 0.005 pF = 5 fF per output.
set_load 0.005 [all_outputs]
# No blanket reset false path: retain recovery/removal checks.
