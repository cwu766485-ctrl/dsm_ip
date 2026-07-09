# Report AXI base addresses for the local ZU15EG block design.
#
# Usage:
#   vivado -mode batch -source fpga/zu15eg/scripts/report_bd_addresses.tcl \
#     -tclargs fpga/zu15eg/local_hw/pl_ps_gpio_test/pl_ps_gpio_test.xpr

if {$argc < 1} {
    puts "Usage: report_bd_addresses.tcl <vivado_project.xpr>"
    exit 1
}

set xpr [lindex $argv 0]
if {![file exists $xpr]} {
    puts "ERROR: Vivado project not found: $xpr"
    exit 1
}

open_project $xpr

set bds [get_files -quiet -filter {FILE_TYPE == "Block Designs"}]
if {[llength $bds] == 0} {
    puts "ERROR: no block design found in project"
    exit 1
}

foreach bd $bds {
    open_bd_design $bd
    puts "BD: [file tail $bd]"
    if {[catch {assign_bd_address} msg]} {
        puts "WARNING: assign_bd_address failed: $msg"
    }
    if {[catch {validate_bd_design} msg]} {
        puts "WARNING: validate_bd_design failed: $msg"
    }

    set segs [get_bd_addr_segs -quiet]
    foreach seg $segs {
        set path [get_property PATH $seg]
        set offset [get_property OFFSET $seg]
        set range [get_property RANGE $seg]
        if {[string match -nocase "*dsm_ip_0*" $path] || [string match -nocase "*axi_dma_0*" $path]} {
            puts [format "ADDR_SEG %-80s OFFSET=%s RANGE=%s" $path $offset $range]
        }
    }
}

close_project
