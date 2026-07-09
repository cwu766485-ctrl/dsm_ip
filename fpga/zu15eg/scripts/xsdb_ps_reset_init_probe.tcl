set psu_init_tcl [lindex $argv 0]

connect -url tcp:127.0.0.1:3121
puts "XSDB targets before reset:"
targets

if {[catch {targets -set -filter {name =~ "PSU"}} msg]} {
    puts "No PSU target: $msg"
    if {[catch {targets -set -filter {name =~ "DAP*"}} msg2]} {
        puts "No DAP target: $msg2"
    }
}
puts "Resetting ZynqMP system..."
catch {rst -cores} msg
puts "rst -cores: $msg"
catch {rst -processor} msg
puts "rst -processor: $msg"
after 2000

puts "Running PS init after reset: $psu_init_tcl"
source $psu_init_tcl
if {[catch {targets -set -filter {name =~ "PSU"}} msg]} {
    puts "No PSU target after reset: $msg"
    catch {targets -set -filter {name =~ "DAP*"}} msg2
    puts "DAP select after reset: $msg2"
}
psu_init
psu_ps_pl_isolation_removal
psu_ps_pl_reset_config

puts "PS init probe complete."
