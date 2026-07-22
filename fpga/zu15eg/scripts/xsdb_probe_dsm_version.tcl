# Read-only probe for the DSM AXI-Lite identity register.

connect -url tcp:127.0.0.1:3121

set psu_targets [targets -filter {name =~ "PSU"}]
if {[llength $psu_targets] == 0} {
    error "No PSU target found"
}

targets -set [lindex $psu_targets 0]
set version [expr {[mrd -force -value 0xA0010014] & 0xffffffff}]
puts [format "DSM_VERSION=0x%08X" $version]
if {$version != 0x00010000} {
    error [format "Unexpected DSM version 0x%08X" $version]
}

puts "PASS DSM AXI-Lite identity register is readable."
disconnect
