# Standalone EF2 architecture study. This is intentionally separate from the
# product wrapper so E0/E1 timing and resource data cannot be mistaken for
# four-plane product signoff.
if {[llength $argv] != 3} {
  error "usage: <part> <out_dir> <pair_lookahead:0|1>"
}
set part [lindex $argv 0]
set out_dir [file normalize [lindex $argv 1]]
set pair [lindex $argv 2]
if {$pair ni {0 1}} { error "pair_lookahead must be 0 or 1" }
if {![info exists ::env(XILINX_VIVADO)]} { error "XILINX_VIVADO is required" }
set repo [file normalize [file join [file dirname [file normalize [info script]]] ..]]
file mkdir $out_dir
cd $out_dir
create_project -in_memory -part $part
read_verilog -sv [file join $repo rtl gt gt_tx_user_bridge.sv]
read_verilog -sv [file join $repo rtl gt gt_tx_raw64_boundary.sv]
read_verilog -sv [file join $repo rtl tx_bandpass_if tid32_cartesian_ef2_fs4_gt_tx.sv]
set_param general.maxThreads 1
set_param synth.maxThreads 1
catch {set_param synth.enableParallelSynthesis false}
catch {set_param synth.parallelSynthesis false}
synth_design -top tid32_cartesian_ef2_fs4_gt_tx -part $part -mode out_of_context \
  -flatten_hierarchy none -directive AreaOptimized_high \
  -generic "W=16 CHANNELS=32 PAIR_LOOKAHEAD=$pair"
create_clock -name clk -period 4.571 [get_ports clk]
report_utilization -file [file join $out_dir synth_utilization.rpt]
report_timing_summary -max_paths 20 -report_unconstrained -file [file join $out_dir synth_timing_summary.rpt]
report_timing -max_paths 20 -file [file join $out_dir synth_timing_paths.rpt]
check_timing -verbose -file [file join $out_dir synth_check_timing.rpt]
write_checkpoint -force [file join $out_dir synthesized.dcp]
set setup [get_timing_paths -delay_type max -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
set wns NA
set whs NA
if {[llength $setup]} { set wns [get_property SLACK [lindex $setup 0]] }
if {[llength $hold]} { set whs [get_property SLACK [lindex $hold 0]] }
set f [open [file join $out_dir summary.csv] w]
puts $f "Part,Top,PAIR_LOOKAHEAD,Clock_MHz,Synthesis_WNS_ns,Synthesis_WHS_ns"
puts $f "$part,tid32_cartesian_ef2_fs4_gt_tx,$pair,218.75,$wns,$whs"
close $f
puts "THERMO5_EF2_VARIANT_SYNTH_PASS pair=$pair out=$out_dir wns=$wns whs=$whs"
exit 0
