# Pin/site audit against public VCU118 UG1224 bank231 pin assignments.
create_project -in_memory -part xcvu9p-flga2104-2L-e
set_property design_mode PinPlanning [get_filesets sources_1]
open_io_design -name io_1
foreach pin {V7 V6 Y2 Y1 T7 T6 W4 W3 W9 W8} {
 set p [get_package_pins -quiet $pin]
 puts "PIN_AUDIT pin=$pin sites=[get_sites -quiet -of_objects $p] function=[get_property PIN_FUNC $p] bank=[get_property BANK $p]"
}
