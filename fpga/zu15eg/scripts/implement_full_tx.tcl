# Build a routed ZU15EG full-TX image with a fixed, reviewable configuration.
#
# Usage:
#   vivado -mode batch -source implement_full_tx.tcl -tclargs <project.xpr>

if {$argc != 1} {
  puts "Usage: implement_full_tx.tcl <vivado_project.xpr>"
  exit 1
}

set xpr [file normalize [lindex $argv 0]]
if {![file exists $xpr]} {
  puts "ERROR: Vivado project not found: $xpr"
  exit 1
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".." ".."]]
set out_dir [file join $repo_root fpga zu15eg out full_tx]
file mkdir $out_dir

# The board build is intentionally a single-clock integration. The external
# observation receiver is optional and must cross an async boundary outside the
# DSM IP when its sampling clock is not pl_clk0.
set expected_clk_hz 100000000
set algorithm 3
set interp_mode 4
set dpd_poly_order 5
set dpd_mp_max_taps 4
# Performance SKU: fixed C1/C3/C5 memory polynomial with four taps.  Prune
# development-only polynomial and LUT branches from the production netlist.
set enable_dpd_poly 0
set enable_dpd_lut 0
set enable_dpd_memory 1

source [file join $repo_root ip package_vivado_ip.tcl]

open_project $xpr
set project_part [get_property PART [current_project]]
puts "Full-TX project part: $project_part"

set ip_repo [file normalize [file join $repo_root ip ip_repo]]
set_property ip_repo_paths [list $ip_repo] [current_project]
update_ip_catalog

set dsm_ips [get_ips -quiet *dsm_ip*]
if {[llength $dsm_ips] == 0} {
  error "No DSM IP instance found in the Vivado project."
}
foreach ip $dsm_ips {
  if {[catch {upgrade_ip $ip} msg]} {
    puts "WARNING: upgrade_ip $ip: $msg"
  }
}

set bds [get_files -quiet -filter {FILE_TYPE == "Block Designs"}]
if {[llength $bds] == 0} {
  error "No block design found in $xpr"
}
foreach bd $bds {
  open_bd_design $bd
  set ps [get_bd_cells -quiet zynq_ultra_ps_e_0]
  if {[llength $ps] == 0} {
    error "Missing zynq_ultra_ps_e_0; a PS PL clock is required."
  }
  if {[catch {
    set_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ 100 $ps
  } msg]} {
    error "Unable to set PS pl_clk0 to 100 MHz: $msg"
  }

  set reset_cells [get_bd_cells -quiet -filter {VLNV =~ "xilinx.com:ip:proc_sys_reset:*"}]
  if {[llength $reset_cells] == 0} {
    error "Missing Processor System Reset block; do not use raw PS reset in the full-TX datapath."
  }
  set reset_pin [get_bd_pins -quiet [lindex $reset_cells 0]/peripheral_aresetn]
  if {[llength $reset_pin] == 0} {
    error "Processor System Reset peripheral_aresetn is unavailable."
  }

  set dsm_cells [get_bd_cells -quiet *dsm_ip*]
  if {[llength $dsm_cells] == 0} {
    error "No dsm_ip block-design cell found."
  }
  set tx_clk_net ""
  foreach cell $dsm_cells {
    set_property -dict [list \
      CONFIG.C_S_AXI_ADDR_WIDTH {9} \
      CONFIG.ALGORITHM $algorithm \
      CONFIG.INTERP_MODE $interp_mode \
      CONFIG.DUC_MODE {3} \
      CONFIG.CLK_FREQ_HZ $expected_clk_hz \
      CONFIG.BB_SAMPLE_RATE_HZ {3125000} \
      CONFIG.SIGNAL_BW_HZ {2539062} \
      CONFIG.DPD_POLY_ORDER $dpd_poly_order \
      CONFIG.DPD_MP_MAX_TAPS $dpd_mp_max_taps \
      CONFIG.ENABLE_DPD_POLY $enable_dpd_poly \
      CONFIG.ENABLE_DPD_LUT $enable_dpd_lut \
      CONFIG.ENABLE_DPD_MEMORY $enable_dpd_memory \
    ] $cell

    set cell_clk_net [get_bd_nets -quiet -of_objects [get_bd_pins $cell/aclk]]
    set tx_rst_net [get_bd_nets -quiet -of_objects [get_bd_pins $cell/aresetn]]
    if {[llength $cell_clk_net] != 1 || [llength $tx_rst_net] != 1} {
      error "$cell must have exactly one connected clock and reset net."
    }
    if {$tx_clk_net eq ""} {
      set tx_clk_net $cell_clk_net
    } elseif {[lindex $cell_clk_net 0] ne [lindex $tx_clk_net 0]} {
      error "All dsm_ip instances must share one full-TX aclk."
    }
    if {[lindex $tx_rst_net 0] ne [lindex [get_bd_nets -quiet -of_objects $reset_pin] 0]} {
      error "$cell reset must be driven by Processor System Reset peripheral_aresetn."
    }
  }

  # Older local board designs predate the optional observation AXI-Stream
  # interface. Keep it deterministically idle until an explicitly clock-crossed
  # feedback receiver is integrated.
  set obs_data [get_bd_cells -quiet obs_tdata_zero]
  if {[llength $obs_data] == 0} {
    set obs_data [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant obs_tdata_zero]
    set_property -dict [list CONFIG.CONST_WIDTH {32} CONFIG.CONST_VAL {0}] $obs_data
  }
  set obs_control [get_bd_cells -quiet obs_control_zero]
  if {[llength $obs_control] == 0} {
    set obs_control [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant obs_control_zero]
    set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {0}] $obs_control
  }
  foreach cell $dsm_cells {
    foreach mapping [list \
      [list s_axis_obs_tdata $obs_data/dout] \
      [list s_axis_obs_tlast $obs_control/dout] \
      [list s_axis_obs_tuser $obs_control/dout] \
      [list s_axis_obs_tvalid $obs_control/dout]] {
      lassign $mapping port source_pin
      set target_pin [get_bd_pins -quiet $cell/$port]
      if {[llength $target_pin] > 0 && [llength [get_bd_nets -quiet -of_objects $target_pin]] == 0} {
        connect_bd_net [get_bd_pins $source_pin] $target_pin
      }
    }
  }

  set dma_cells [get_bd_cells -quiet *axi_dma*]
  foreach cell $dma_cells {
    foreach pin_name {s_axi_lite_aclk m_axi_mm2s_aclk} {
      set pin [get_bd_pins -quiet $cell/$pin_name]
      if {[llength $pin] > 0} {
        set net [get_bd_nets -quiet -of_objects $pin]
        if {[llength $net] != 1 || [lindex $net 0] ne [lindex $tx_clk_net 0]} {
          error "$cell/$pin_name must share the dsm_ip aclk; add an explicit clock converter otherwise."
        }
      }
    }
  }

  validate_bd_design
  save_bd_design
  generate_target all [get_files $bd]
}

update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {![string match -nocase "*complete*" [get_property STATUS [get_runs synth_1]]]} {
  error "synth_1 failed: [get_property STATUS [get_runs synth_1]]"
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
if {![string match -nocase "*complete*" $impl_status]} {
  error "impl_1 failed: $impl_status"
}

open_run impl_1
set timing_paths [get_timing_paths -delay_type max -max_paths 1]
if {[llength $timing_paths] == 0} {
  error "No maximum-delay timing path found after implementation."
}
set wns [get_property SLACK $timing_paths]
if {$wns < 0.0} {
  error "Full-TX routed timing failed: WNS=$wns ns"
}

report_clocks -file [file join $out_dir clocks.rpt]
report_timing_summary -delay_type max -max_paths 20 -file [file join $out_dir timing_summary.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
report_power -file [file join $out_dir power.rpt]
report_cdc -file [file join $out_dir cdc.rpt]
report_drc -file [file join $out_dir drc.rpt]

set impl_dir [get_property DIRECTORY [get_runs impl_1]]
set bit_file [file join $impl_dir top.bit]
if {![file exists $bit_file]} {
  error "write_bitstream completed without top.bit: $bit_file"
}
set xsa_file [file join $out_dir full_tx_zu15eg.xsa]
write_hw_platform -fixed -include_bit -force $xsa_file

set summary [open [file join $out_dir summary.txt] w]
puts $summary "project_part=$project_part"
puts $summary "clock_hz=$expected_clk_hz"
puts $summary "algorithm=$algorithm"
puts $summary "interp_mode=$interp_mode"
puts $summary "dpd_poly_order=$dpd_poly_order"
puts $summary "dpd_mp_max_taps=$dpd_mp_max_taps"
puts $summary "enable_dpd_poly=$enable_dpd_poly"
puts $summary "enable_dpd_lut=$enable_dpd_lut"
puts $summary "enable_dpd_memory=$enable_dpd_memory"
puts $summary "routed_wns_ns=$wns"
puts $summary "bitstream=$bit_file"
puts $summary "xsa=$xsa_file"
close $summary

close_project
puts "PASS full-TX routed implementation: WNS=$wns ns"
