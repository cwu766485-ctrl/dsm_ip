# Read-only Design Compiler standard-cell library probe.
# Requires DSM_ASIC_STDCELL_DB to point at a permitted .db file.

if {![info exists ::env(DSM_ASIC_STDCELL_DB)] || $::env(DSM_ASIC_STDCELL_DB) eq ""} {
  error "DSM_ASIC_STDCELL_DB is required"
}

set stdcell_db [file normalize $::env(DSM_ASIC_STDCELL_DB)]
if {![file exists $stdcell_db]} {
  error "Standard-cell DB does not exist: $stdcell_db"
}

set report_dir [expr {[info exists ::env(DSM_ASIC_PROBE_DIR)] ? $::env(DSM_ASIC_PROBE_DIR) : [pwd]}]
file mkdir $report_dir

# Explicit loading makes the library object visible before target/link setup.
read_db $stdcell_db
set_app_var target_library [list $stdcell_db]
set_app_var link_library [concat "*" [get_app_var target_library]]

puts "STDCELL_PROBE_BEGIN db=$stdcell_db"
set lib_count 0
foreach_in_collection lib [get_libs *] {
  set lib_name [get_object_name $lib]
  set cells [get_lib_cells -quiet "$lib_name/*"]
  set inv_like [get_lib_cells -quiet "$lib_name/*INV*"]
  puts "STDCELL_PROBE_LIB name=$lib_name cells=[sizeof_collection $cells] inv_name_matches=[sizeof_collection $inv_like]"
  redirect -file "$report_dir/library_${lib_name}.rpt" { report_lib $lib_name }
  incr lib_count
}
puts "STDCELL_PROBE_RESULT libraries=$lib_count target_library=[get_app_var target_library]"
exit
