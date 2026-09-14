# Stage-by-stage OOC synthesis for the exact temporal64 state-map architecture.
set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
set part [expr {[llength $argv] >= 1 ? [lindex $argv 0] : "xczu15eg-ffvb1156-2-i"}]
set target_mhz [expr {[llength $argv] >= 2 ? double([lindex $argv 1]) : 218.75}]
set out_root [expr {[llength $argv] >= 3 ? [file normalize [lindex $argv 2]] : [file join $script_dir reports]}]
if {$target_mhz <= 0.0} { error "Target frequency must be positive" }
set period_ns [expr {1000.0 / $target_mhz}]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set label [string map {"." "p"} [format %.2f $target_mhz]]
set part_label [string map {"-" "_" "." "_"} $part]
set out_dir [file normalize [file join $out_root "bp_ef2_state_map_stages_ooc_${part_label}_${label}mhz_${stamp}"]]
file mkdir $out_dir

proc run_stage {top part period_ns out_dir} {
  create_project -in_memory -part $part
  read_verilog -sv $::map1_src
  read_verilog -sv $::leaf_src
  read_verilog -sv $::compose_src
  read_verilog -sv $::selector_src
  read_verilog -sv $::harness_src
  set_param general.maxThreads 1
  set_param synth.maxThreads 1
  synth_design -top $top -part $part -mode out_of_context -flatten_hierarchy none -directive AreaOptimized_high
  # Keep a reusable synthesized boundary for top-level assembly.  Reports are
  # still generated below from the in-memory design, while a later Vivado
  # process can open this DCP without re-elaborating the wide map payload.
  write_checkpoint -force [file join $out_dir "${top}_synthesized.dcp"]
  write_verilog -force -mode synth_stub [file join $out_dir "${top}_synth_stub.v"]
  create_clock -name clk -period $period_ns [get_ports clk]
  set inputs [get_ports -quiet -filter {DIRECTION == IN && NAME != "clk"}]
  set outputs [get_ports -quiet -filter {DIRECTION == OUT}]
  if {[llength $inputs] > 0} { set_input_delay 0.0 -clock clk $inputs }
  if {[llength $outputs] > 0} { set_output_delay 0.0 -clock clk $outputs }
  report_utilization -file [file join $out_dir "${top}_utilization.rpt"]
  report_timing_summary -file [file join $out_dir "${top}_timing.rpt"]
  set paths [get_timing_paths -max_paths 1 -quiet]
  if {[llength $paths] == 0} { error "No timing path for $top" }
  set wns [get_property SLACK [lindex $paths 0]]
  set fmax [expr {1000.0 / ($period_ns - double($wns))}]
  close_design
  return [list $wns $fmax]
}

set map1_src [file join $root rtl tx_bandpass_if bp_ef2_phase_map1.sv]
set leaf_src [file join $root rtl tx_bandpass_if bp_ef2_phase_map4.sv]
set compose_src [file join $root rtl tx_bandpass_if bp_ef2_map_compose.sv]
set selector_src [file join $root rtl tx_bandpass_if bp_ef2_state_selector.sv]
set harness_src [file join $root syn rtl bp_ef2_state_map_ooc_tops.sv]
set stages {bp_ef2_state_map_leaf4_ooc bp_ef2_state_map_compose8_ooc bp_ef2_state_map_compose16_ooc bp_ef2_state_map_compose32_ooc bp_ef2_state_selector_ooc}
set fp [open [file join $out_dir summary.csv] w]
puts $fp "Part,Block,Target_MHz,Status,WNS_ns,Fmax_est_MHz"
foreach top $stages {
  puts "STATE_MAP_OOC_STAGE=$top"
  if {[catch {run_stage $top $part $period_ns $out_dir} result]} {
    puts $fp "$part,$top,[format %.2f $target_mhz],ERROR,,"
    close $fp
    error "OOC stage failed: $top: $result"
  }
  lassign $result wns fmax
  set status [expr {$wns >= 0.0 ? "PASS" : "FAIL_TIMING"}]
  puts $fp "$part,$top,[format %.2f $target_mhz],$status,[format %.3f $wns],[format %.2f $fmax]"
}
close $fp
puts "BP_EF2_STATE_MAP_STAGES_OOC_SUMMARY=[file join $out_dir summary.csv]"
