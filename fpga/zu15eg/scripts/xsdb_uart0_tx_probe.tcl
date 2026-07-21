connect -url tcp:127.0.0.1:3121

set a53_targets [targets -filter {name =~ "*Cortex-A53 #0*"}]
if {[llength $a53_targets] == 0} {
    error "No Cortex-A53 #0 target found"
}
targets -set [lindex $a53_targets 0]

set uart0_fifo 0xFF000030
set message "UART0_JTAG_PROBE_PASS\r\n"
foreach byte [split $message ""] {
    scan $byte %c value
    mwr $uart0_fifo $value
}
puts "PASS wrote UART0 probe string"
