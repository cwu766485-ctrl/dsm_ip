# Read and check ZU15EG DSM IP counters after the bare-metal smoke app runs.
#
# Optional environment variables:
#   DSM_BASE             DSM AXI-Lite base address, default 0xA0010000
#   EXPECTED_SAMPLES     Expected accepted sample count, default 0x00001000
#   EXPECTED_DPD_CTRL    Expected DPD mode after app run, default 0x00000002

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

proc show {name value} {
    puts [format "%-22s = %s" $name [hex32 $value]]
}

proc expect_eq {name actual expected} {
    show $name $actual
    if {[expr {$actual & 0xffffffff}] != [expr {$expected & 0xffffffff}]} {
        error "$name mismatch: got [hex32 $actual], expected [hex32 $expected]"
    }
}

set dsm_base [parse_num [env_or_default DSM_BASE 0xA0010000]]
set expected_samples [parse_num [env_or_default EXPECTED_SAMPLES 0x00001000]]
set expected_dpd_ctrl [parse_num [env_or_default EXPECTED_DPD_CTRL 0x00000002]]

puts "ZU15EG DSM counter check"
puts "DSM_BASE          = [hex32 $dsm_base]"
puts "EXPECTED_SAMPLES  = [hex32 $expected_samples]"
puts "EXPECTED_DPD_CTRL = [hex32 $expected_dpd_ctrl]"

connect -url tcp:127.0.0.1:3121
targets -set -filter {name =~ "PSU"}

set DSM_VERSION               0x14
set DSM_INPUT_SAMPLE_COUNT    0x18
set DSM_OUTPUT_SAMPLE_COUNT   0x1C
set DSM_ERROR_STATUS          0x24
set DSM_FRONTEND_SAMPLE_COUNT 0x28
set DSM_INPUT_STALL_COUNT     0x2C
set DSM_DPD_CTRL              0x40
set DSM_DPD_SAMPLE_COUNT      0x50
set DSM_DPD_SATURATION_COUNT  0x54
set DSM_MON_INPUT_POWER       0x64
set DSM_MON_OUTPUT_POWER      0x68
set DSM_MON_CLIP_COUNT        0x6C
set DSM_MON_PEAK              0x70
set DSM_MON_AVG_MAG           0x74
set DSM_MON_EVM_PROXY         0x78
set DSM_MON_ACPR_PROXY        0x7C
set DSM_MON_SPEC_BIN0         0x80
set DSM_MON_SPEC_BIN1         0x84
set DSM_MON_SPEC_BIN2         0x88
set DSM_MON_SPEC_ADJ          0x8C

expect_eq VERSION               [rd32 [addr_add $dsm_base $DSM_VERSION]] 0x00010000
expect_eq INPUT_SAMPLE_COUNT    [rd32 [addr_add $dsm_base $DSM_INPUT_SAMPLE_COUNT]] $expected_samples
expect_eq FRONTEND_SAMPLE_COUNT [rd32 [addr_add $dsm_base $DSM_FRONTEND_SAMPLE_COUNT]] $expected_samples
expect_eq DPD_SAMPLE_COUNT      [rd32 [addr_add $dsm_base $DSM_DPD_SAMPLE_COUNT]] $expected_samples
expect_eq OUTPUT_SAMPLE_COUNT   [rd32 [addr_add $dsm_base $DSM_OUTPUT_SAMPLE_COUNT]] $expected_samples
expect_eq INPUT_STALL_COUNT     [rd32 [addr_add $dsm_base $DSM_INPUT_STALL_COUNT]] 0x00000000
expect_eq ERROR_STATUS          [rd32 [addr_add $dsm_base $DSM_ERROR_STATUS]] 0x00000000
expect_eq DPD_CTRL              [rd32 [addr_add $dsm_base $DSM_DPD_CTRL]] $expected_dpd_ctrl
expect_eq DPD_SATURATION_COUNT  [rd32 [addr_add $dsm_base $DSM_DPD_SATURATION_COUNT]] 0x00000000

show MON_INPUT_POWER  [rd32 [addr_add $dsm_base $DSM_MON_INPUT_POWER]]
show MON_OUTPUT_POWER [rd32 [addr_add $dsm_base $DSM_MON_OUTPUT_POWER]]
show MON_CLIP_COUNT   [rd32 [addr_add $dsm_base $DSM_MON_CLIP_COUNT]]
show MON_PEAK         [rd32 [addr_add $dsm_base $DSM_MON_PEAK]]
show MON_AVG_MAG      [rd32 [addr_add $dsm_base $DSM_MON_AVG_MAG]]
show MON_EVM_PROXY    [rd32 [addr_add $dsm_base $DSM_MON_EVM_PROXY]]
show MON_ACPR_PROXY   [rd32 [addr_add $dsm_base $DSM_MON_ACPR_PROXY]]
show MON_SPEC_BIN0    [rd32 [addr_add $dsm_base $DSM_MON_SPEC_BIN0]]
show MON_SPEC_BIN1    [rd32 [addr_add $dsm_base $DSM_MON_SPEC_BIN1]]
show MON_SPEC_BIN2    [rd32 [addr_add $dsm_base $DSM_MON_SPEC_BIN2]]
show MON_SPEC_ADJ     [rd32 [addr_add $dsm_base $DSM_MON_SPEC_ADJ]]

puts "PASS ZU15EG DSM counter check completed."
