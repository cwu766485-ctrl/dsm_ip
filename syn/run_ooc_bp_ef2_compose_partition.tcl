# Build one production bp_ef2_map_compose_pipe specialization as an OOC DCP.
# Args: <8|16|32> <part> <target_mhz> <out_dir>
set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
if {[llength $argv] != 4} { error "usage: <8|16|32> <part> <target_mhz> <out_dir>" }
set kind [lindex $argv 0]
set part [lindex $argv 1]
set target_mhz [expr {double([lindex $argv 2])}]
set out_dir [file normalize [lindex $argv 3]]
array set spec {
  8  {5 5 9 4 4}
  16 {9 9 17 8 8}
  32 {17 17 34 16 16}
}
if {![info exists spec($kind)]} { error "kind must be 8, 16, or 32" }
lassign $spec($kind) lreg rreg oreg lbits rbits
file mkdir $out_dir
cd $out_dir
create_project -in_memory -part $part
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_map_region_select.sv]
read_verilog -sv [file join $root rtl tx_bandpass_if bp_ef2_map_compose_pipe.sv]
read_verilog -sv [file join $root syn rtl bp_ef2_map_compose_pipe_partition_wrap.sv]
set_param general.maxThreads 1
set_param synth.maxThreads 1
set generics "ACC_W=28 L_REGIONS=$lreg R_REGIONS=$rreg OUT_REGIONS=$oreg L_BITS=$lbits R_BITS=$rbits"
synth_design -top bp_ef2_map_compose_pipe_partition_wrap -part $part -mode out_of_context \
  -flatten_hierarchy none -directive AreaOptimized_high -generic $generics
# A cell checkpoint, not a top-level checkpoint: it is structurally importable
# by `read_checkpoint -cell` in the temporal64 shell.
write_checkpoint -force -cell u_compose [file join $out_dir "compose${kind}_pipe.dcp"]
create_clock -name clk -period [expr {1000.0 / $target_mhz}] [get_ports clk]
set inputs [get_ports -quiet -filter {DIRECTION == IN && NAME != "clk" && NAME != "rst_n"}]
set outputs [get_ports -quiet -filter {DIRECTION == OUT}]
if {[llength $inputs] > 0} { set_input_delay 0.0 -clock clk $inputs }
if {[llength $outputs] > 0} { set_output_delay 0.0 -clock clk $outputs }
set_false_path -from [get_ports rst_n]
report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing.rpt]
set path [lindex [get_timing_paths -max_paths 1 -quiet] 0]
if {$path eq ""} { error "No timing path reported" }
set wns [get_property SLACK $path]
set fmax [expr {1000.0 / ((1000.0 / $target_mhz) - double($wns))}]
if {$wns >= 0.0} {
  set status PASS
} else {
  set status FAIL_TIMING
}
set fp [open [file join $out_dir summary.csv] w]
puts $fp "Part,Block,Target_MHz,Status,WNS_ns,Fmax_est_MHz"
puts $fp "$part,bp_ef2_map_compose_pipe_${kind},[format %.2f $target_mhz],$status,[format %.3f $wns],[format %.2f $fmax]"
close $fp
