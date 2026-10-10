# Integration-only timing contract for tid32_thermo5_axis_frontend_tx_ooc.
# Source after synthesis in a real parent design, not on the archived OOC DCP.
# The parent must supply measured board/launch/capture budgets in nanoseconds.
# This file deliberately does not waive reset or run_request paths.
foreach name {AXI_IN_MAX_NS AXI_IN_MIN_NS CORE_IN_MAX_NS CORE_IN_MIN_NS AXI_OUT_MAX_NS AXI_OUT_MIN_NS CORE_OUT_MAX_NS CORE_OUT_MIN_NS} {
  if {![info exists $name]} { error "Missing integration timing budget: $name" }
  if {![string is double -strict [set $name]]} { error "Non-numeric integration timing budget: $name" }
}
foreach {max_name min_name} {AXI_IN_MAX_NS AXI_IN_MIN_NS CORE_IN_MAX_NS CORE_IN_MIN_NS AXI_OUT_MAX_NS AXI_OUT_MIN_NS CORE_OUT_MAX_NS CORE_OUT_MIN_NS} {
  if {[set $min_name] > [set $max_name]} { error "Minimum exceeds maximum: $min_name / $max_name" }
}
foreach {name port period} {s_axis_aclk clk125 8.000 core_clk clk218 4.571428571} {
  if {[llength [get_ports -quiet $port]] != 1} { error "Missing top-level clock port: $port" }
  if {[llength [get_clocks -quiet $name]] == 0} {
    create_clock -name $name -period $period [get_ports $port]
  }
}
set_clock_groups -asynchronous -group [get_clocks s_axis_aclk] -group [get_clocks core_clk]
foreach port {run_request rst125_n rst218_n} {
  if {[llength [get_ports -quiet $port]] != 1} { error "Missing control port: $port" }
}

# run_request is a core_clk-synchronous level, never a raw AXI/CPU-domain bit.
# The upstream register and its source-to-pin delay must meet CORE_IN_*.
set axi_inputs [get_ports {s_valid s_frame_start s_i_vec[*] s_q_vec[*] s_frame_gain[*]}]
set core_inputs [get_ports {run_request dpd_active_taps[*] c1_re[*] c1_im[*] c3_re[*] c3_im[*] c5_re[*] c5_im[*]}]
set axi_outputs [get_ports {s_ready s_fifo_full}]
set core_outputs [get_ports {core_underflow core_protocol_error pa_valid[*] pa0_data[*] pa1_data[*] pa2_data[*] pa3_data[*]}]
foreach {ports clk max_var min_var} [list $axi_inputs s_axis_aclk AXI_IN_MAX_NS AXI_IN_MIN_NS $core_inputs core_clk CORE_IN_MAX_NS CORE_IN_MIN_NS] {
  set_input_delay -clock [get_clocks $clk] -max [set $max_var] $ports
  set_input_delay -clock [get_clocks $clk] -min [set $min_var] $ports
}
foreach {ports clk max_var min_var} [list $axi_outputs s_axis_aclk AXI_OUT_MAX_NS AXI_OUT_MIN_NS $core_outputs core_clk CORE_OUT_MAX_NS CORE_OUT_MIN_NS] {
  set_output_delay -clock [get_clocks $clk] -max [set $max_var] $ports
  set_output_delay -clock [get_clocks $clk] -min [set $min_var] $ports
}

# rst125_n/rst218_n: async assertion and synchronous release per destination
# clock must be implemented and audited in the parent.  No blanket reset
# false path or clock-group exception is added for these two inputs here.
puts "THERMO5_INTEGRATION_CONTRACT_APPLIED: reset/RDC and physical IO budgets require parent-level review"
