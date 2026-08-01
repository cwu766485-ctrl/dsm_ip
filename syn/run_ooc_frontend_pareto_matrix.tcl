set script_dir [file dirname [file normalize [info script]]]
set ip_root [file normalize [file join $script_dir ".."]]

if {[info exists argv] && [llength $argv] >= 1} {
  set part [lindex $argv 0]
}
if {![info exists part]} {
  set part "xc7z020clg400-1"
}

set part_tag [string map {"-" "_" "." "_"} $part]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set out_root [file normalize [file join $script_dir "reports" "ooc_frontend_pareto_${part_tag}_${stamp}"]]
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
  [file join $ip_root rtl interp dsm_interp_fir_fixed.sv] \
  [file join $ip_root rtl interp dsm_interp_cic_direct.sv] \
  [file join $ip_root rtl interp dsm_interp_fir_polyphase.sv] \
  [file join $ip_root rtl interp dsm_interp_fir_i2_polyphase.sv] \
  [file join $ip_root rtl interp dsm_interp2_halfband.sv] \
  [file join $ip_root rtl interp dsm_interp_frontend.sv] \
  [file join $ip_root rtl dpd dpd_poly.v] \
  [file join $ip_root rtl dpd dpd_memory_poly.v] \
  [file join $ip_root rtl duc duc_fs4_merge.sv] \
  [file join $ip_root rtl duc duc_fs4_merge_signed.sv] \
  [file join $ip_root rtl duc duc_nco_mix_signed.v] \
  [file join $ip_root rtl ip dsm_ip_core.sv] \
  [file join $ip_root rtl top dsm_interp_ooc_top.sv] \
  [file join $ip_root rtl top dsm_core_ooc_top.sv] \
  [file join $ip_root rtl top dpd_memory_poly_ooc_top.sv] \
]

set summary_csv [file join $out_root "summary.csv"]
set fp [open $summary_csv "w"]
puts $fp "Part,Block,Variant,Status,LUT,FF,DSP,BRAM,WNS_ns,Fmax_est_MHz"

proc synth_one {part rtl_files out_root fp block variant top generics} {
  set run_dir [file join $out_root "${block}_${variant}"]
  file mkdir $run_dir
  puts "==== SYNTH OOC $block $variant ===="
  create_project -in_memory -part $part
  set status "PASS"
  set lut 0; set ff 0; set dsp 0; set bram 0; set wns "NA"; set fmax "NA"
  if {[catch {
    read_verilog -sv $rtl_files
    eval synth_design -top $top -part $part -mode out_of_context $generics
    create_clock -name clk -period 10.000 [get_ports clk]
    report_utilization -file [file join $run_dir utilization_synth.rpt]
    report_timing_summary -file [file join $run_dir timing_summary_synth.rpt]
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
    set bram [llength [get_cells -hier -filter {REF_NAME =~ RAMB*}]]
    set paths [get_timing_paths -max_paths 1 -quiet]
    if {[llength $paths] > 0} {
      set wns [format %.3f [get_property SLACK [lindex $paths 0]]]
      set fmax [format %.2f [expr {1000.0 / (10.0 - double($wns))}]]
      if {[expr {double($wns)}] < 0.0} { set status "FAIL_TIMING" }
    }
  }
  puts $fp "$part,$block,$variant,$status,$lut,$ff,$dsp,$bram,$wns,$fmax"
  flush $fp
  close_project
}

foreach impl {0 1 2 3} {
  synth_one $part $rtl_files $out_root $fp "interpolator" "I$impl" \
    dsm_interp_ooc_top [list -generic INTERP_IMPL=$impl]
}

foreach {alg name} {2 D0_EFDSM 1 D1_LPDSM2 3 D2_EFDSM2 4 D3_MASH11 5 D4_MASH111 9 D5_MB_EFDSM 10 D6_MB_EFDSM2} {
  synth_one $part $rtl_files $out_root $fp "dsm" $name dsm_core_ooc_top \
    [list -generic ALGORITHM=$alg]
}

synth_one $part $rtl_files $out_root $fp "dpd" "MemoryPoly5_4tap" \
  dpd_memory_poly_ooc_top {}

close $fp
puts "Frontend Pareto OOC summary: $summary_csv"
