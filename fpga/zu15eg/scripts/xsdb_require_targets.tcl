# Fail early when hw_server does not expose a usable Zynq UltraScale+ target.

connect -url tcp:127.0.0.1:3121

set all_targets [targets]
puts "XSDB target scan:"
puts $all_targets

set pl_targets [targets -filter {name =~ "PL"}]
set a53_targets [targets -filter {name =~ "*Cortex-A53 #0*"}]
set psu_targets [targets -filter {name =~ "PSU"}]

if {[llength $pl_targets] == 0 || [llength $a53_targets] == 0 || [llength $psu_targets] == 0} {
    error "No usable ZU15EG JTAG target found. Reconnect or power-cycle the JTAG path, close other hw_server/xic sessions, then retry."
}

puts "PASS usable ZU15EG JTAG targets found."
