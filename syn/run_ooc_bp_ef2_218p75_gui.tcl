# One-command Vivado Tcl Console entry point for the high-rate timing target.
# Run from the repository root with:
#   source syn/run_ooc_bp_ef2_218p75_gui.tcl
#
# Change ::bp_part before sourcing if the installed board uses another device.
if {![info exists ::bp_part]} {
  set ::bp_part "xczu15eg-ffvb1156-2-i"
}
set ::argv [list $::bp_part 218.75]
source [file join [file dirname [file normalize [info script]]] run_ooc_bp_ef2_axi.tcl]
