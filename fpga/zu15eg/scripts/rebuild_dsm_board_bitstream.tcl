# Rebuild the local ZU15EG DSM validation bitstream after DSM IP changes.
#
# Usage:
#   vivado -mode batch -source fpga/zu15eg/scripts/rebuild_dsm_board_bitstream.tcl \
#     -tclargs fpga/zu15eg/local_hw/pl_ps_gpio_test/pl_ps_gpio_test.xpr 2 0

if {$argc < 1 || $argc > 3} {
    puts "Usage: rebuild_dsm_board_bitstream.tcl <vivado_project.xpr> ?algorithm? ?interp_mode?"
    exit 1
}

set xpr [file normalize [lindex $argv 0]]
set algorithm [expr {$argc >= 2 ? [lindex $argv 1] : 2}]
set interp_mode [expr {$argc >= 3 ? [lindex $argv 2] : 0}]
if {![file exists $xpr]} {
    puts "ERROR: Vivado project not found: $xpr"
    exit 1
}
if {$algorithm < 0 || $algorithm > 13} {
    puts "ERROR: algorithm must be in the range 0 to 13"
    exit 1
}
if {$interp_mode < 0 || $interp_mode > 4} {
    puts "ERROR: interp_mode must be in the range 0 to 4"
    exit 1
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".." ".."]]
set ip_repo [file normalize [file join $repo_root "ip" "ip_repo"]]

open_project $xpr
set_property ip_repo_paths [list $ip_repo] [current_project]
update_ip_catalog

set ips [get_ips -quiet *dsm_ip*]
if {[llength $ips] == 0} {
    puts "ERROR: no DSM IP instance found in project"
    exit 1
}

puts "DSM IP instances: $ips"
foreach ip $ips {
    puts "Upgrading IP: $ip"
    if {[catch {upgrade_ip $ip} msg]} {
        puts "WARNING: upgrade_ip failed for $ip: $msg"
    }
}

set bds [get_files -quiet -filter {FILE_TYPE == "Block Designs"}]
foreach bd $bds {
    open_bd_design $bd
    set dsm_cells [get_bd_cells -quiet *dsm_ip*]
    foreach cell $dsm_cells {
        puts "Configuring DSM IP cell $cell: ALGORITHM=$algorithm INTERP_MODE=$interp_mode"
        if {[catch {
            set_property -dict [list \
                CONFIG.C_S_AXI_ADDR_WIDTH {9} \
                CONFIG.ALGORITHM $algorithm \
                CONFIG.INTERP_MODE $interp_mode \
            ] $cell
        } msg]} {
            puts "ERROR: failed to configure DSM IP cell $cell: $msg"
            exit 1
        }
    }
    puts "Regenerating BD targets: [file tail $bd]"
    if {[catch {generate_target all [get_files $bd]} msg]} {
        puts "WARNING: generate_target failed: $msg"
    }
}

update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "ERROR: synth_1 did not complete"
    exit 1
}
if {[get_property STATUS [get_runs synth_1]] ni {"synth_design Complete!" "Synth Design Complete!"}} {
    puts "ERROR: synth_1 status: [get_property STATUS [get_runs synth_1]]"
    exit 1
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    puts "ERROR: impl_1 did not complete"
    exit 1
}

set impl_status [get_property STATUS [get_runs impl_1]]
puts "impl_1 status: $impl_status"
if {![string match -nocase "*write_bitstream*Complete*" $impl_status] && ![string match -nocase "*Complete*" $impl_status]} {
    puts "ERROR: impl_1 status: $impl_status"
    exit 1
}

close_project
puts "PASS rebuilt local ZU15EG DSM bitstream (ALGORITHM=$algorithm INTERP_MODE=$interp_mode)"
