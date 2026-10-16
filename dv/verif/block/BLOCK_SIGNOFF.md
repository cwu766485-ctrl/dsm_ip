# Thermo5 Block Verification Scope

This is a test-to-block index, not a blanket signoff claim. A block-level pass
does not replace the full-chain MATLAB/UVM comparison, CDC/RDC analysis, routed
timing, or physical GT/board validation.

| Block | Focused evidence | Limits |
|---|---|---|
| AXI/FIFO | Generic and real-XPM 14:8 FIFO/gearbox tests; independent reset and frame-power tests | Simulation checks function/order, not metastability or system CDC/RDC closure |
| DPD | Signed-endpoint identity sweep, Memory-Poly bit-true unit test, ready/backpressure protocol test | Frozen thermo5 UVM oracle covers identity coefficients; this does not validate nonlinear PA linearization |
| Interpolation | Directed x2 reachable-state test with bubbles and output stalls | Scope is the selected x2 polyphase RTL, not all interpolation SKUs |
| TID32 | Single-branch Cartesian TID/Fs4 bit-true test | Four-branch synchronization is checked at subsystem/IP level |
| Raw GT-user word | 64-bit continuous-valid behavior test and behavioral loopback | No physical GT primitive, serial lane, RX deskew, or board output is present |
| AXI-Lite DPD config/mailbox | Standalone config-block reset/request/pending overlap tuples in `dv/uvm/tb/thermo5_axil_cfg_coverage_tb.sv`; AXI bus/register behavior is exercised in wrapper-integrated UVM | The standalone harness intentionally probes internal state for two reset-overlap tuples; it is not a full AXI protocol test or system CDC/RDC signoff |

Run focused tests from the repository root using `../RUN_REGRESSION.md`. The
full thermo5 UVM source, MATLAB golden-vector comparison, and coverage records
are maintained under `dv/uvm/` and `docs/verification/`.
