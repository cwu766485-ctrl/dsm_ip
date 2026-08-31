# Full AXI-top synthesis and routed implementation for the four frozen
# interpolation/DSM finalists.  All cases use I0 (INTERP_IMPL=0), x32 mode,
# the complete AXI-Lite/control/Memory-Poly hardware and the Fs/4 DUC.

set script_dir [file dirname [file normalize [info script]]]
set ip_root [file normalize [file join $script_dir ".."]]

if {[info exists argv] && [llength $argv] >= 1} {
  set part [lindex $argv 0]
}
if {![info exists part]} {
  set part "xczu15eg-ffvb1156-1-i"
}

set part_tag [string map {"-" "_" "." "_"} $part]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set out_root [file normalize [file join $script_dir "reports" "finalists_axi_routed_${part_tag}_${stamp}"]]
file mkdir $out_root
# Keep Vivado's transient .Xil database inside this report directory.  The
# shared project-root cache may be locked by an unrelated GUI or earlier run.
cd $out_root

set rtl_files [list \
  [file join $ip_root rtl axis axis_skid_buffer.sv] \
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
  [file join $ip_root rtl dpd dpd_lut.v] \
  [file join $ip_root rtl dpd dpd_memory_poly.v] \
  [file join $ip_root rtl dpd dpd_observer.v] \
  [file join $ip_root rtl dpd dpd_seed_predictor.v] \
  [file join $ip_root rtl dpd dpd_frontend.v] \
  [file join $ip_root rtl duc duc_fs4_merge.sv] \
  [file join $ip_root rtl duc duc_fs4_merge_signed.sv] \
  [file join $ip_root rtl duc duc_nco_mix_signed.v] \
  [file join $ip_root rtl tx_bandpass_if bp_fs4_iq_mixer.sv] \
  [file join $ip_root rtl tx_bandpass_if dsm_core_bp_single.sv] \
  [file join $ip_root rtl tx_bandpass_if dsm_core_bp_ef2.sv] \
  [file join $ip_root rtl tx_bandpass_if tx_bp_if_top.sv] \
  [file join $ip_root rtl ip dsm_ip_core.sv] \
  [file join $ip_root rtl ip dsm_ip_top.v] \
  [file join $ip_root rtl axi dsm_ip_axi_read_mux.v] \
  [file join $ip_root rtl axi dsm_ip_axi_top.v] \
]

set cases [list \
  [list I0_D0_EFDSM 2 EFDSM_1bit] \
  [list I0_D1_LPDSM2 1 LPDSM2_1bit] \
  [list I0_D3_MASH11 4 MASH11_native_3bit] \
  [list I0_D5_MB_EFDSM 9 MB_EFDSM_4bit] \
]

set summary_csv [file join $out_root "summary.csv"]
set fp [open $summary_csv "w"]
puts $fp "Part,Case,Algorithm,AlgorithmName,InterpMode,InterpImpl,Clock_ns,Status,LUT,FF,DSP,BRAM,WNS_ns,Fmax_est_MHz"

proc utilization_count {report_file site_type} {
  set in [open $report_file r]
  set text [read $in]
  close $in
  set escaped_type [string map {" " "[ \\t]+"} $site_type]
  set pattern [format {\|[ \t]*%s[ \t]*\|[ \t]*([0-9]+)[ \t]*\|} $escaped_type]
  if {[regexp $pattern $text -> count]} {
    return $count
  }
  error "Cannot find utilization count for $site_type in $report_file"
}

foreach item $cases {
  lassign $item case_name algorithm algorithm_name
  set run_dir [file join $out_root $case_name]
  file mkdir $run_dir
  puts "==== Full AXI routed finalist $case_name ===="
  create_project -in_memory -part $part
  set status "PASS"
  set lut 0; set ff 0; set dsp 0; set bram 0; set wns "NA"; set fmax "NA"
  if {[catch {
    read_verilog -sv $rtl_files
    synth_design -top dsm_ip_axi_top -part $part -mode out_of_context \
      -generic ALGORITHM=$algorithm -generic INTERP_MODE=4 \
      -generic INTERP_IMPL=0 -generic DUC_MODE=0 \
      -generic ENABLE_DPD_MEMORY=1
    create_clock -name aclk -period 10.000 [get_ports aclk]
    set_false_path -from [get_ports -quiet {aresetn s_axi_* s_axis_*}]
    set_false_path -to [get_ports -quiet {s_axi_* s_axis_tready dsm_valid i_bit q_bit i_yout[*] q_yout[*] rf_valid rf_bit rf_signed[*] phase_acc_dbg[*]}]
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
    # Use the post-route report rather than primitive-name wildcards.  The
    # latter include mapped helper cells and overcount DSP/LUT resources.
    set utilization_report [file join $run_dir utilization.rpt]
    set lut [utilization_count $utilization_report "CLB LUTs"]
    set ff [utilization_count $utilization_report "CLB Registers"]
    set dsp [utilization_count $utilization_report "DSPs"]
    set bram [utilization_count $utilization_report "Block RAM Tile"]
    set paths [get_timing_paths -max_paths 1 -quiet]
    if {[llength $paths] > 0} {
      set wns [format %.3f [get_property SLACK [lindex $paths 0]]]
      set fmax [format %.2f [expr {1000.0 / (10.0 - double($wns))}]]
      if {[expr {double($wns)}] < 0.0} { set status "FAIL_TIMING" }
    }
  }
  puts $fp "$part,$case_name,$algorithm,$algorithm_name,4,0,10.000,$status,$lut,$ff,$dsp,$bram,$wns,$fmax"
  flush $fp
  close_project
}
close $fp
puts "Finalist full-AXI routed summary: $summary_csv"
