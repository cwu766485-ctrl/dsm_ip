# Frozen thermo5 SpyGlass review

Run: `runs/thermo5_lint_delivery_20261006/`, SpyGlass V-2023.12-SP1,
`lint/lint_rtl`, top `thermo5_frozen_asic`. Configuration: interpolation 2,
DPD 1/identity, generic FIFO, low-power disabled. Memory threshold 32768
permits elaboration of the real 1024 x 17-bit TID state. No waivers applied.
Result: zero errors/blackboxes; 39 warnings, four synthesis warnings,
three informational records. This is an error-free lint execution with
explicit warning review, not a zero-warning or CDC signoff.

| Records | Finding | Disposition and evidence |
| --- | --- | --- |
| 0, 1, 2 | Redundant `$signed` on already signed expressions | Reviewed: retains the intended signed arithmetic; no functional fix needed. |
| 1B through 22 | STEP expression 32 bits into 17-bit offset | Reviewed for this SKU: +/-7168 and +/-21504 fit signed 17 bits. Function argument truncation is intentional existing semantics. Arbitrary STEP values are outside this review. |
| 8, 9 | CDC residual FSM next/state in one sequential block | Reviewed coding style; exact 7:4 scoped formal proves residual set, bound and parity; all seven state covers hit. |
| 23, 24 | Unconnected per-lane sample/saturation counters | Reviewed interface choice: UVM observes counters hierarchically; they are unused hardware diagnostics in this top and synthesis may remove them. |
| B through 1A | Repeated assignments in interpolation accumulation loops | Reviewed blocking combinational reduction, initialized before loop; independent MATLAB bit-true scoreboard and interval bound cover the selected 2-tap arithmetic. |
| 25, 26 | Power terms narrowed after arithmetic shift | Reviewed frozen identity only: nonlinear coefficients zero, so these values cannot affect the identity output. Existing truncation matches the bit-true model. No general calibrated-DPD overflow signoff inferred. |
| A, 27, 28, 7 | Unused FIFO empty/history/low-power diagnostics | Reviewed fixed elaboration and ready/valid use. MAX_TAPS=1 history is not consumed; low-power is disabled. |
| 29, 2A, 2B, 2C | Parameter-check initial blocks ignored by synthesis | Reviewed simulation elaboration guards, no synthesized state or required initialization. |
| 31 | FIFO reset also gates non-reset memory write enable | OPEN physical RDC/timing review. Memory is intentionally not reset, writes are suppressed during reset. Scoped behavioral proof is not analog reset-release timing. |
| 30 | Core reset also gates DPD history memory enable | OPEN physical RDC/timing review; selected one-tap history is unused, but a generic source-level reset-use warning is retained. |
| 4, 3, 6 | Top/elaboration/signal-use informational reports | Retained, no suppression. |

The source filelist previously omitted `gt_tx_user_bridge.sv` and
`gt_tx_raw64_boundary.sv`; adding the actual sources removed the unresolved
reference, without blackboxing it. Original configurable 4/4 tops remain.

Reproduce using `THERMO5_LINT_RUN` set to a new `runs/` directory, then
`sg_shell -tcl dv/uvm/sim/run_thermo5_spyglass.tcl` and
`python3.12 tools/hw/thermo5_lint_summary.py "$THERMO5_LINT_RUN/moresimple.rpt"`.
