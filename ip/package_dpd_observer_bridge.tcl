# Package the dual-clock observer bridge as a companion IP.
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set work_dir [file normalize [file join $script_dir "build" "observer_bridge_pack"]]
set ip_dir [file normalize [file join $script_dir "ip_repo" "dpd_observer_async_bridge_1_0"]]
set part "xczu15eg-ffvb1156-2-i"

file delete -force $work_dir
file delete -force $ip_dir
file mkdir $work_dir
file mkdir $ip_dir

create_project dpd_observer_bridge_pack $work_dir -part $part
add_files -norecurse [file join $repo_root rtl dpd dpd_observer_async_bridge.v]
set_property top dpd_observer_async_bridge [get_filesets sources_1]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $ip_dir -vendor dsm.local -library communication \
  -taxonomy /UserIP -import_files -force
set core [ipx::current_core]
set_property name dpd_observer_async_bridge $core
set_property display_name {DPD Observation AXI-Stream Asynchronous Bridge} $core
set_property description {Dual-clock AXI-Stream feedback bridge for DPD observation I/Q, tlast, and invalid-sample marker transport.} $core
set_property version 1.0 $core
set_property supported_families {zynquplus Production zynq Production} $core
ipx::update_checksums $core
ipx::save_core $core
close_project
puts "Packaged DPD observer bridge IP: [file join $ip_dir component.xml]"
