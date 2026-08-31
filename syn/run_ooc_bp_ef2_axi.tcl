# OOC synthesis of the complete DPD -> interpolation -> full-precision IF
# mixer -> one-bit BP EFDSM2 AXI transmitter SKU.
#
# Optional Tcl arguments:
#   1: FPGA part
#   2: target clock frequency in MHz

set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
set part [expr {[llength $argv] >= 1 ? [lindex $argv 0] : "xczu15eg-ffvb1156-2-i"}]
set target_mhz [expr {[llength $argv] >= 2 ? double([lindex $argv 1]) : 100.0}]
if {$target_mhz <= 0.0} {
  error "Target clock frequency must be positive: $target_mhz"
}
set target_period_ns [expr {1000.0 / $target_mhz}]
set target_label [string map {"." "p"} [format %.2f $target_mhz]]
set tag [string map {"-" "_" "." "_"} $part]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set out_dir [file normalize [file join $script_dir reports "bp_ef2_axi_ooc_${tag}_${target_label}mhz_${stamp}"]]
file mkdir $out_dir
cd $out_dir
puts "BP EFDSM2 AXI OOC: part=$part target_mhz=$target_mhz out_dir=$out_dir"

set rtl [list \
  [file join $root rtl axis axis_skid_buffer.sv] \
  [file join $root rtl dsm singlebit dsm_core.sv] \
  [file join $root rtl dsm singlebit dsm_core_dsm2.sv] \
  [file join $root rtl dsm singlebit dsm_core_ef1.sv] \
  [file join $root rtl dsm singlebit dsm_core_ef2.sv] \
  [file join $root rtl dsm singlebit dsm_core_mash11.sv] \
  [file join $root rtl dsm singlebit dsm_core_mash111.sv] \
  [file join $root rtl dsm singlebit dsm_core_mash22.sv] \
  [file join $root rtl dsm multibit dsm_core_multibit.sv] \
  [file join $root rtl dsm multibit dsm_core_multibit_lp1.sv] \
  [file join $root rtl dsm multibit dsm_core_multibit_lp2.sv] \
  [file join $root rtl dsm multibit dsm_core_multibit_ef1.sv] \
  [file join $root rtl dsm multibit dsm_core_multibit_ef2.sv] \
  [file join $root rtl dsm multibit dsm_core_multibit_mash11.sv] \
  [file join $root rtl dsm multibit dsm_core_multibit_mash111.sv] \
  [file join $root rtl dsm multibit dsm_core_multibit_mash22.sv] \
  [file join $root rtl interp dsm_interp_fir_fixed.sv] \
  [file join $root rtl interp dsm_interp_cic_direct.sv] \
  [file join $root rtl interp dsm_interp_fir_polyphase.sv] \
  [file join $root rtl interp dsm_interp_fir_i2_polyphase.sv] \
  [file join $root rtl interp dsm_interp2_halfband.sv] \
  [file join $root rtl interp dsm_interp_frontend.sv] \
  [file join $root rtl dpd dpd_poly.v] \
  [file join $root rtl dpd dpd_lut.v] \
  [file join $root rtl dpd dpd_memory_poly.v] \
  [file join $root rtl dpd dpd_observer.v] \
  [file join $root rtl dpd dpd_seed_predictor.v] \
  [file join $root rtl dpd dpd_frontend.v] \
  [file join $root rtl duc duc_fs4_merge.sv] \
  [file join $root rtl duc duc_fs4_merge_signed.sv] \
  [file join $root rtl duc duc_nco_mix_signed.v] \
  [file join $root rtl tx_bandpass_if bp_fs4_iq_mixer.sv] \
  [file join $root rtl tx_bandpass_if dsm_core_bp_single.sv] \
  [file join $root rtl tx_bandpass_if dsm_core_bp_ef2.sv] \
  [file join $root rtl tx_bandpass_if tx_bp_if_top.sv] \
  [file join $root rtl ip dsm_ip_core.sv] \
  [file join $root rtl ip dsm_ip_top.v] \
  [file join $root rtl axi dsm_ip_axi_read_mux.v] \
  [file join $root rtl axi dsm_ip_axi_top.v] \
]

create_project -in_memory -part $part
read_verilog -sv $rtl
# Vivado 2024.1 on this host hangs after launching the multi-process synthesis
# helper. Keep this OOC run single-threaded so the implementation evidence is
# reproducible from the GUI Tcl console as well as batch mode.
set_param general.maxThreads 1
synth_design -top dsm_ip_axi_top -part $part -mode out_of_context \
  -generic ALGORITHM=3 -generic DUC_MODE=3 -generic INTERP_MODE=4 \
  -generic INTERP_IMPL=0 -generic DPD_POLY_ORDER=5 -generic DPD_MP_MAX_TAPS=4 \
  -generic ENABLE_DPD_POLY=0 -generic ENABLE_DPD_LUT=0 -generic ENABLE_DPD_MEMORY=1
create_clock -name aclk -period $target_period_ns [get_ports aclk]
# OOC timing must cover internal register-to-register paths. Primary I/O timing
# belongs to the parent integration, so suppress only complete input/output paths
# rather than wildcarding mixed-direction interface names.
set nonclock_inputs [get_ports -quiet -filter {DIRECTION == IN && NAME != aclk}]
set outputs [get_ports -quiet -filter {DIRECTION == OUT}]
if {[llength $nonclock_inputs] > 0} { set_false_path -from $nonclock_inputs }
if {[llength $outputs] > 0} { set_false_path -to $outputs }
report_utilization -file [file join $out_dir utilization_synth.rpt]
report_timing_summary -file [file join $out_dir timing_summary_synth.rpt]
if {![file exists [file join $out_dir utilization_synth.rpt]] ||
    ![file exists [file join $out_dir timing_summary_synth.rpt]]} {
  error "BP EFDSM2 AXI OOC did not create synthesis reports"
}
set paths [get_timing_paths -max_paths 1]
set wns [get_property SLACK [lindex $paths 0]]
set fmax [expr {1000.0 / ($target_period_ns - double($wns))}]
set status "PASS"
if {$wns < 0.0} { set status "FAIL_TIMING" }
set fp [open [file join $out_dir summary.csv] w]
puts $fp "Part,SKU,Algorithm,DucMode,InterpMode,Target_MHz,Status,WNS_ns,Fmax_est_MHz"
puts $fp "$part,DPD_Interp_BP_EFDSM2,3,3,4,[format %.2f $target_mhz],$status,[format %.3f $wns],[format %.2f $fmax]"
close $fp
puts "BP EFDSM2 AXI OOC summary: [file join $out_dir summary.csv]"
if {$wns < 0.0} { error "BP EFDSM2 AXI SKU fails [format %.2f $target_mhz] MHz: WNS=$wns" }
