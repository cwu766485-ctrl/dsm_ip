# Read-only package-pin audit.  The schematic identifies a four-lane QSFP
# route on bank 128 but labels its FPGA symbol xczu9eg; verify against the
# actual XCZU15EG part before any board implementation claim.
set part xczu15eg-ffvb1156-2-i
create_project -in_memory -part $part
set_property design_mode PinPlanning [get_filesets sources_1]
open_io_design -name io_1
puts "AUDIT_PART $part"
foreach {signal pin} {
  qsfp_tx1_p T29 qsfp_tx1_n T30
  qsfp_rx1_p T33 qsfp_rx1_n T34
  qsfp_tx2_p R31 qsfp_tx2_n R32
  qsfp_rx2_p P33 qsfp_rx2_n P34
  qsfp_tx3_p P29 qsfp_tx3_n P30
  qsfp_rx3_p N31 qsfp_rx3_n N32
  qsfp_tx4_p M29 qsfp_tx4_n M30
  qsfp_rx4_p M33 qsfp_rx4_n M34
  gty128_ref_p R27 gty128_ref_n R28
} {
  set obj [get_package_pins -quiet $pin]
  if {[llength $obj] != 1} {
    puts "AUDIT_MISSING $signal $pin"
    continue
  }
  set props {}
  foreach prop {PIN_FUNC BANK SITE} {
    if {[lsearch -exact [list_property $obj] $prop] >= 0} {
      lappend props "$prop=[get_property $prop $obj]"
    }
  }
  puts "AUDIT_PIN $signal $pin [join $props { }] SITES=[get_sites -quiet -of_objects $obj]"
}
close_project
