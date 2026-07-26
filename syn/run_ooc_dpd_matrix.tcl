# ZU15EG fixed-function DPD OOC matrix.
set part xczu15eg-ffvb1156-1-i
set root [file normalize [file join [file dirname [info script]] ..]]
set out_dir [file join $root reports dpd_ooc_zu15eg]
file mkdir $out_dir
set rtl [file join $root rtl]
set source_files [list \
  [file join $rtl dpd dpd_poly.v] \
  [file join $rtl dpd dpd_lut.v] \
  [file join $rtl dpd dpd_memory_poly.v] \
  [file join $root syn rtl dpd_ooc_tops.sv]]

set configs [list \
  [list bypass dpd_bypass_ooc_top ""] \
  [list poly3 dpd_poly_ooc_top "POLY_ORDER=3"] \
  [list poly5 dpd_poly_ooc_top "POLY_ORDER=5"] \
  [list poly7 dpd_poly_ooc_top "POLY_ORDER=7"] \
  [list lut dpd_lut_ooc_top ""] \
  [list mp1 dpd_memory_poly_ooc_top "MAX_TAPS=1"] \
  [list mp2 dpd_memory_poly_ooc_top "MAX_TAPS=2"] \
  [list mp4 dpd_memory_poly_ooc_top "MAX_TAPS=4"] \
  [list mp6 dpd_memory_poly_ooc_top "MAX_TAPS=6"]]
set summary [open [file join $out_dir summary.csv] w]
puts $summary "config,top,generic,lut,ff,dsp,bram,wns_ns,fmax_est_mhz,dynamic_power_w,total_power_w"
foreach item $configs {
  lassign $item name top generic
  set run_dir [file join $out_dir $name]
  file mkdir $run_dir
  create_project -in_memory -part $part
  read_verilog -sv $source_files
  if {$generic eq ""} {
    synth_design -top $top -part $part -mode out_of_context
  } else {
    synth_design -top $top -part $part -mode out_of_context -generic $generic
  }
  create_clock -period 10.000 -name aclk [get_ports clk]
  set util_report [report_utilization -return_string]
  set timing_report [report_timing_summary -delay_type max -max_paths 10 -return_string]
  set util_fh [open [file join $run_dir utilization.rpt] w]
  puts $util_fh $util_report
  close $util_fh
  set timing_fh [open [file join $run_dir timing.rpt] w]
  puts $timing_fh $timing_report
  close $timing_fh
  set power_report [report_power -return_string]
  set power_fh [open [file join $run_dir power.rpt] w]
  puts $power_fh $power_report
  close $power_fh
  set lut "NA"
  set ff "NA"
  set dsp "NA"
  set bram "NA"
  regexp {(?m)^\| CLB LUTs\*?\s*\|\s*([0-9]+)} $util_report -> lut
  regexp {(?m)^\| CLB Registers\s*\|\s*([0-9]+)} $util_report -> ff
  regexp {(?m)^\| DSPs\s*\|\s*([0-9]+)} $util_report -> dsp
  regexp {(?m)^\| Block RAM Tile\s*\|\s*([0-9.]+)} $util_report -> bram
  set dynamic_power "NA"
  set total_power "NA"
  regexp {(?m)^\| Dynamic \(W\)\s*\|\s*([0-9.]+)} $power_report -> dynamic_power
  regexp {(?m)^\| Total On-Chip Power \(W\)\s*\|\s*([0-9.]+)} $power_report -> total_power
  set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
  if {$wns eq ""} { set wns "NA"; set fmax "NA" } else { set fmax [expr {1000.0 / (10.0 - $wns)}] }
  puts $summary "$name,$top,$generic,$lut,$ff,$dsp,$bram,$wns,$fmax,$dynamic_power,$total_power"
  close_project
}
close $summary
puts "DPD OOC matrix complete: [file join $out_dir summary.csv]"
