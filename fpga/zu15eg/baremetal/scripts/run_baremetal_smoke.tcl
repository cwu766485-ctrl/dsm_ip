# Download and run the ZU15EG bare-metal DSM DPD smoke application.
#
# Required environment variables:
#   ELF_FILE      Built bare-metal ELF
#
# Optional environment variables:
#   PSU_INIT_TCL  Generated psu_init.tcl
#   BIT_FILE      Bitstream to program when PROGRAM_BIT=1
#   PROGRAM_BIT   1 to program BIT_FILE before running, default 0

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

set elf_file [require_env ELF_FILE]
set psu_init_tcl [env_or_default PSU_INIT_TCL ""]
set bit_file [env_or_default BIT_FILE ""]
set program_bit [expr {[env_or_default PROGRAM_BIT 0]}]

if {![file exists $elf_file]} {
    error "ELF_FILE does not exist: $elf_file"
}

puts "ZU15EG bare-metal smoke launch"
puts "ELF_FILE     = $elf_file"
puts "BIT_FILE     = $bit_file"
puts "PSU_INIT_TCL = $psu_init_tcl"
puts "PROGRAM_BIT  = $program_bit"

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

set a53_targets [targets -filter {name =~ "*Cortex-A53 #0*"}]
if {[llength $a53_targets] == 0} {
    error "no Cortex-A53 #0 target found"
}

targets -set [lindex $a53_targets 0]
puts "Selected target: [lindex $a53_targets 0]"
rst -processor
after 100
dow $elf_file
puts "Starting ELF. Watch the PS UART terminal for xil_printf output."
con
after 3000
puts "PASS ELF launched."
