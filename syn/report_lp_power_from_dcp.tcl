if {[llength $argv] != 4} {
  error "usage: <routed_dcp> <saif> <strip_path> <output_report>"
}
set routed_dcp [file normalize [lindex $argv 0]]
set saif_file [file normalize [lindex $argv 1]]
set strip_path [lindex $argv 2]
set output_report [file normalize [lindex $argv 3]]
foreach required [list $routed_dcp $saif_file] {
  if {![file exists $required]} { error "required power input missing: $required" }
}
file mkdir [file dirname $output_report]
open_checkpoint $routed_dcp
read_saif -strip_path $strip_path $saif_file
report_power -file $output_report
puts "LP_POWER_REPORT=$output_report"
close_design
exit
