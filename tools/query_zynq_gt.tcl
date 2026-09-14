# Query the transceiver sites of a selected Zynq UltraScale+ part.
# A tiny synthesized design is used because Vivado does not expose device
# sites through get_sites until a design context is open.

set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
set part [expr {[llength $argv] > 0 ? [lindex $argv 0] : "xczu15eg-ffvb1156-2-i"}]

create_project -in_memory -part $part
read_verilog -sv [file join $root tools gt_query_dummy.sv]
synth_design -top gt_query_dummy -part $part -mode out_of_context

puts "GT_QUERY_PART=$part"
set gts [get_sites -filter {SITE_TYPE =~ GT*}]
puts "GT_QUERY_SITE_COUNT=[llength $gts]"
puts "GT_QUERY_SITE_TYPES=[lsort -unique [get_property SITE_TYPE $gts]]"
puts "GT_QUERY_SITE_SAMPLE=[lrange $gts 0 31]"
set channels [get_sites -filter {SITE_TYPE == GTHE4_CHANNEL}]
set commons [get_sites -filter {SITE_TYPE == GTHE4_COMMON}]
puts "GT_QUERY_CHANNEL_COUNT=[llength $channels]"
puts "GT_QUERY_COMMON_COUNT=[llength $commons]"

set gt_cells [get_cells -hier -filter {REF_NAME =~ GT*}]
puts "GT_QUERY_INSTANTIATED_GT_CELLS=[llength $gt_cells]"
puts "GT_QUERY_DONE"
close_project
exit
