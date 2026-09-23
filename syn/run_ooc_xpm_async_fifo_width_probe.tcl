set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
if {[llength $argv] != 3} { error "usage: <part> <data_width> <out_dir>" }
set part [lindex $argv 0]
set data_width [expr {int([lindex $argv 1])}]
set out_dir [file normalize [lindex $argv 2]]
if {$data_width < 1} { error "data_width must be positive" }
if {![info exists ::env(XILINX_VIVADO)]} { error "XILINX_VIVADO is required" }
file mkdir $out_dir
cd $out_dir
create_project -in_memory -part $part
foreach xpm_file [list \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_cdc hdl xpm_cdc.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_memory hdl xpm_memory.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_fifo hdl xpm_fifo.sv]] {
  if {![file exists $xpm_file]} { error "XPM source not found: $xpm_file" }
  read_verilog -sv $xpm_file
}
read_verilog -sv [file join $root syn rtl xpm_async_fifo_width_probe_ooc.sv]
set_param general.maxThreads 1
set_param synth.maxThreads 1
synth_design -top xpm_async_fifo_width_probe_ooc -part $part -mode out_of_context \
  -flatten_hierarchy none -directive AreaOptimized_high -generic DATA_W=$data_width
puts "XPM_WIDTH_PROBE_STAGE=post_synth"
write_checkpoint -force [file join $out_dir synthesized.dcp]
create_clock -name clk125 -period 8.000 [get_ports clk125]
create_clock -name clk218 -period [expr {1000.0/218.75}] [get_ports clk218]
set_clock_groups -asynchronous -group [get_clocks clk125] -group [get_clocks clk218]
set_false_path -from [get_ports rst]
puts "XPM_WIDTH_PROBE_STAGE=constraints_set"
opt_design
place_design
phys_opt_design
route_design
report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing_summary.rpt]
set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup] == 0 || [llength $hold] == 0} { error "No timing path reported" }
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
if {$wns < 0.0} {set status FAIL_SETUP} elseif {$whs < 0.0} {set status FAIL_HOLD} else {set status PASS}
set f [open [file join $out_dir summary.csv] w]
puts $f "Part,Block,Data_W,Status,WNS_ns,WHS_ns"
puts $f "$part,xpm_async_fifo_width_probe,$data_width,$status,[format %.3f $wns],[format %.3f $whs]"
close $f
puts "XPM_WIDTH_PROBE_STATUS=$status"
