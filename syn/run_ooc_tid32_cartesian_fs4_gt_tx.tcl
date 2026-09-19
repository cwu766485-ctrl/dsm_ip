set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
if {[llength $argv] != 3} { error "usage: <part> <target_mhz> <out_dir>" }
set part [lindex $argv 0]
set target_mhz [expr {double([lindex $argv 1])}]
set out_dir [file normalize [lindex $argv 2]]
if {$target_mhz <= 0.0} { error "Target frequency must be positive" }
set period_ns [expr {1000.0 / $target_mhz}]
file mkdir $out_dir
cd $out_dir
create_project -in_memory -part $part
read_verilog -sv [file join $root rtl gt gt_tx_user_bridge.sv]
read_verilog -sv [file join $root rtl gt gt_tx_raw64_boundary.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if tid32_cartesian_fs4_gt_tx.sv]
read_verilog -sv [file join $root syn rtl tid32_cartesian_fs4_gt_tx_ooc.sv]
set_param general.maxThreads 1
set_param synth.maxThreads 1
synth_design -top tid32_cartesian_fs4_gt_tx_ooc -part $part -mode out_of_context -flatten_hierarchy none -directive AreaOptimized_high
write_checkpoint -force [file join $out_dir synthesized.dcp]
create_clock -name clk -period $period_ns [get_ports clk]
set_false_path -from [get_ports rst_n]
opt_design
place_design
phys_opt_design
route_design
report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing_summary.rpt]
set setup_paths [get_timing_paths -max_paths 1 -quiet]
set hold_paths [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup_paths] == 0 || [llength $hold_paths] == 0} { error "No timing path reported" }
set wns [get_property SLACK [lindex $setup_paths 0]]
set whs [get_property SLACK [lindex $hold_paths 0]]
set fmax [expr {1000.0 / ($period_ns - double($wns))}]
if {$wns < 0.0} { set status "FAIL_SETUP" } elseif {$whs < 0.0} { set status "FAIL_HOLD" } else { set status "PASS" }
set fp [open [file join $out_dir summary.csv] w]
puts $fp "Part,Block,Target_MHz,Status,WNS_ns,WHS_ns,Fmax_est_MHz"
puts $fp "$part,tid32_cartesian_fs4_gt_tx_ooc,[format %.2f $target_mhz],$status,[format %.3f $wns],[format %.3f $whs],[format %.2f $fmax]"
close $fp
puts "TID32_CARTESIAN_FS4_GT_TX_OOC_STATUS=$status"
