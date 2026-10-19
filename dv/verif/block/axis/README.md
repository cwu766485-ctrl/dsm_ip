# AXI, FIFO, and Reset Blocks

`tb/` holds tests for the AXI ingress, asynchronous FIFO, frame-power
controller, and reset synchronizers. Generic and XPM FIFO testbenches are
separate so the vendor FIFO model is explicit.

Focused XSim runners are next to this block's testbenches. The older
`dv/verif/scripts/` command paths remain as compatibility shims. All outputs
go under ignored `runs/` directories.
