# Structural CDC/RDC on the isolated runtime candidate, Generic FIFO only.
set root $::env(ABORT_STATIC_ROOT)
set out $::env(ABORT_STATIC_OUT)
new_project $out/abort_runtime.prj
set_option enableSV yes
set_option top tid32_thermo5_runtime_tx
set_option param tid32_thermo5_runtime_tx.FPGA_USE_XPM_FIFO=0
set_option mthresh 32768
set fd [open $root/dv/uvm/sim/thermo5_sku_filelist.f r]
foreach line [split [read $fd] \n] {
 if {[string match rtl/* $line]} {read_file -type verilog $root/$line}
}
close $fd
read_file -type sgdc $::env(ABORT_STATIC_SGDC)
current_goal $::env(ABORT_STATIC_GOAL)
run_goal
write_report moresimple > $out/moresimple.rpt
exit
