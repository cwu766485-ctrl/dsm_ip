create_project -force query_props [file normalize [file join [pwd] fpga query_props]] -part xczu15eg-ffvb1156-2-i
report_property [get_runs synth_1]
close_project
exit
