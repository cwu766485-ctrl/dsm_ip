set script_dir [file dirname [file normalize [info script]]]
set ip_root [file normalize [file join $script_dir ".."]]

if {[info exists argv] && [llength $argv] >= 1} {
  set part [lindex $argv 0]
}

if {![info exists part]} {
  set part "xc7z020clg400-1"
}

set part_tag [string map {"-" "_" "." "_"} $part]
set out_root [file normalize [file join $script_dir "reports" "ooc_${part_tag}_[clock format [clock seconds] -format %Y%m%d_%H%M%S]"]]
file mkdir $out_root

set rtl_files [list \
  [file join $ip_root rtl dsm singlebit dsm_core.sv] \
  [file join $ip_root rtl dsm singlebit dsm_core_dsm2.sv] \
  [file join $ip_root rtl dsm singlebit dsm_core_ef1.sv] \
  [file join $ip_root rtl dsm singlebit dsm_core_ef2.sv] \
  [file join $ip_root rtl dsm singlebit dsm_core_mash11.sv] \
  [file join $ip_root rtl dsm singlebit dsm_core_mash111.sv] \
  [file join $ip_root rtl dsm singlebit dsm_core_mash22.sv] \
  [file join $ip_root rtl dsm multibit dsm_core_multibit.sv] \
  [file join $ip_root rtl dsm multibit dsm_core_multibit_lp1.sv] \
  [file join $ip_root rtl dsm multibit dsm_core_multibit_lp2.sv] \
  [file join $ip_root rtl dsm multibit dsm_core_multibit_ef1.sv] \
  [file join $ip_root rtl dsm multibit dsm_core_multibit_ef2.sv] \
  [file join $ip_root rtl dsm multibit dsm_core_multibit_mash11.sv] \
  [file join $ip_root rtl dsm multibit dsm_core_multibit_mash111.sv] \
  [file join $ip_root rtl dsm multibit dsm_core_multibit_mash22.sv] \
  [file join $ip_root rtl duc duc_fs4_merge.sv] \
  [file join $ip_root rtl duc duc_fs4_merge_signed.sv] \
  [file join $ip_root syn rtl p0_ooc_tops.sv] \
]

set tops [list \
  p0_ooc_lp1 \
  p0_ooc_lp2 \
  p0_ooc_ef1 \
  p0_ooc_ef2 \
  p0_ooc_mash11 \
  p0_ooc_mash111 \
  p0_ooc_mash22 \
  p0_ooc_mb_lp1 \
  p0_ooc_mb_lp2 \
  p0_ooc_mb_ef1 \
  p0_ooc_mb_ef2 \
  p0_ooc_mb_mash11 \
  p0_ooc_mb_mash111 \
  p0_ooc_mb_mash22 \
]

set summary_csv [file join $out_root "summary_all.csv"]
set fp [open $summary_csv "w"]
puts $fp "Part,Top,Status,LUT,FF,DSP,WNS_ns,Fmax_est_MHz"

foreach top $tops {
  puts "==== OOC $top ===="
  set run_dir [file join $out_root $top]
  file mkdir $run_dir

  create_project -in_memory -part $part
  set_msg_config -id {Synth 8-3332} -new_severity {WARNING}
  read_verilog -sv $rtl_files
  read_xdc [file join $ip_root syn constraints p0_ooc_100mhz.xdc]

  set status "PASS"
  set lut 0
  set ff 0
  set dsp 0
  set wns "NA"
  set fmax "NA"

  if {[catch {
    synth_design -top $top -part $part -mode out_of_context
    opt_design
    place_design
    phys_opt_design
    route_design
    phys_opt_design

    report_utilization -file [file join $run_dir utilization.rpt]
    report_timing_summary -file [file join $run_dir timing_summary.rpt]
    report_power -file [file join $run_dir power.rpt]
    report_drc -file [file join $run_dir drc.rpt]
    report_methodology -file [file join $run_dir methodology.rpt]
  } err]} {
    set status "FAIL"
    set logfp [open [file join $run_dir error.log] "w"]
    puts $logfp $err
    close $logfp
  }

  if {$status eq "PASS"} {
    set lut [llength [get_cells -hier -filter {REF_NAME =~ LUT*}]]
    set ff [llength [get_cells -hier -filter {REF_NAME =~ FD* || REF_NAME =~ LD*}]]
    set dsp [llength [get_cells -hier -filter {REF_NAME =~ DSP*}]]
    set paths [get_timing_paths -max_paths 1 -quiet]
    if {[llength $paths] > 0} {
      set wns [format %.3f [get_property SLACK [lindex $paths 0]]]
      set fmax [format %.2f [expr {1000.0 / (10.0 - double($wns))}]]
      if {[expr {double($wns)}] < 0.0} {
        set status "FAIL_TIMING"
      }
    }
  }

  puts $fp "$part,$top,$status,$lut,$ff,$dsp,$wns,$fmax"
  flush $fp
  close_project
}

close $fp
puts "OOC summary: $summary_csv"
