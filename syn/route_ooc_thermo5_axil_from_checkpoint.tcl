# Memory-bounded, checkpoint-resumable route for the optional thermo5 AXI-Lite
# wrapper.  This is an internal-path timing study, not parent I/O signoff.
if {[llength $argv] ni {3 4 5 6}} {
  error "usage: <input_checkpoint.dcp> <out_dir> <synth|optimized|placed|physopt> ?Default|RuntimeOptimized|Quick? ?no_psir_0_or_1? ?stop_after_physopt_0_or_1?"
}

set checkpoint [file normalize [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
set resume_from [lindex $argv 2]
set route_directive Default
if {[llength $argv] >= 4} { set route_directive [lindex $argv 3] }
set route_no_psir 0
if {[llength $argv] >= 5} { set route_no_psir [lindex $argv 4] }
set stop_after_physopt 0
if {[llength $argv] == 6} { set stop_after_physopt [lindex $argv 5] }
if {$resume_from ni {synth optimized placed physopt}} {
  error "resume stage must be synth, optimized, placed, or physopt"
}
if {$route_directive ni {Default RuntimeOptimized Quick}} {
  error "unsupported route directive: $route_directive"
}
if {$route_no_psir ni {0 1}} { error "no_psir must be 0 or 1" }
if {$stop_after_physopt ni {0 1}} { error "stop_after_physopt must be 0 or 1" }
if {![file exists $checkpoint]} { error "checkpoint not found: $checkpoint" }
file mkdir $out_dir
cd $out_dir

set_param general.maxThreads 1
open_checkpoint $checkpoint
set design [current_design]
foreach clock_name {s_axis_aclk core_clk s_axil_aclk} {
  if {[llength [get_clocks -quiet $clock_name]] == 0} {
    error "checkpoint is missing expected clock: $clock_name"
  }
}
puts "THERMO5_AXIL_ROUTE_INPUT=$checkpoint"
puts "THERMO5_AXIL_ROUTE_RESUME_FROM=$resume_from"
puts "THERMO5_AXIL_ROUTE_DESIGN=$design"
puts "THERMO5_AXIL_ROUTE_DIRECTIVE=$route_directive"
puts "THERMO5_AXIL_ROUTE_NO_PSIR=$route_no_psir"
puts "THERMO5_AXIL_STOP_AFTER_PHYSOPT=$stop_after_physopt"

if {$resume_from eq "synth"} {
  opt_design
  write_checkpoint -force [file join $out_dir optimized.dcp]
  puts "THERMO5_AXIL_ROUTE_STAGE=optimized_checkpoint_saved"
}

if {$resume_from in {synth optimized}} {
  place_design
  write_checkpoint -force [file join $out_dir placed.dcp]
  puts "THERMO5_AXIL_ROUTE_STAGE=placed_checkpoint_saved"

  phys_opt_design
  write_checkpoint -force [file join $out_dir physopt.dcp]
  puts "THERMO5_AXIL_ROUTE_STAGE=physopt_checkpoint_saved"
} elseif {$resume_from eq "placed"} {
  phys_opt_design
  write_checkpoint -force [file join $out_dir physopt.dcp]
  puts "THERMO5_AXIL_ROUTE_STAGE=physopt_checkpoint_saved"
}

if {$stop_after_physopt} {
  report_timing_summary -max_paths 30 -report_unconstrained \
    -file [file join $out_dir physopt_timing_summary.rpt]
  report_timing -max_paths 30 \
    -file [file join $out_dir physopt_timing_paths.rpt]
  report_utilization -file [file join $out_dir physopt_utilization.rpt]
  puts "THERMO5_AXIL_ROUTE_STAGE=physopt_checkpoint_ready"
  exit 0
}

if {$route_no_psir} {
  if {$route_directive eq "Default"} {
    route_design -no_psir
  } else {
    route_design -directive $route_directive -no_psir
  }
} elseif {$route_directive eq "Default"} {
  route_design
} else {
  route_design -directive $route_directive
}
puts "THERMO5_AXIL_ROUTE_STAGE=route_complete"
write_checkpoint -force [file join $out_dir routed.dcp]
report_timing_summary -max_paths 30 -report_unconstrained \
  -file [file join $out_dir timing_summary.rpt]
report_timing -max_paths 30 -file [file join $out_dir timing_max_paths.rpt]
report_clock_interaction -file [file join $out_dir clock_interaction.rpt]
check_timing -verbose -file [file join $out_dir check_timing.rpt]
report_route_status -file [file join $out_dir route_status.rpt]
report_utilization -file [file join $out_dir utilization.rpt]

set setup [get_timing_paths -delay_type max -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup] == 0 || [llength $hold] == 0} {
  error "No setup/hold timing path reported"
}
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
if {$wns < 0.0} {
  set status FAIL_SETUP
} elseif {$whs < 0.0} {
  set status FAIL_HOLD
} else {
  set status PASS
}
set f [open [file join $out_dir summary.csv] w]
puts $f "Top,Core_MHz,Axil_MHz,Implementation,Status,WNS_ns,WHS_ns"
set impl_tag "checkpoint_resume_$route_directive"
if {$route_no_psir} { append impl_tag "_no_psir" }
puts $f "tid32_thermo5_axi_lite_axis_frontend_tx,218.75,100.00,$impl_tag,$status,[format %.3f $wns],[format %.3f $whs]"
close $f
puts "THERMO5_AXIL_ROUTE_STATUS=$status WNS=$wns WHS=$whs"
exit 0
