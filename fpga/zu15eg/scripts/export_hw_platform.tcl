set project_path $::env(ZU15EG_PROJECT)
set out_xsa $::env(ZU15EG_OUT_XSA)

if {![file exists $project_path]} {
    error "Project not found: $project_path"
}

open_project $project_path

set impl_run [current_run -implementation]
if {$impl_run eq ""} {
    set impl_run impl_1
}

set run_dir [get_property DIRECTORY [get_runs $impl_run]]
set bit_file [file join $run_dir top.bit]
if {![file exists $bit_file]} {
    puts "WARNING: bitstream not found at $bit_file; exporting hardware without embedded bitstream"
    write_hw_platform -fixed -force $out_xsa
} else {
    puts "Using bitstream: $bit_file"
    write_hw_platform -fixed -include_bit -force $out_xsa
}

close_project
