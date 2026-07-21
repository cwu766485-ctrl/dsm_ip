if {$argc < 1} {
    error "Usage: report_ps_uart_config.tcl <project.xpr>"
}

open_project [file normalize [lindex $argv 0]]
set bd_files [get_files -quiet *.bd]
if {[llength $bd_files] == 0} {
    error "No block design found in project"
}

open_bd_design [lindex $bd_files 0]
set ps_cells [get_bd_cells -quiet -filter {VLNV =~ "xilinx.com:ip:zynq_ultra_ps_e:*"}]
if {[llength $ps_cells] == 0} {
    error "No Zynq UltraScale+ PS cell found"
}

set ps [lindex $ps_cells 0]
puts "PS_CELL=$ps"
foreach property [lsort [list_property $ps]] {
    if {[string match "*UART*" $property]} {
        puts "$property=[get_property $property $ps]"
    }
}
close_project
