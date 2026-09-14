# One isolated state-map OOC stage per Vivado process.
set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
if {[llength $argv] != 4} { error "usage: <top> <part> <target_mhz> <out_dir>" }
set top [lindex $argv 0]
set part [lindex $argv 1]
set target_mhz [expr {double([lindex $argv 2])}]
set out_dir [file normalize [lindex $argv 3]]
if {$target_mhz <= 0.0} { error "Target frequency must be positive" }
set period_ns [expr {1000.0 / $target_mhz}]
file mkdir $out_dir
cd $out_dir
create_project -in_memory -part $part
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_phase_map1.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_phase_map4.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_map_compose.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_map_compose_step.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_map_region_select.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_map_compose_pipe.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_map_compose_ctx_pipe.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_state_selector.sv]
read_verilog -sv [file join $root syn rtl bp_ef2_state_map_ooc_tops.sv]
set_param general.maxThreads 1
set_param synth.maxThreads 1
synth_design -top $top -part $part -mode out_of_context -flatten_hierarchy none -directive AreaOptimized_high
write_checkpoint -force [file join $out_dir synthesized.dcp]
write_verilog -force -mode synth_stub [file join $out_dir synthesized_stub.v]
create_clock -name clk -period $period_ns [get_ports clk]
set inputs [get_ports -quiet -filter {DIRECTION == IN && NAME != "clk"}]
set outputs [get_ports -quiet -filter {DIRECTION == OUT}]
if {[llength $inputs] > 0} { set_input_delay 0.0 -clock clk $inputs }
if {[llength $outputs] > 0} { set_output_delay 0.0 -clock clk $outputs }
report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing.rpt]
set paths [get_timing_paths -max_paths 1 -quiet]
if {[llength $paths] == 0} { error "No timing path reported" }
set wns [get_property SLACK [lindex $paths 0]]
set hold_paths [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $hold_paths] == 0} { error "No hold timing path reported" }
set whs [get_property SLACK [lindex $hold_paths 0]]
set fmax [expr {1000.0 / ($period_ns - double($wns))}]
if {$wns < 0.0} {
  set status "FAIL_SETUP"
} elseif {$whs < 0.0} {
  set status "FAIL_HOLD"
} else {
  set status "PASS"
}
set fp [open [file join $out_dir summary.csv] w]
puts $fp "Part,Block,Target_MHz,Status,WNS_ns,WHS_ns,Fmax_est_MHz"
puts $fp "$part,$top,[format %.2f $target_mhz],$status,[format %.3f $wns],[format %.3f $whs],[format %.2f $fmax]"
close $fp
puts "STATE_MAP_STAGE_OOC_STATUS=$status"
