# Thermo5 Block Verification

Block tests isolate one RTL module contract—arithmetic, local ready/valid,
reset, or status behavior—before combining blocks into a subsystem. Each
testbench and focused runner is kept under its block directory.

| Block | DUT scope | Local evidence |
|---|---|---|
| AXI/FIFO | 14:8 asynchronous FIFO/gearbox, reset, frame-power control | axis/tb/ and axis/run_xsim_*.ps1 |
| AXI-Lite DPD config | Register/control block and bundled-data mailbox, separate from DPD arithmetic | axil/tb/ standalone corner harnesses; external bus protocol test in dv/uvm/tests/thermo5/axil/ |
| DPD | Identity and memory-polynomial datapath boundaries | dpd/tb/ and VCS runners beside the block |
| Interpolation | Reachable x2 vector interpolation and backpressure | interp/tb/ and interp/run_xsim_*.ps1 |
| TID32 | One Cartesian Fs/4 modulator and raw-word handshake | tid32/tb/ and tid32/run_xsim_*.ps1 |
| GT user boundary | Continuous raw-word source behavior before the vendor GT | gt/tb/ and gt/run_xsim_*.ps1 |

The raw GT-user test is still a block test: it checks four-word alignment,
continuous consumption, idle data, and sticky missing-word/plane-mismatch
diagnostics. It does not model the serialized physical link.

Generated simulator products belong under ignored runs/, not beside RTL or test
sources. See BLOCK_SIGNOFF.md for exact scope limits and ../RUN_REGRESSION.md
for the command list.
