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
set out_root [file normalize [file join $script_dir "reports" "ooc_dsm_ip_axi_${part_tag}_${stamp}"]]
file mkdir $out_root

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
  [file join $ip_root rtl interp dsm_interp2_halfband.sv] \
  [file join $ip_root rtl interp dsm_interp_frontend.sv] \
  [file join $ip_root rtl dpd dpd_poly.v] \
  [file join $ip_root rtl dpd dpd_lut.v] \
  [file join $ip_root rtl dpd dpd_frontend.v] \
  [file join $ip_root rtl duc duc_fs4_merge.sv] \
  [file join $ip_root rtl duc duc_fs4_merge_signed.sv] \
  [file join $ip_root rtl duc duc_nco_mix_signed.v] \
  [file join $ip_root rtl ip dsm_ip_core.sv] \
  [file join $ip_root rtl ip dsm_ip_top.v] \
  [file join $ip_root rtl axi dsm_ip_axi_top.v] \
]

set alg_names [dict create \
  0 LPDSM_1b \
  1 LPDSM2_1b \
  2 EFDSM_1b \
  3 EFDSM2_1b \
  4 MASH11_native \
  5 MASH111_native \
  6 MASH22_native \
  7 LPDSM_multibit \
  8 LPDSM2_multibit \
  9 EFDSM_multibit \
  10 EFDSM2_multibit \
  11 MASH11_multibit \
  12 MASH111_multibit \
  13 MASH22_multibit \
]

set interp_names [dict create \
  0 bypass \
  1 x4_halfband \
  2 x8_halfband \
  3 x16_halfband \
  4 x32_hb_cic_equiv_comp_fir \
]

set summary_csv [file join $out_root "summary_all.csv"]
set fp [open $summary_csv "w"]
puts $fp "Part,Top,Algorithm,AlgorithmName,InterpMode,InterpName,DucMode,Status,LUT,FF,DSP,WNS_ns,Fmax_est_MHz"

for {set alg 0} {$alg <= 13} {incr alg} {
  for {set interp 0} {$interp <= 4} {incr interp} {
    set top_tag "dsm_ip_axi_alg${alg}_interp${interp}"
    puts "==== OOC $top_tag ===="
    set run_dir [file join $out_root $top_tag]
    file mkdir $run_dir

    create_project -in_memory -part $part
    set_msg_config -id {Synth 8-3332} -new_severity {WARNING}
    read_verilog -sv $rtl_files

    set status "PASS"
    set lut 0
    set ff 0
    set dsp 0
    set wns "NA"
    set fmax "NA"

    if {[catch {
      synth_design -top dsm_ip_axi_top -part $part -mode out_of_context \
        -generic ALGORITHM=$alg -generic INTERP_MODE=$interp -generic DUC_MODE=0
      create_clock -name aclk -period 10.000 [get_ports aclk]
      set_false_path -from [get_ports -quiet {aresetn s_axi_* s_axis_tdata[*] s_axis_tvalid}]
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

    puts $fp "$part,$top_tag,$alg,[dict get $alg_names $alg],$interp,[dict get $interp_names $interp],0,$status,$lut,$ff,$dsp,$wns,$fmax"
    flush $fp
    close_project
  }
}

close $fp
puts "DSM IP AXI OOC matrix summary: $summary_csv"
