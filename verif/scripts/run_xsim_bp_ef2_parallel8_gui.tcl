# Run the eight-lane BP EFDSM2 directed simulation from Vivado Tcl Console.
# Execute from the repository root:
#   source verif/scripts/run_xsim_bp_ef2_parallel8_gui.tcl
#
# The CSV must already exist at:
#   verif/out_xsim_bp_dsm_parallel8/bp_ef2_parallel8_vectors.csv
set repo [file normalize [file join [file dirname [file normalize [info script]]] .. ..]]
set work [file join $repo verif out_xsim_bp_dsm_parallel8]
set rtl [file join $repo rtl tx_bandpass_if bp_ef2_parallel8.sv]
set tb [file join $repo verif block bp_dsm tb tb_bp_ef2_parallel8.sv]
file mkdir $work
cd $work
create_project -in_memory -part xczu15eg-ffvb1156-2-i
add_files -norecurse $rtl
add_files -fileset sim_1 -norecurse $tb
set_property top tb_bp_ef2_parallel8 [get_filesets sim_1]
set_property simulator_language Verilog [current_project]
launch_simulation -simset sim_1 -mode behavioral
run all
