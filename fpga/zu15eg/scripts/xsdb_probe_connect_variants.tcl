proc show_targets {label} {
    puts "---- $label ----"
    catch {targets} msg
    puts $msg
    catch {targets -target-properties} msg2
    puts $msg2
}

catch {disconnect} msg
puts "disconnect: $msg"

catch {connect -url tcp:127.0.0.1:3121} msg
puts "connect url: $msg"
show_targets "after connect -url"

catch {disconnect} msg
puts "disconnect: $msg"

catch {connect -host 127.0.0.1 -port 3121} msg
puts "connect host/port: $msg"
show_targets "after connect -host/-port"

catch {disconnect} msg
puts "disconnect: $msg"

catch {connect} msg
puts "connect default: $msg"
show_targets "after connect default"
