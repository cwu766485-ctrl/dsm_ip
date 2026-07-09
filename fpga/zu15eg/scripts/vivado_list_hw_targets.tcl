open_hw_manager
connect_hw_server -url 127.0.0.1:3121
puts "HW servers:"
puts [get_hw_servers]
puts "HW targets before open:"
puts [get_hw_targets *]
foreach t [get_hw_targets *] {
    puts "Opening target $t"
    if {[catch {open_hw_target $t} msg]} {
        puts "WARNING: open_hw_target failed for $t: $msg"
    }
}
puts "HW targets after open:"
puts [get_hw_targets *]
puts "HW devices:"
puts [get_hw_devices *]
close_hw_manager
