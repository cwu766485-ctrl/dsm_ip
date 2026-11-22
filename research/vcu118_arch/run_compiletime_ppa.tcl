# Compile-time Thermo5 product top OOC synthesis and optional route.
# This is a research flow with explicit provisional boundary budgets; it is
# not a board-level VCU118 signoff flow.
if {[llength $argv] ni {3 4}} {error "usage: <DSM_ARCH:0|1|2> <new-output-dir> <route:0|1> ?synthesized.dcp?"}
set arch [lindex $argv 0]
set out [file normalize [lindex $argv 1]]
set do_route [lindex $argv 2]
set source_dcp ""
if {[llength $argv] == 4} {set source_dcp [file normalize [lindex $argv 3]]}
if {$arch ni {0 1 2} || $do_route ni {0 1}} {error "invalid architecture or route flag"}
if {$source_dcp ne "" && (!$do_route || ![file isfile $source_dcp])} {error "DCP reuse requires route=1 and an existing source checkpoint"}
if {[file exists $out]} {error "refusing to overwrite output directory"}
set repo [file normalize [file join [file dirname [info script]] ../..]]
set timing_xdc [file join $repo research vcu118_arch compiletime_timing_budget.xdc]
if {![file isfile $timing_xdc]} {error "timing XDC not found: $timing_xdc"}
file mkdir $out
cd $out
create_project -in_memory -part xcvu9p-flga2104-2L-e
set ::env(HRT_TCL_PATH) [string map {\\ /} [file normalize [file join $::env(XILINX_VIVADO) scripts rt fpga_tcl]]]
set ::env(XILINX_REALTIMEFPGA) 1
catch {unset ::env(BUILTIN_SYNTH)}
set_param general.maxThreads 1
set_param synth.maxThreads 1
catch {set_param synth.enableParallelSynthesis false}
catch {set_param synth.parallelSynthesis false}
set version_file [open tool_version.txt w]
puts $version_file [version -short]
close $version_file
if {$source_dcp ne ""} {
  open_checkpoint $source_dcp
  reset_timing
  read_xdc $timing_xdc
  puts "COMPILETIME_SOURCE_DCP_REUSED $source_dcp"
} else {
foreach x {xpm_cdc xpm_memory xpm_fifo} {
  read_verilog -sv [file join $::env(XILINX_VIVADO) data ip xpm $x hdl ${x}.sv]
}
set filelist [open [file join $repo dv uvm sim thermo5_sku_filelist.f] r]
foreach line [split [read $filelist] \n] {
  set line [string trim $line]
  if {[string match rtl/* $line]} {read_verilog -sv [file join $repo $line]}
}
close $filelist
read_xdc $timing_xdc
synth_design -top tid32_thermo5_compiletime_tx -part xcvu9p-flga2104-2L-e \
  -mode out_of_context -generic DSM_ARCH=$arch
}

# Apply the provisional OOC interface budget only after the ports and
# synthesized design exist. XDC is kept to native constraint commands; Tcl
# foreach logic belongs here, not in an XDC file.
set io_input_count 0
foreach p [get_ports -filter {DIRECTION == IN && NAME !~ *clk*}] {
  set n [get_property NAME $p]
  if {$n eq "common_aresetn"} {
    # One asynchronous reset input feeds three local reset synchronizers.
    # Constrain its arrival against each destination clock for recovery/removal
    # analysis; this is not a reset-wide false path.
    foreach c {s_axil_aclk s_axis_aclk core_clk} {
      set_input_delay -max 0.2 -clock [get_clocks $c] $p
      set_input_delay -min 0.2 -clock [get_clocks $c] $p
    }
    incr io_input_count
    continue
  } elseif {[string match s_axil_* $n]} {
    set c s_axil_aclk
  } elseif {[string match s_axis_* $n]} {
    set c s_axis_aclk
  } else {
    set c core_clk
  }
  set_input_delay -max 0.2 -clock [get_clocks $c] $p
  set_input_delay -min 0.2 -clock [get_clocks $c] $p
  incr io_input_count
}
set io_output_count 0
foreach p [get_ports -filter {DIRECTION == OUT}] {
  set n [get_property NAME $p]
  if {[string match s_axil_* $n] || $n in {cfg_busy cfg_done cfg_error dsm_switch_busy}} {
    set c s_axil_aclk
  } elseif {[string match s_axis_* $n]} {
    set c s_axis_aclk
  } else {
    set c core_clk
  }
  set_output_delay -max 0.2 -clock [get_clocks $c] $p
  set_output_delay -min 0.0 -clock [get_clocks $c] $p
  incr io_output_count
}
puts "OOC_IO_BUDGET inputs=$io_input_count min_max_ns=0.2 outputs=$io_output_count min_ns=0.0 max_ns=0.2"

# Confirm the generated netlist contains the selected backend and no other
# compile-time backend or runtime backend. Fail closed if hierarchy naming
# does not allow the architecture pruning check to be performed.
set selected [dict get {0 g_ef1 1 g_ef2 2 g_mash11} $arch]
foreach branch {g_ef1 g_ef2 g_mash11} {
  set found [get_cells -hier -filter "NAME =~ *$branch*"]
  if {$branch eq $selected && [llength $found] == 0} {
    error "selected DSM generate hierarchy $branch not found"
  }
  if {$branch ne $selected && [llength $found] != 0} {
    error "unselected DSM generate hierarchy $branch survived synthesis"
  }
}
if {[llength [get_cells -hier -filter {NAME =~ *g_runtime_dsm*}]] != 0} {
  error "runtime DSM backend survived compile-time synthesis"
}
set blackboxes [get_cells -hier -filter {IS_BLACKBOX == 1}]
set latch_cells [get_cells -hier -filter {REF_NAME =~ LD*}]
if {[llength $blackboxes] != 0} {error "blackbox cells remain after synthesis: [llength $blackboxes]"}
if {[llength $latch_cells] != 0} {error "latch cells remain after synthesis: [llength $latch_cells]"}
puts "COMPILETIME_HIERARCHY_PASS DSM_ARCH=$arch selected=$selected blackboxes=[llength $blackboxes]"
puts "COMPILETIME_LATCH_CHECK_PASS latch_cells=[llength $latch_cells]"
report_utilization -hierarchical -file hierarchy.rpt
report_utilization -hierarchical -file synth_utilization_hierarchical.rpt

# Local async-assert/sync-release reset synchronizers: exception only to the
# asynchronous CLR pins of cells explicitly tagged ASYNC_REG.
set reset_cells [get_cells -hier -filter {NAME =~ *sync_q_reg*}]
if {[llength $reset_cells] == 0} {error "reset synchronizer cells not found"}
foreach c $reset_cells {
  set attr [string toupper [get_property ASYNC_REG $c]]
  if {$attr ni {TRUE 1}} {error "reset synchronizer lacks ASYNC_REG: [get_property NAME $c]"}
}
set reset_clr [get_pins -of_objects $reset_cells -filter {REF_PIN_NAME == CLR}]
if {[llength $reset_clr] == 0} {error "reset synchronizer CLR pins not found"}
set_false_path -to $reset_clr
puts "RESET_CLR_ENDPOINTS [llength $reset_clr]"

# Single-bit synchronizers are excluded only at their first D stage and only
# after checking the synchronizer attribute on every selected register.
proc add_sync1_exception {patterns label} {
  set cells {}
  foreach pattern $patterns {
    set found [get_cells -hier -filter "NAME =~ $pattern"]
    if {[llength $found] == 0} {error "$label synchronizer not found: $pattern"}
    foreach c $found {
      set attr [string toupper [get_property ASYNC_REG $c]]
      if {$attr ni {TRUE 1}} {error "$label cell lacks ASYNC_REG: [get_property NAME $c]"}
      lappend cells $c
    }
  }
  set cells [lsort -unique $cells]
  set pins [get_pins -of_objects $cells -filter {REF_PIN_NAME == D}]
  if {[llength $pins] != [llength $cells]} {error "$label first-stage D pin count mismatch"}
  set_false_path -to $pins
  puts "CDC_SYNC1_ENDPOINTS label=$label count=[llength $pins]"
}
add_sync1_exception {*u_cfg/cfg_req_sync1_reg* *u_cfg/run_sync1_reg*} axil_to_core
add_sync1_exception {*u_cfg/cfg_ack_sync1_reg* *u_cfg/tx_active_sync1_reg* *u_cfg/draining_sync1_reg*} core_to_axil
add_sync1_exception {*run_s1_reg*} axil_to_axis
add_sync1_exception {*u_product/arch_locked_c1_reg* *u_product/ingress_closed_c1_reg* *u_product/source_error_c1_reg*} axis_to_core

# In the compile-time common-reset FIFO mode, the XPM reset-level synchronizer
# samples the write-domain local reset solely to generate XPM's wr_clk-aligned
# reset. Exempt only its first D stage; stage one remains normally timed.
set fifo_reset_first_stage {}
foreach c [get_cells -hier -filter {NAME =~ *wr_reset_sync_reg*}] {
  set n [get_property NAME $c]
  if {![regexp {wr_reset_sync_reg\[0\]$} $n]} {continue}
  set attr [string toupper [get_property ASYNC_REG $c]]
  if {$attr ni {TRUE 1}} {error "FIFO reset first stage lacks ASYNC_REG: $n"}
  lappend fifo_reset_first_stage $c
}
if {[llength $fifo_reset_first_stage] != 1} {
  error "expected one common-epoch FIFO reset synchronizer stage zero, found [llength $fifo_reset_first_stage]"
}
set fifo_reset_first_stage_d [get_pins -of_objects $fifo_reset_first_stage -filter {REF_PIN_NAME == D}]
if {[llength $fifo_reset_first_stage_d] != 1} {error "FIFO reset first-stage D pin count mismatch"}
set_false_path -to $fifo_reset_first_stage_d
puts "COMMON_EPOCH_FIFO_RESET_SYNC1_D_ENDPOINTS [llength $fifo_reset_first_stage_d]"

# The read side waits for the AXIS-domain reset to release through a two-flop
# ASYNC_REG chain before exposing FWFT valid. Exempt only its asynchronous CLR
# pins; the stage-to-stage path remains timed in core_clk.
set fifo_read_reset_guard [get_cells -hier -filter {NAME =~ *wr_reset_in_rd_reg*}]
if {[llength $fifo_read_reset_guard] != 2} {
  error "expected two common-epoch read reset guard flops, found [llength $fifo_read_reset_guard]"
}
foreach c $fifo_read_reset_guard {
  set attr [string toupper [get_property ASYNC_REG $c]]
  if {$attr ni {TRUE 1}} {error "read reset guard lacks ASYNC_REG: [get_property NAME $c]"}
}
set fifo_read_reset_guard_clr [get_pins -of_objects $fifo_read_reset_guard -filter {REF_PIN_NAME == CLR}]
if {[llength $fifo_read_reset_guard_clr] != 2} {error "read reset guard CLR count mismatch"}
set_false_path -to $fifo_read_reset_guard_clr
puts "COMMON_EPOCH_FIFO_READ_RESET_GUARD_CLR_ENDPOINTS [llength $fifo_read_reset_guard_clr]"

# The XPM reset synchronizer's stage-zero D endpoints are asynchronous; require
# exactly the two generated first stages and verify ASYNC_REG before exception.
set xpm_stage0_d {}
foreach c [get_cells -hier -filter {NAME =~ *syncstages_ff_reg*}] {
  set n [get_property NAME $c]
  if {![regexp {xpm_fifo_rst_inst/.*gen_rst_ic\.(rrst_wr_inst|wrst_rd_inst)/syncstages_ff_reg\[0\]$} $n]} {continue}
  set attr [string toupper [get_property ASYNC_REG $c]]
  if {$attr ni {TRUE 1}} {error "XPM reset stage zero lacks ASYNC_REG: $n"}
  set pins [get_pins -of_objects $c -filter {REF_PIN_NAME == D}]
  if {[llength $pins] != 1} {error "XPM reset stage-zero D count mismatch: $n"}
  lappend xpm_stage0_d $pins
  puts "VERIFIED_XPM_RESET_STAGE0 $n ASYNC_REG=$attr"
}
set xpm_stage0_d [lsort -unique $xpm_stage0_d]
if {[llength $xpm_stage0_d] != 2} {error "expected two XPM FIFO reset stage-zero D pins, found [llength $xpm_stage0_d]"}
set_false_path -to $xpm_stage0_d

# DPD coefficients cross as a stable four-phase mailbox. Bound the source
# register clock pins to Pending-bank capture D pins and audit bus skew.
set cfg_src [get_cells -hier -filter {NAME =~ *u_cfg/cfg_mailbox_q_reg*}]
set cfg_dst [get_cells -hier -filter {NAME =~ *u_cfg/cfg_pending_core_reg*}]
if {[llength $cfg_src] == 0 || [llength $cfg_dst] == 0} {error "DPD config mailbox endpoints not found"}
set_max_delay -datapath_only 4.571428571 \
  -from [get_pins -of_objects $cfg_src -filter {REF_PIN_NAME == C}] \
  -to [get_pins -of_objects $cfg_dst -filter {REF_PIN_NAME == D}]
set_bus_skew 4.571428571 \
  -from [get_pins -of_objects $cfg_src -filter {REF_PIN_NAME == C}] \
  -to [get_pins -of_objects $cfg_dst -filter {REF_PIN_NAME == D}]
puts "DPD_MAILBOX_BOUNDED src_cells=[llength $cfg_src] dst_cells=[llength $cfg_dst] limit_ns=4.571428571"

# Preserve Gray-pointer physical ordering bounds for each XPM async FIFO.
set gray_sources [get_cells -hier -filter {NAME =~ *src_gray_ff_reg*}]
set gray_dest_all [get_cells -hier -filter {NAME =~ *dest_graysync_ff_reg*}]
if {[llength $gray_sources] == 0 || [llength $gray_dest_all] == 0} {error "XPM Gray pointer synchronizers not found"}
set gray_pairs 0
set gray_seen {}
foreach src_cell $gray_sources {
  set src_name [get_property NAME $src_cell]
  regsub {/src_gray_ff_reg.*$} $src_name "" inst
  if {[lsearch -exact $gray_seen $inst] >= 0} {continue}
  lappend gray_seen $inst
  set dst_cells {}
  foreach dst_cell $gray_dest_all {
    set dst_name [get_property NAME $dst_cell]
    if {[string match "${inst}/dest_graysync_ff_reg*" $dst_name] &&
        [regexp {dest_graysync_ff_reg\[0\]($|\[)} $dst_name]} {lappend dst_cells $dst_cell}
  }
  if {[llength $dst_cells] == 0} {continue}
  set src_group [get_cells -hier -filter "NAME =~ ${inst}/src_gray_ff_reg*"]
  set src_c [get_pins -of_objects $src_group -filter {REF_PIN_NAME == C}]
  set dst_d [get_pins -of_objects $dst_cells -filter {REF_PIN_NAME == D}]
  set clocks [get_clocks -of_objects $src_c]
  if {[llength $clocks] != 1 || [llength $src_c] == 0 || [llength $dst_d] == 0} {error "cannot resolve Gray pointer constraints: $inst"}
  set bound [get_property PERIOD [lindex $clocks 0]]
  set_max_delay -datapath_only $bound -from $src_c -to $dst_d
  set_bus_skew $bound -from $src_c -to $dst_d
  incr gray_pairs
  puts "XPM_GRAY_BOUNDED instance=$inst period_ns=$bound dest_bits=[llength $dst_d]"
}
if {$gray_pairs == 0} {error "no XPM Gray pointer groups paired"}

report_cdc -file synthesized_cdc.rpt
report_cdc -details -file synthesized_cdc_details.rpt
report_exceptions -file exceptions.rpt
report_clock_interaction -delay_type min_max -file clock_interaction.rpt
check_timing -verbose -file check_timing.rpt
report_utilization -file synth_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file synth_timing_summary.rpt
write_checkpoint synthesized.dcp

if {$do_route} {
  foreach step {opt_design place_design phys_opt_design route_design} {
    if {[catch {uplevel #0 $step} message options]} {
      puts stderr "IMPLEMENTATION_STEP_FAILED step=$step message=$message"
      if {[dict exists $options -errorinfo]} {puts stderr [dict get $options -errorinfo]}
      error "implementation step failed: $step"
    }
    if {$step eq "place_design"} {write_checkpoint placed.dcp}
  }
  write_checkpoint routed.dcp
  report_cdc -file routed_cdc.rpt
  report_cdc -details -file routed_cdc_details.rpt
  report_utilization -file routed_utilization.rpt
  report_timing_summary -delay_type min_max -report_unconstrained -file routed_timing_summary.rpt
  report_timing -delay_type max -max_paths 20 -nworst 20 -file setup_worst20.rpt
  report_timing -delay_type min -max_paths 20 -nworst 20 -file hold_worst20.rpt
  report_timing -delay_type max -max_paths 20 -nworst 20 \
    -from [get_clocks core_clk] -to [get_clocks core_clk] -file core_setup_worst20.rpt
  report_clock_interaction -delay_type min_max -file routed_clock_interaction.rpt
  report_exceptions -file routed_exceptions.rpt
  report_bus_skew -file routed_bus_skew.rpt
  report_power -file power_default_activity.rpt
  puts "COMPILETIME_PPA_ROUTE_PASS DSM_ARCH=$arch OUT=$out"
} else {
  puts "COMPILETIME_PPA_SYNTH_PASS DSM_ARCH=$arch OUT=$out"
}
