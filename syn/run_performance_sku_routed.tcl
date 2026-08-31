# Routed OOC implementation for the frozen 100 MHz Performance SKU.
#
# This is a complete implementation of dsm_ip_axi_top, not a board bitstream:
# board XDC, pins, PS configuration, and DMA integration remain board-specific.

set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
set part [expr {[llength $argv] >= 1 ? [lindex $argv 0] : "xczu15eg-ffvb1156-2-i"}]
set target_mhz [expr {[llength $argv] >= 2 ? double([lindex $argv 1]) : 100.0}]
if {$target_mhz <= 0.0} { error "Target clock frequency must be positive: $target_mhz" }

set period_ns [expr {1000.0 / $target_mhz}]
set target_label [string map {"." "p"} [format %.2f $target_mhz]]
set part_tag [string map {"-" "_" "." "_"} $part]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set out_dir [file normalize [file join $script_dir reports "performance_sku_routed_${part_tag}_${target_label}mhz_${stamp}"]]
file mkdir $out_dir
cd $out_dir

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
foreach source_file $rtl {
  if {![file exists $source_file]} { error "Missing RTL source: $source_file" }
}

create_project -in_memory -part $part
read_verilog -sv $rtl
set_param general.maxThreads 1
synth_design -top dsm_ip_axi_top -part $part -mode out_of_context \
  -generic ALGORITHM=3 -generic DUC_MODE=3 -generic INTERP_MODE=4 \
  -generic INTERP_IMPL=0 -generic DPD_POLY_ORDER=5 -generic DPD_MP_MAX_TAPS=4 \
  -generic ENABLE_DPD_POLY=0 -generic ENABLE_DPD_LUT=0 -generic ENABLE_DPD_MEMORY=1

create_clock -name aclk -period $period_ns [get_ports aclk]
set nonclock_inputs [get_ports -quiet -filter {DIRECTION == IN && NAME != aclk}]
set outputs [get_ports -quiet -filter {DIRECTION == OUT}]
if {[llength $nonclock_inputs] > 0} { set_false_path -from $nonclock_inputs }
if {[llength $outputs] > 0} { set_false_path -to $outputs }

opt_design
place_design
phys_opt_design
route_design
phys_opt_design

report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -delay_type max -max_paths 20 -file [file join $out_dir timing_summary.rpt]
report_power -file [file join $out_dir power.rpt]
report_drc -file [file join $out_dir drc.rpt]
report_methodology -file [file join $out_dir methodology.rpt]

set paths [get_timing_paths -delay_type max -max_paths 1 -quiet]
if {[llength $paths] == 0} { error "No maximum-delay path reported after routing." }
set wns [get_property SLACK [lindex $paths 0]]
set fmax [expr {1000.0 / ($period_ns - double($wns))}]
set status "PASS"
if {$wns < 0.0} { set status "FAIL_TIMING" }

set summary [open [file join $out_dir summary.csv] w]
puts $summary "Part,SKU,Algorithm,DucMode,InterpMode,Target_MHz,Status,WNS_ns,Fmax_est_MHz"
puts $summary "$part,MemoryPoly5_4tap_BP_EFDSM2,3,3,4,[format %.2f $target_mhz],$status,[format %.3f $wns],[format %.2f $fmax]"
close $summary
puts "Performance SKU routed summary: [file join $out_dir summary.csv]"
if {$wns < 0.0} { error "Performance SKU fails [format %.2f $target_mhz] MHz after routing: WNS=$wns" }
