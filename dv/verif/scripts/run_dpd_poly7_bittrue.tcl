# Run inside a launched Vivado GUI Tcl console when the command-line launcher
# is unavailable. MATLAB vectors must already exist under matlab/out/dpd/bittrue.
# xvlog/xelab/xsim are OS executables, not Vivado Tcl commands.  Use cmd.exe
# explicitly so this works from the GUI Tcl Console on Windows.

set script_dir [file dirname [file normalize [info script]]]
set repo [file normalize [file join $script_dir .. ..]]
set work [file join $repo verif out_xsim_dpd]
set vec_dir [file join $repo matlab out dpd bittrue]

file mkdir $work
file copy -force [file join $vec_dir dpd7_input_iq.csv] [file join $work dpd7_input_iq.csv]
file copy -force [file join $vec_dir dpd7_expected_iq.csv] [file join $work dpd7_expected_iq.csv]
file copy -force [file join $vec_dir dpd7_coefficients.csv] [file join $work dpd7_coefficients.csv]
cd $work

set poly [file join $repo rtl dpd dpd_poly.v]
set lut [file join $repo rtl dpd dpd_lut.v]
set memory [file join $repo rtl dpd dpd_memory_poly.v]
set frontend [file join $repo rtl dpd dpd_frontend.v]
set tb [file join $repo verif tb tb_dpd_poly7_bittrue.sv]
set tb_protocol [file join $repo verif tb tb_dpd_frontend_protocol.sv]

if {![info exists ::env(XILINX_VIVADO)]} {
  error "XILINX_VIVADO is not set. Launch the Tcl Console from Vivado 2024.1."
}
set bin_dir [file join $::env(XILINX_VIVADO) bin]
set xvlog [file join $bin_dir xvlog.bat]
set xelab [file join $bin_dir xelab.bat]
set xsim [file join $bin_dir xsim.bat]

proc run_xsim_tool {tool args} {
  set cmd [concat [list $tool] $args]
  puts "RUN: $cmd"
  if {[catch {exec cmd.exe /c {*}$cmd 2>@1} output options]} {
    puts stderr $output
    return -options $options $output
  }
  if {$output ne ""} { puts $output }
  if {[string match "*Fatal:*" $output] || [string match "*ERROR:*" $output]} {
    error "XSim reported a failure while running $tool"
  }
}

file delete -force [file join $work xsim.dir]
run_xsim_tool $xvlog -sv -d DPD_SIM_TRACE $poly $tb
run_xsim_tool $xelab -debug typical tb_dpd_poly7_bittrue -s sim_tb_dpd_poly7_bittrue
run_xsim_tool $xsim sim_tb_dpd_poly7_bittrue -runall

# This directed protocol test covers reset, backpressure, unsafe commit reject,
# and safe bank commit. It does not require MATLAB output files.
run_xsim_tool $xvlog -sv $poly $lut $memory $frontend $tb_protocol
run_xsim_tool $xelab -debug typical tb_dpd_frontend_protocol -s sim_tb_dpd_frontend_protocol
run_xsim_tool $xsim sim_tb_dpd_frontend_protocol -runall

if {![file exists [file join $work dpd7_rtl_iq.csv]]} {
  error "XSim completed without creating dpd7_rtl_iq.csv"
}
puts "DPD seventh-order XSim complete: [file join $work dpd7_rtl_iq.csv]"
