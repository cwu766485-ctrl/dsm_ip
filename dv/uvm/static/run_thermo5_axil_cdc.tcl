set root $::env(THERMO5_STATIC_ROOT)
set out $::env(THERMO5_STATIC_OUT)
new_project $out/thermo5_axil.prj
set_option enableSV yes
set_option top tid32_thermo5_axi_lite_axis_frontend_tx
set_option param tid32_thermo5_axi_lite_axis_frontend_tx.DPD_MAX_TAPS=1
set_option param tid32_thermo5_axi_lite_axis_frontend_tx.FPGA_USE_XPM_FIFO=0
set_option mthresh 32768
set fd [open $root/dv/uvm/sim/thermo5_sku_filelist.f r]
foreach line [split [read $fd] \n] {
 if {[string match rtl/* $line]} {read_file -type verilog $root/$line}
}
close $fd
read_file -type sgdc $root/dv/uvm/static/thermo5_axil_generic.sgdc
current_goal $::env(THERMO5_STATIC_GOAL)
run_goal
write_report moresimple > $out/moresimple.rpt
exit
