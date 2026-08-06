set script_dir [file dirname [file normalize [info script]]]
set ip_root [file normalize [file join $script_dir ".."]]
set part [expr {[llength $argv] >= 1 ? [lindex $argv 0] : "xczu15eg-ffvb1156-1-i"}]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set out_dir [file normalize [file join $script_dir reports "axi_v11_${stamp}"]]
file mkdir $out_dir

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
  [file join $ip_root rtl axi dsm_ip_axi_top.v] \
]

create_project -in_memory -part $part
read_verilog -sv $rtl_files
synth_design -top dsm_ip_axi_top -part $part -mode out_of_context \
  -generic ALGORITHM=2 -generic INTERP_MODE=0 -generic DUC_MODE=0
create_clock -name aclk -period 10.000 [get_ports aclk]
set_false_path -from [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set_false_path -to [get_ports -filter {DIRECTION == OUT}]

set utilization_report [report_utilization -return_string]
set utilization_fp [open [file join $out_dir utilization_synth.rpt] w]
puts $utilization_fp $utilization_report
close $utilization_fp
report_timing_summary -file [file join $out_dir timing_summary_synth.rpt]
if {![regexp {\|\s*CLB LUTs\*?\s*\|\s*([0-9]+)} $utilization_report unused lut]} {
  error "Unable to extract CLB LUT utilization"
}
if {![regexp {\|\s*CLB Registers\s*\|\s*([0-9]+)} $utilization_report unused ff]} {
  error "Unable to extract CLB register utilization"
}
if {![regexp {\|\s*DSPs\s*\|\s*([0-9]+)} $utilization_report unused dsp]} {
  error "Unable to extract DSP utilization"
}
set wns [get_property SLACK [lindex [get_timing_paths -max_paths 1] 0]]
set fp [open [file join $out_dir summary.csv] w]
puts $fp "Part,Top,Algorithm,InterpMode,LUT,FF,DSP,WNS_ns"
puts $fp "$part,dsm_ip_axi_top,2,0,$lut,$ff,$dsp,[format %.3f $wns]"
close $fp
puts "DSM IP AXI v1.1 OOC summary: [file join $out_dir summary.csv]"
if {$wns < 0.0} { error "DSM IP AXI v1.1 fails 100 MHz timing: WNS=$wns" }
