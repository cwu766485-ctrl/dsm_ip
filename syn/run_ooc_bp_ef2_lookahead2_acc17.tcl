# OOC synthesis of the compact two-sample look-ahead temporal64 candidate.
set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
set part [expr {[llength $argv] >= 1 ? [lindex $argv 0] : "xczu15eg-ffvb1156-2-i"}]
set target_mhz [expr {[llength $argv] >= 2 ? double([lindex $argv 1]) : 218.75}]
if {$target_mhz <= 0.0} { error "Target frequency must be positive" }
set period_ns [expr {1000.0 / $target_mhz}]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set label [string map {"." "p"} [format %.2f $target_mhz]]
set part_label [string map {"-" "_" "." "_"} $part]
set out_dir [file normalize [file join $script_dir reports "bp_ef2_lookahead2_acc17_ooc_${part_label}_${label}mhz_${stamp}"]]
file mkdir $out_dir
cd $out_dir

create_project -in_memory -part $part
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_lookahead2_comb.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_polyphase2_lookahead2_acc17.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_lookahead2_acc17.sv]
set_param general.maxThreads 1
set_param synth.maxThreads 1
synth_design -top bp_ef2_lookahead2_acc17 -part $part -mode out_of_context

create_clock -name clk -period $period_ns [get_ports clk]
set data_inputs [get_ports -quiet {enable x_vec[*]}]
set data_outputs [get_ports -quiet {y_vec[*] y_signed_vec[*] out_valid v_state[*]}]
if {[llength $data_inputs] > 0} { set_input_delay 0.0 -clock clk $data_inputs }
if {[llength $data_outputs] > 0} { set_output_delay 0.0 -clock clk $data_outputs }
set reset_port [get_ports -quiet rst_n]
if {[llength $reset_port] > 0} { set_false_path -from $reset_port }

report_utilization -file [file join $out_dir utilization_synth.rpt]
report_timing_summary -file [file join $out_dir timing_summary_synth.rpt]
set paths [get_timing_paths -max_paths 1 -quiet]
if {[llength $paths] == 0} { error "No timing path reported" }
set wns [get_property SLACK [lindex $paths 0]]
set fmax [expr {1000.0 / ($period_ns - double($wns))}]
set status [expr {$wns >= 0.0 ? "PASS" : "FAIL_TIMING"}]

set fp [open [file join $out_dir summary.csv] w]
puts $fp "Part,Block,Lanes,Target_MHz,Status,WNS_ns,Fmax_est_MHz,II,Lookahead_Group,ACC_W"
puts $fp "$part,bp_ef2_lookahead2_acc17,64,[format %.2f $target_mhz],$status,[format %.3f $wns],[format %.2f $fmax],1,2,17"
close $fp
puts "BP EFDSM2 lookahead2_acc17 OOC summary: [file join $out_dir summary.csv]"
if {$wns < 0.0} { puts "BP_EF2_LOOKAHEAD2_ACC17_STATUS=FAIL_TIMING" } else { puts "BP_EF2_LOOKAHEAD2_ACC17_STATUS=PASS" }
