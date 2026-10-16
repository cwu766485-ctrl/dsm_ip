# AXI, FIFO, and Reset Blocks

`tb/` holds tests for the AXI ingress, asynchronous FIFO, frame-power
controller, and reset synchronizers. Generic and XPM FIFO testbenches are
separate so the vendor FIFO model is explicit.

Focused XSim runners are in `dv/verif/scripts/`; reset-release runners are next
to the block. All outputs go under ignored `runs/` directories.
