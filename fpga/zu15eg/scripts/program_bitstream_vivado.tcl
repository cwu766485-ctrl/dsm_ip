# Program ZU15EG bitstream through Vivado Hardware Manager.
#
# Usage:
#   vivado -mode batch -source fpga/zu15eg/scripts/program_bitstream_vivado.tcl \
#     -tclargs <top.bit> <top.ltx>

if {$argc < 1} {
    puts "Usage: program_bitstream_vivado.tcl <bit_file> ?ltx_file?"
    exit 1
}

set bit_file [file normalize [lindex $argv 0]]
set ltx_file ""
if {$argc >= 2} {
    set ltx_file [file normalize [lindex $argv 1]]
}

if {![file exists $bit_file]} {
    puts "ERROR: bitstream not found: $bit_file"
    exit 1
}

open_hw_manager
connect_hw_server -url 127.0.0.1:3121
foreach t [get_hw_targets *] {
    open_hw_target $t
}

set devices [get_hw_devices xczu15*]
if {[llength $devices] == 0} {
    puts "ERROR: no xczu15 hardware device found"
    exit 1
}

set dev [lindex $devices 0]
current_hw_device $dev
refresh_hw_device $dev
set_property PROGRAM.FILE $bit_file $dev
if {$ltx_file ne "" && [file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file $dev
}

puts "Programming $dev with $bit_file"
program_hw_devices $dev
refresh_hw_device $dev
puts "PASS programmed $dev"
close_hw_manager
