# Export the cache-flushed bare-metal calibration trace buffer through JTAG.

proc env_required {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        error "Missing required environment variable: $name"
    }
    return $::env($name)
}

proc rd32 {addr} {
    return [expr {[mrd -force -value $addr] & 0xffffffff}]
}

proc hex32 {value} {
    return [format "0x%08X" [expr {$value & 0xffffffff}]]
}

set trace_base [expr {[env_required CAL_TRACE_BASE]}]
set trace_csv [env_required CAL_TRACE_CSV]

connect -url tcp:127.0.0.1:3121
targets -set -filter {name =~ "PSU"}

set magic [rd32 [expr {$trace_base + 0}]]
set version [rd32 [expr {$trace_base + 4}]]
set header_size [rd32 [expr {$trace_base + 8}]]
set record_size [rd32 [expr {$trace_base + 12}]]
set capacity [rd32 [expr {$trace_base + 16}]]
set count [rd32 [expr {$trace_base + 20}]]
set complete [rd32 [expr {$trace_base + 24}]]
set overflow [rd32 [expr {$trace_base + 28}]]

if {$magic != 0x43414C54} { error "Calibration trace magic mismatch: [hex32 $magic]" }
if {$version != 0x00010000} { error "Unsupported calibration trace version: [hex32 $version]" }
if {$header_size != 32} { error "Unexpected calibration trace header size: $header_size" }
if {$record_size != 112} { error "Unexpected calibration trace record size: $record_size" }
if {$count > $capacity} { error "Calibration trace count $count exceeds capacity $capacity" }
if {$complete != 1} { error "Calibration trace is not complete: complete=$complete count=$count" }

set stage_name {unknown software_seed package search replay final policy}
set decision_name {unknown accept reject selected}
set reason_name {unknown best_overall not_best_overall lower_cost not_lower_cost fixed_replay final_replay policy_replay}
set columns {
    candidate_id round stage decision reason mode package searched c1 c3 c5
    proxy_evm_ppm proxy_sndr_mdB input_power output_power saturation clip error
    stall peak avg_mag evm_proxy acpr_proxy spec_bin0 spec_bin1 spec_bin2 spec_adj cost
}

set f [open $trace_csv w]
puts $f [join $columns ,]
for {set index 0} {$index < $count} {incr index} {
    set addr [expr {$trace_base + $header_size + ($index * $record_size)}]
    set words {}
    for {set word 0} {$word < 28} {incr word} {
        lappend words [rd32 [expr {$addr + ($word * 4)}]]
    }

    set stage [lindex $words 2]
    set decision [lindex $words 3]
    set reason [lindex $words 4]
    set row [list \
        [lindex $words 0] [lindex $words 1] \
        [lindex $stage_name $stage] [lindex $decision_name $decision] \
        [lindex $reason_name $reason] [lindex $words 5] [lindex $words 6] \
        [lindex $words 7] [hex32 [lindex $words 8]] [hex32 [lindex $words 9]] \
        [hex32 [lindex $words 10]] [lindex $words 11] [lindex $words 12] \
        [hex32 [lindex $words 13]] [hex32 [lindex $words 14]] \
        [hex32 [lindex $words 15]] [hex32 [lindex $words 16]] \
        [hex32 [lindex $words 17]] [hex32 [lindex $words 18]] \
        [hex32 [lindex $words 19]] [hex32 [lindex $words 20]] \
        [hex32 [lindex $words 21]] [hex32 [lindex $words 22]] \
        [hex32 [lindex $words 23]] [hex32 [lindex $words 24]] \
        [hex32 [lindex $words 25]] [hex32 [lindex $words 26]] [lindex $words 27]]
    puts $f [join $row ,]
}
close $f

puts "CAL_TRACE_META base=[hex32 $trace_base] count=$count capacity=$capacity complete=$complete overflow=$overflow"
puts "PASS calibration trace CSV written: $trace_csv"
