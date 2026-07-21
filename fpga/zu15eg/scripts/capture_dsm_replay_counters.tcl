# Capture ZU15EG DSM replay counters and monitor proxies as CSV.
#
# Optional environment variables:
#   DSM_BASE             DSM AXI-Lite base address, default 0xA0010000
#   EXPECTED_SAMPLES     Expected accepted sample count, default 0x00001000
#   EXPECTED_DPD_CTRL    Expected DPD mode, default 0x00000002
#   REPLAY_CSV           CSV output path. When unset, prints CSV to stdout only.

proc env_or_default {name default_value} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default_value
}

proc parse_num {value} {
    return [expr {$value}]
}

proc addr_add {base offset} {
    return [expr {($base + $offset) & 0xffffffff}]
}

proc hex32 {value} {
    return [format "0x%08X" [expr {$value & 0xffffffff}]]
}

proc rd32 {addr} {
    set value [mrd -force -value $addr]
    return [expr {$value & 0xffffffff}]
}

proc expect_eq {name actual expected} {
    if {[expr {$actual & 0xffffffff}] != [expr {$expected & 0xffffffff}]} {
        error "$name mismatch: got [hex32 $actual], expected [hex32 $expected]"
    }
}

proc csv_escape {value} {
    regsub -all {"} $value {""} escaped
    return "\"$escaped\""
}

set dsm_base [parse_num [env_or_default DSM_BASE 0xA0010000]]
set expected_samples [parse_num [env_or_default EXPECTED_SAMPLES 0x00001000]]
set expected_dpd_ctrl [parse_num [env_or_default EXPECTED_DPD_CTRL 0x00000002]]
set replay_csv [env_or_default REPLAY_CSV ""]

connect -url tcp:127.0.0.1:3121
targets -set -filter {name =~ "PSU"}

array set reg {
    VERSION               0x14
    INPUT_SAMPLE_COUNT    0x18
    OUTPUT_SAMPLE_COUNT   0x1C
    ERROR_STATUS          0x24
    FRONTEND_SAMPLE_COUNT 0x28
    INPUT_STALL_COUNT     0x2C
    INTERP_MODE           0x30
    DPD_CTRL              0x40
    DPD_C1                0x44
    DPD_C3                0x48
    DPD_C5                0x4C
    DPD_SAMPLE_COUNT      0x50
    DPD_SATURATION_COUNT  0x54
    MON_INPUT_POWER       0x64
    MON_OUTPUT_POWER      0x68
    MON_CLIP_COUNT        0x6C
    MON_PEAK              0x70
    MON_AVG_MAG           0x74
    MON_EVM_PROXY         0x78
    MON_ACPR_PROXY        0x7C
    MON_SPEC_BIN0         0x80
    MON_SPEC_BIN1         0x84
    MON_SPEC_BIN2         0x88
    MON_SPEC_ADJ          0x8C
}

set names {
    VERSION
    INTERP_MODE
    DPD_CTRL
    DPD_C1
    DPD_C3
    DPD_C5
    INPUT_SAMPLE_COUNT
    FRONTEND_SAMPLE_COUNT
    DPD_SAMPLE_COUNT
    OUTPUT_SAMPLE_COUNT
    INPUT_STALL_COUNT
    ERROR_STATUS
    DPD_SATURATION_COUNT
    MON_INPUT_POWER
    MON_OUTPUT_POWER
    MON_CLIP_COUNT
    MON_PEAK
    MON_AVG_MAG
    MON_EVM_PROXY
    MON_ACPR_PROXY
    MON_SPEC_BIN0
    MON_SPEC_BIN1
    MON_SPEC_BIN2
    MON_SPEC_ADJ
}

array set value {}
foreach name $names {
    set value($name) [rd32 [addr_add $dsm_base $reg($name)]]
}

expect_eq VERSION $value(VERSION) 0x00010000
expect_eq INPUT_SAMPLE_COUNT $value(INPUT_SAMPLE_COUNT) $expected_samples
expect_eq FRONTEND_SAMPLE_COUNT $value(FRONTEND_SAMPLE_COUNT) $expected_samples
expect_eq DPD_SAMPLE_COUNT $value(DPD_SAMPLE_COUNT) $expected_samples
expect_eq OUTPUT_SAMPLE_COUNT $value(OUTPUT_SAMPLE_COUNT) $expected_samples
expect_eq INPUT_STALL_COUNT $value(INPUT_STALL_COUNT) 0x00000000
expect_eq ERROR_STATUS $value(ERROR_STATUS) 0x00000000
expect_eq DPD_CTRL $value(DPD_CTRL) $expected_dpd_ctrl
expect_eq DPD_SATURATION_COUNT $value(DPD_SATURATION_COUNT) 0x00000000

set header "timestamp,dsm_base,expected_samples,expected_dpd_ctrl"
set row "[csv_escape [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]],[hex32 $dsm_base],[hex32 $expected_samples],[hex32 $expected_dpd_ctrl]"
foreach name $names {
    append header ",$name"
    append row ",[hex32 $value($name)]"
}

puts $header
puts $row

if {$replay_csv ne ""} {
    set f [open $replay_csv w]
    puts $f $header
    puts $f $row
    close $f
    puts "PASS replay counter CSV written: $replay_csv"
}

puts "PASS ZU15EG DSM replay counter capture completed."
