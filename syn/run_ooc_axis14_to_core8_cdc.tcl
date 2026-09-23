set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
if {[llength $argv] != 3} { error "usage: <part> <core_mhz> <out_dir>" }
set part [lindex $argv 0]
set core_mhz [expr {double([lindex $argv 1])}]
set out_dir [file normalize [lindex $argv 2]]
file mkdir $out_dir
cd $out_dir
create_project -in_memory -part $part
if {![info exists ::env(XILINX_VIVADO)]} { error "XILINX_VIVADO is required for XPM FIFO synthesis" }
set xpm_fifo_file [file join $::env(XILINX_VIVADO) data ip xpm xpm_fifo hdl xpm_fifo.sv]
set xpm_cdc_file [file join $::env(XILINX_VIVADO) data ip xpm xpm_cdc hdl xpm_cdc.sv]
set xpm_memory_file [file join $::env(XILINX_VIVADO) data ip xpm xpm_memory hdl xpm_memory.sv]
foreach xpm_file [list $xpm_cdc_file $xpm_memory_file $xpm_fifo_file] {
  if {![file exists $xpm_file]} { error "XPM source not found: $xpm_file" }
  read_verilog -sv $xpm_file
}
foreach file [list \
  [file join $root rtl axis dsm_reset_sync.sv] \
  [file join $root rtl axis dsm_xpm_async_fifo.sv] \
  [file join $root rtl axis dsm_axis14_to_core8_cdc.sv] \
  [file join $root syn rtl dsm_axis14_to_core8_cdc_ooc.sv]] { read_verilog -sv $file }
set_param general.maxThreads 1
set_param synth.maxThreads 1
# Match the known-stable thermo5 OOC synthesis strategy.  This also avoids
# using the default high-effort optimizer on the wide generic FIFO memory.
synth_design -top dsm_axis14_to_core8_cdc_ooc -part $part -mode out_of_context -flatten_hierarchy none -directive AreaOptimized_high
puts "AXIS14_TO_CORE8_CDC_OOC_STAGE=post_synth"
write_checkpoint -force [file join $out_dir synthesized.dcp]
puts "AXIS14_TO_CORE8_CDC_OOC_STAGE=checkpoint_written"
create_clock -name s_axis_aclk -period 8.000 [get_ports clk125]
create_clock -name core_clk -period [expr {1000.0/$core_mhz}] [get_ports clk218]
set_clock_groups -asynchronous -group [get_clocks s_axis_aclk] -group [get_clocks core_clk]
set_false_path -from [get_ports {rst125_n rst218_n}]
puts "AXIS14_TO_CORE8_CDC_OOC_STAGE=constraints_set"
opt_design
puts "AXIS14_TO_CORE8_CDC_OOC_STAGE=opt_done"
place_design
puts "AXIS14_TO_CORE8_CDC_OOC_STAGE=place_done"
phys_opt_design
puts "AXIS14_TO_CORE8_CDC_OOC_STAGE=physopt_done"
route_design
puts "AXIS14_TO_CORE8_CDC_OOC_STAGE=route_done"
report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing_summary.rpt]
set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup] == 0 || [llength $hold] == 0} { error "No timing path reported" }
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
if {$wns < 0.0} {set status FAIL_SETUP} elseif {$whs < 0.0} {set status FAIL_HOLD} else {set status PASS}
set f [open [file join $out_dir summary.csv] w]
puts $f "Part,Block,Source_MHz,Core_MHz,Status,WNS_ns,WHS_ns"
puts $f "$part,dsm_axis14_to_core8_cdc_ooc,125.00,[format %.2f $core_mhz],$status,[format %.3f $wns],[format %.3f $whs]"
close $f
puts "AXIS14_TO_CORE8_CDC_OOC_STATUS=$status"
