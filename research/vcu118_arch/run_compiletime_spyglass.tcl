# Exact compile-time EF1/MASH product CDC or RDC run. No waivers are loaded.
foreach env_name {THERMO5_CTIME_ROOT THERMO5_CTIME_OUT THERMO5_CTIME_ARCH THERMO5_CTIME_GOAL} {
  if {![info exists ::env($env_name)]} {error "missing $env_name"}
}
set root [file normalize $::env(THERMO5_CTIME_ROOT)]
set out [file normalize $::env(THERMO5_CTIME_OUT)]
set arch $::env(THERMO5_CTIME_ARCH)
set goal $::env(THERMO5_CTIME_GOAL)
set use_xpm 1
if {[info exists ::env(THERMO5_CTIME_XPM)]} {set use_xpm $::env(THERMO5_CTIME_XPM)}
if {$use_xpm ni {0 1}} {error "THERMO5_CTIME_XPM must be 0 or 1"}
if {$arch ni {0 2}} {error "only EF1 (0) and MASH 1-1 (2) are in this closure run"}
if {![string match "cdc/*" $goal] && ![string match "rdc/*" $goal]} {
  error "expected a CDC or RDC goal, got $goal"
}
if {[file exists $out]} {error "refusing to overwrite existing run directory: $out"}
file mkdir $out
new_project $out/thermo5_compiletime.prj
set_option enableSV yes
set_option enableSV09 yes
# AMD XPM marks simulation-only code with the synthesis pragma family.
set_option pragma {synopsys synthesis}
set_option top tid32_thermo5_compiletime_tx
set_option param tid32_thermo5_compiletime_tx.DSM_ARCH=$arch
set_option param tid32_thermo5_compiletime_tx.FPGA_USE_XPM_FIFO=$use_xpm
set_option mthresh 32768

if {$use_xpm} {
  set vivado [file normalize $::env(VIVADO_ROOT)]
  foreach xpm {xpm_cdc xpm_memory xpm_fifo} {
    read_file -type verilog [file join $vivado data ip xpm $xpm hdl ${xpm}.sv]
  }
}
set fd [open [file join $root dv uvm sim thermo5_sku_filelist.f] r]
foreach line [split [read $fd] \n] {
  set line [string trim $line]
  if {[string match rtl/* $line]} {read_file -type verilog [file join $root $line]}
}
close $fd
read_file -type sgdc [file join $root research vcu118_arch compiletime_product.sgdc]
current_goal $goal
run_goal
write_report moresimple > [file join $out moresimple.rpt]
exit
