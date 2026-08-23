# Arm the DSM ILA for the fixed 24-input, 768-RF-sample board golden run.
# Start the golden bare-metal ELF after this script reports that ILA is armed.
# The resulting CSV is compared by compare_ila_golden.py.

if {$argc != 1} {
    puts "Usage: capture_ila_golden.tcl <capture.csv>"
    exit 1
}

set capture_csv [file normalize [lindex $argv 0]]
file mkdir [file dirname $capture_csv]

open_hw_manager
connect_hw_server -url 127.0.0.1:3121
set device [lindex [get_hw_devices xczu15*] 0]
if {$device eq ""} {
    error "No XCZU15EG hardware device found. Program an ILA-enabled bitstream first."
}
current_hw_device $device
refresh_hw_device $device

set ilas [get_hw_ilas -of_objects $device]
if {[llength $ilas] == 0} {
    error "No hardware ILA found. The programmed bitstream must include ila_dsm_0 and its LTX probes file."
}
set ila [lindex $ilas 0]
set_property CONTROL.TRIGGER_POSITION 0 $ila
set_property CONTROL.TRIGGER_MODE BASIC $ila

set valid_probes [get_hw_probes -of_objects $ila -filter {NAME =~ "*probe4*"}]
if {[llength $valid_probes] == 0} {
    error "Expected probe4=rf_valid is absent. Rebuild from create_dsm_dma_ila_bd.tcl."
}
set_property COMPARE_VALUE.EQ 1'b1 [lindex $valid_probes 0]
puts "Arming $ila: trigger probe4 (rf_valid) == 1. Start the CAL_ILA_GOLDEN_ONLY ELF now."
run_hw_ila $ila
wait_on_hw_ila $ila
set ila_data [upload_hw_ila_data $ila]
write_hw_ila_data -csv_file $capture_csv $ila_data
puts "PASS ILA capture written: $capture_csv"
close_hw_manager
