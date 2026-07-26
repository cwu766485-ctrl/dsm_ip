# ZU15EG OOC PPA matrix for compile-time DPD product configurations.
# This script deliberately uses the feature gates in dpd_frontend rather than
# the runtime-select development configuration.

set part xczu15eg-ffvb1156-2-i
if {[llength $argv] > 0} {
  set part [lindex $argv 0]
}
set requested_config ""
if {[llength $argv] > 1} {
  set requested_config [lindex $argv 1]
}

set root [file normalize [file join [file dirname [info script]] ..]]
set out_dir [file join $root syn reports dpd_feature_ooc_zu15eg]
file mkdir $out_dir

# Keep the matrix deterministic and avoid parallel synthesis worker setup in
# constrained Windows installations. This affects run time only, not results.
set_param general.maxThreads 1
set_param synth.maxThreads 1
set rtl [file join $root rtl]
set source_files [list \
  [file join $rtl dpd dpd_poly.v] \
  [file join $rtl dpd dpd_lut.v] \
  [file join $rtl dpd dpd_memory_poly.v] \
  [file join $rtl dpd dpd_frontend.v] \
  [file join $root syn rtl dpd_frontend_ooc_top.sv]]

set configs [list \
  [list bypass "ENABLE_DPD_POLY=0 ENABLE_DPD_LUT=0 ENABLE_DPD_MEMORY=0 DPD_POLY_ORDER=5 DPD_MP_MAX_TAPS=1"] \
  [list poly3 "ENABLE_DPD_POLY=1 ENABLE_DPD_LUT=0 ENABLE_DPD_MEMORY=0 DPD_POLY_ORDER=3 DPD_MP_MAX_TAPS=1"] \
  [list poly5 "ENABLE_DPD_POLY=1 ENABLE_DPD_LUT=0 ENABLE_DPD_MEMORY=0 DPD_POLY_ORDER=5 DPD_MP_MAX_TAPS=1"] \
  [list poly7 "ENABLE_DPD_POLY=1 ENABLE_DPD_LUT=0 ENABLE_DPD_MEMORY=0 DPD_POLY_ORDER=7 DPD_MP_MAX_TAPS=1"] \
  [list lut "ENABLE_DPD_POLY=0 ENABLE_DPD_LUT=1 ENABLE_DPD_MEMORY=0 DPD_POLY_ORDER=5 DPD_MP_MAX_TAPS=1"] \
  [list memory1 "ENABLE_DPD_POLY=0 ENABLE_DPD_LUT=0 ENABLE_DPD_MEMORY=1 DPD_POLY_ORDER=5 DPD_MP_MAX_TAPS=1"] \
  [list memory2 "ENABLE_DPD_POLY=0 ENABLE_DPD_LUT=0 ENABLE_DPD_MEMORY=1 DPD_POLY_ORDER=5 DPD_MP_MAX_TAPS=2"] \
  [list memory4 "ENABLE_DPD_POLY=0 ENABLE_DPD_LUT=0 ENABLE_DPD_MEMORY=1 DPD_POLY_ORDER=5 DPD_MP_MAX_TAPS=4"] \
  [list memory6 "ENABLE_DPD_POLY=0 ENABLE_DPD_LUT=0 ENABLE_DPD_MEMORY=1 DPD_POLY_ORDER=5 DPD_MP_MAX_TAPS=6"] \
  [list development_all "ENABLE_DPD_POLY=1 ENABLE_DPD_LUT=1 ENABLE_DPD_MEMORY=1 DPD_POLY_ORDER=5 DPD_MP_MAX_TAPS=4 RUNTIME_MODE_INPUT=1"]]

set summary_path [file join $out_dir summary.csv]
set retained_rows [list]
if {$requested_config ne "" && [file exists $summary_path]} {
  set previous [open $summary_path r]
  gets $previous ignored_header
  while {[gets $previous row] >= 0} {
    if {![string match "${requested_config},*" $row]} {
      lappend retained_rows $row
    }
  }
  close $previous
}
set summary [open $summary_path w]
puts $summary "config,part,generic,lut,ff,dsp,bram,wns_ns,fmax_est_mhz,dynamic_power_w,total_power_w"
foreach row $retained_rows {
  puts $summary $row
}

foreach item $configs {
  lassign $item name generic
  if {$requested_config ne "" && $name ne $requested_config} {
    continue
  }
  set run_dir [file join $out_dir $name]
  file mkdir $run_dir

  create_project -in_memory -part $part
  read_verilog -sv $source_files
  synth_design -top dpd_frontend_ooc_top -part $part -mode out_of_context -generic $generic
  create_clock -period 10.000 -name aclk [get_ports clk]

  set util_report [report_utilization -return_string]
  set timing_report [report_timing_summary -delay_type max -max_paths 10 -return_string]
  set power_report [report_power -return_string]
  foreach {filename report} [list utilization.rpt $util_report timing.rpt $timing_report power.rpt $power_report] {
    set fh [open [file join $run_dir $filename] w]
    puts $fh $report
    close $fh
  }

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
  if {$wns eq ""} {
    set wns "NA"
    set fmax "NA"
  } else {
    set fmax [format %.3f [expr {1000.0 / (10.0 - $wns)}]]
  }
  puts $summary "$name,$part,\"$generic\",$lut,$ff,$dsp,$bram,$wns,$fmax,$dynamic_power,$total_power"
  flush $summary
  close_project
}

close $summary
puts "DPD feature-gate OOC matrix complete: [file join $out_dir summary.csv]"
