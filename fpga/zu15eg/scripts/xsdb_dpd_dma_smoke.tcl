# XSDB board smoke for the ZU15EG DSM IP DPD control path.
#
# Required environment variables:
#   DSM_BASE   AXI-Lite base address of dsm_ip_0
#   DMA_BASE   AXI-Lite base address of axi_dma_0
#
# Optional environment variables:
#   DDR_ADDR      DMA source buffer address, default 0x10000000
#   DMA_BYTES     DMA transfer length in bytes, default 0x00004000
#   DMA_BIN       Packed 32-bit I/Q binary for DMA source data
#   PSU_INIT_TCL  Generated psu_init.tcl
#   BIT_FILE      Bitstream to program when PROGRAM_BIT=1
#   PROGRAM_BIT   1 to program BIT_FILE before smoke, default 0
#   DPD_MODE      0=bypass, 1=polynomial, 2=LUT, default 1

proc env_or_default {name default_value} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default_value
}

proc require_env {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        error "Missing required environment variable $name"
    }
    return $::env($name)
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

proc wr32 {addr value} {
    mwr -force $addr [expr {$value & 0xffffffff}]
}

proc expect_eq {name actual expected} {
    if {[expr {$actual & 0xffffffff}] != [expr {$expected & 0xffffffff}]} {
        error "$name mismatch: got [hex32 $actual], expected [hex32 $expected]"
    }
    puts "PASS $name = [hex32 $actual]"
}

proc poll_until {name addr mask expected timeout_ms} {
    set elapsed 0
    while {$elapsed < $timeout_ms} {
        set value [rd32 $addr]
        if {[expr {$value & $mask}] == $expected} {
            puts "PASS $name = [hex32 $value]"
            return $value
        }
        after 10
        incr elapsed 10
    }
    set value [rd32 $addr]
    error "$name timeout: got [hex32 $value], mask [hex32 $mask], expected [hex32 $expected]"
}

set dsm_base [parse_num [require_env DSM_BASE]]
set dma_base [parse_num [require_env DMA_BASE]]
set ddr_addr [parse_num [env_or_default DDR_ADDR 0x10000000]]
set dma_bytes [parse_num [env_or_default DMA_BYTES 0x00004000]]
set dma_bin [env_or_default DMA_BIN ""]
set psu_init_tcl [env_or_default PSU_INIT_TCL ""]
set bit_file [env_or_default BIT_FILE ""]
set program_bit [parse_num [env_or_default PROGRAM_BIT 0]]
set dpd_mode [parse_num [env_or_default DPD_MODE 1]]

set expected_samples [expr {$dma_bytes / 4}]

puts "ZU15EG DPD/DMA smoke"
puts "DSM_BASE      = [hex32 $dsm_base]"
puts "DMA_BASE      = [hex32 $dma_base]"
puts "DDR_ADDR      = [hex32 $ddr_addr]"
puts "DMA_BYTES     = [hex32 $dma_bytes]"
puts "EXPECTED_SAMP = $expected_samples"
puts "DPD_MODE      = $dpd_mode"

connect -url tcp:127.0.0.1:3121

if {$program_bit != 0} {
    if {$bit_file eq "" || ![file exists $bit_file]} {
        error "PROGRAM_BIT=1 but BIT_FILE is missing or does not exist"
    }
    puts "Programming FPGA: $bit_file"
    set pl_targets [targets -filter {name =~ "PL"}]
    if {[llength $pl_targets] == 0} {
        error "no PL target found for FPGA programming"
    }
    targets -set [lindex $pl_targets 0]
    fpga -file $bit_file
}

if {$psu_init_tcl ne "" && [file exists $psu_init_tcl]} {
    puts "Running PS init: $psu_init_tcl"
    source $psu_init_tcl
    targets -set -filter {name =~ "PSU"}
    psu_init
    psu_ps_pl_isolation_removal
    psu_ps_pl_reset_config
} else {
    puts "WARNING: PSU_INIT_TCL not found; assuming PS/PL clocks are already initialized."
}

targets -set -filter {name =~ "PSU"}

# DSM register offsets.
set DSM_CTRL                 0x00
set DSM_VERSION              0x14
set DSM_INPUT_SAMPLE_COUNT   0x18
set DSM_OUTPUT_SAMPLE_COUNT  0x1C
set DSM_ERROR_STATUS         0x24
set DSM_FRONTEND_SAMPLE_COUNT 0x28
set DSM_INPUT_STALL_COUNT    0x2C
set DSM_INTERP_MODE          0x30
set DSM_DPD_CTRL             0x40
set DSM_DPD_C1               0x44
set DSM_DPD_C3               0x48
set DSM_DPD_C5               0x4C
set DSM_DPD_SAMPLE_COUNT     0x50
set DSM_DPD_SATURATION_COUNT 0x54
set DSM_DPD_LUT_ADDR         0x58
set DSM_DPD_LUT_DATA         0x5C
set DSM_DPD_LUT_COMMIT       0x60

# AXI DMA simple-mode MM2S offsets.
set DMA_MM2S_DMACR           0x00
set DMA_MM2S_DMASR           0x04
set DMA_MM2S_SA              0x18
set DMA_MM2S_SA_MSB          0x1C
set DMA_MM2S_LENGTH          0x28

set version [rd32 [addr_add $dsm_base $DSM_VERSION]]
puts "DSM VERSION   = [hex32 $version]"
puts "INTERP_MODE   = [hex32 [rd32 [addr_add $dsm_base $DSM_INTERP_MODE]]]"

# Fixed-point DPD baseline coefficients from MATLAB, packed as {imag[15:0], real[15:0]}.
set dpd_c1 0xFFFB4009
set dpd_c3 0xF1A41F6F
set dpd_c5 0xDE503A39
set dpd_lut_identity 0x00004000

wr32 [addr_add $dsm_base $DSM_DPD_CTRL] 0x00000000
if {$dpd_mode == 1} {
    puts "DPD_C1_BEFORE = [hex32 [rd32 [addr_add $dsm_base $DSM_DPD_C1]]]"
    wr32 [addr_add $dsm_base $DSM_DPD_C1] $dpd_c1
    wr32 [addr_add $dsm_base $DSM_DPD_C3] $dpd_c3
    wr32 [addr_add $dsm_base $DSM_DPD_C5] $dpd_c5
    expect_eq DPD_C1_READBACK [rd32 [addr_add $dsm_base $DSM_DPD_C1]] $dpd_c1
    expect_eq DPD_C3_READBACK [rd32 [addr_add $dsm_base $DSM_DPD_C3]] $dpd_c3
    expect_eq DPD_C5_READBACK [rd32 [addr_add $dsm_base $DSM_DPD_C5]] $dpd_c5
} elseif {$dpd_mode == 2} {
    for {set k 0} {$k < 16} {incr k} {
        wr32 [addr_add $dsm_base $DSM_DPD_LUT_ADDR] $k
        wr32 [addr_add $dsm_base $DSM_DPD_LUT_DATA] $dpd_lut_identity
    }
    wr32 [addr_add $dsm_base $DSM_DPD_LUT_ADDR] 0
    expect_eq DPD_LUT0_READBACK [rd32 [addr_add $dsm_base $DSM_DPD_LUT_DATA]] $dpd_lut_identity
    wr32 [addr_add $dsm_base $DSM_DPD_LUT_ADDR] 15
    expect_eq DPD_LUT15_READBACK [rd32 [addr_add $dsm_base $DSM_DPD_LUT_DATA]] $dpd_lut_identity
    set bank_before [rd32 [addr_add $dsm_base $DSM_DPD_LUT_COMMIT]]
    wr32 [addr_add $dsm_base $DSM_DPD_LUT_COMMIT] 0x00000001
    set bank_after [rd32 [addr_add $dsm_base $DSM_DPD_LUT_COMMIT]]
    if {[expr {$bank_before & 1}] == [expr {$bank_after & 1}]} {
        error "DPD_LUT_COMMIT did not toggle active bank"
    }
    puts "PASS DPD_LUT_ACTIVE_BANK = [hex32 $bank_after]"
} elseif {$dpd_mode != 0} {
    error "Unsupported DPD_MODE $dpd_mode"
}
wr32 [addr_add $dsm_base $DSM_DPD_CTRL] $dpd_mode
expect_eq DPD_CTRL_READBACK [rd32 [addr_add $dsm_base $DSM_DPD_CTRL]] $dpd_mode

wr32 [addr_add $dsm_base $DSM_CTRL] 0x00000004
wr32 [addr_add $dsm_base $DSM_CTRL] 0x00000002
wr32 [addr_add $dsm_base $DSM_CTRL] 0x00000001

if {$dma_bin eq "" || ![file exists $dma_bin]} {
    error "DMA_BIN is missing or does not exist. Generate fpga/zu15eg/p0_iq_dma_words.bin first."
}
puts "Downloading DMA source: $dma_bin"
dow -data $dma_bin $ddr_addr

wr32 [addr_add $dma_base $DMA_MM2S_DMACR] 0x00000004
after 100
poll_until DMA_RESET_CLEAR [addr_add $dma_base $DMA_MM2S_DMACR] 0x00000004 0x00000000 2000
wr32 [addr_add $dma_base $DMA_MM2S_DMACR] 0x00000001
wr32 [addr_add $dma_base $DMA_MM2S_SA] $ddr_addr
wr32 [addr_add $dma_base $DMA_MM2S_SA_MSB] 0x00000000
wr32 [addr_add $dma_base $DMA_MM2S_LENGTH] $dma_bytes
poll_until DMA_MM2S_DONE [addr_add $dma_base $DMA_MM2S_DMASR] 0x00000002 0x00000002 5000

set input_count [rd32 [addr_add $dsm_base $DSM_INPUT_SAMPLE_COUNT]]
set frontend_count [rd32 [addr_add $dsm_base $DSM_FRONTEND_SAMPLE_COUNT]]
set output_count [rd32 [addr_add $dsm_base $DSM_OUTPUT_SAMPLE_COUNT]]
set dpd_count [rd32 [addr_add $dsm_base $DSM_DPD_SAMPLE_COUNT]]
set stall_count [rd32 [addr_add $dsm_base $DSM_INPUT_STALL_COUNT]]
set error_status [rd32 [addr_add $dsm_base $DSM_ERROR_STATUS]]
set sat_count [rd32 [addr_add $dsm_base $DSM_DPD_SATURATION_COUNT]]

expect_eq INPUT_SAMPLE_COUNT $input_count $expected_samples
expect_eq FRONTEND_SAMPLE_COUNT $frontend_count $expected_samples
expect_eq DPD_SAMPLE_COUNT $dpd_count $expected_samples
expect_eq OUTPUT_SAMPLE_COUNT $output_count $expected_samples
expect_eq INPUT_STALL_COUNT $stall_count 0x00000000
expect_eq ERROR_STATUS $error_status 0x00000000
puts "DPD_SATURATION_COUNT = [hex32 $sat_count]"
puts "PASS ZU15EG DPD/DMA smoke completed."
