# Read-only path audit for the two GT TX-active CDC-11 findings.
# Usage: vivado -mode batch -source syn/audit_thermo5_gt_cdc11_paths.tcl \
#        -tclargs runs/thermo5_parent_cleanroute_20261005_2117/routed.dcp
if {[llength $argv] != 1} { error "usage: <routed.dcp>" }
set dcp [file normalize [lindex $argv 0]]
if {![file exists $dcp]} { error "Missing routed checkpoint: $dcp" }
open_checkpoint $dcp

proc audit_cell {label exact_name} {
  set cells [get_cells -hierarchical -quiet -filter "NAME == $exact_name"]
  puts "AUDIT_CELL $label count=[llength $cells]"
  foreach cell $cells {
    set name [get_property NAME $cell]
    set ref [get_property REF_NAME $cell]
    set async [get_property -quiet ASYNC_REG $cell]
    set loc [get_property -quiet LOC $cell]
    set cpin [get_pins -quiet -of_objects $cell -filter {REF_PIN_NAME == C}]
    set qpin [get_pins -quiet -of_objects $cell -filter {REF_PIN_NAME == Q}]
    set dpin [get_pins -quiet -of_objects $cell -filter {REF_PIN_NAME == D}]
    set cclks [get_clocks -quiet -of_objects $cpin]
    set dclks [get_clocks -quiet -of_objects $dpin]
    set qclks [get_clocks -quiet -of_objects $qpin]
    puts "  CELL name=$name ref=$ref ASYNC_REG=$async LOC=$loc"
    puts "    C_CLOCKS=$cclks D_CLOCKS=$dclks Q_CLOCKS=$qclks"
    if {[llength $qpin]} {
      set endpoints [all_fanout -flat -endpoints_only -from $qpin]
      puts "    Q_ENDPOINT_COUNT=[llength $endpoints] Q_ENDPOINTS=$endpoints"
    }
  }
}

puts "AUDIT_DCP=$dcp"
puts "AUDIT_CLOCKS=[get_clocks -quiet {core_clk218 freerun_clk200}]"
set gtbase {u_gt/inst/gen_gtwizard_gthe4_top.thermo5_qsfp_gt14_probe_gtwizard_gthe4_inst}
set txclock "$gtbase/gen_gtwizard_gthe4.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst"
set resetctl "$gtbase/gen_gtwizard_gthe4.gen_reset_controller_internal.gen_single_instance.gtwiz_reset_inst"
set txactive_sync "$txclock/gen_gtwiz_userclk_tx_main.gtwiz_userclk_tx_active_sync_reg"
set wiz_sync "$resetctl/bit_synchronizer_gtwiz_reset_userclk_tx_active_inst"
audit_cell tx_active_source $txactive_sync
audit_cell parent_meta tx_active_meta_reg
audit_cell parent_sync tx_active_sync_reg
audit_cell wizard_meta "$wiz_sync/i_in_meta_reg"
audit_cell wizard_sync1 "$wiz_sync/i_in_sync1_reg"
audit_cell wizard_sync2 "$wiz_sync/i_in_sync2_reg"
audit_cell wizard_sync3 "$wiz_sync/i_in_sync3_reg"
audit_cell wizard_out "$wiz_sync/i_in_out_reg"

# Repeat the routed design's CDC analysis to preserve the tool's exact rule text
# and the two destination pin paths in the transcript. No constraints are changed.
report_cdc -details
puts "THERMO5_GT_CDC11_READ_ONLY_AUDIT_COMPLETE"
