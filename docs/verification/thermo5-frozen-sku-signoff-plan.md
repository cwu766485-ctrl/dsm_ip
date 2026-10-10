# Thermo5 frozen-SKU verification plan

Updated: 2026-10-08. Scope: the digital thermo5 transmitter SKU with
`INTERP_TAPS=2`, `DPD_MAX_TAPS=1`, `BYPASS_DPD=0`, identity DPD coefficients,
125-MHz AXI ingress, 218.75-MHz core, and either the generic or Vivado XPM
asynchronous FIFO. The UVM top is
`dv/uvm/tb/thermo5_sku_uvm_tb.sv`; the filelist is
`dv/uvm/sim/thermo5_sku_filelist.f`.

One legal frame accepts 32 beats of 14 complex samples (448 samples) and
produces 56 ordered words on four 64-bit PA planes. MATLAB-generated `.mem`
files are the independent oracle. The UVM scoreboard checks each accepted
source beat and each accepted four-plane output word. A passing test is not
equivalent to code-coverage closure, CDC/RDC signoff, GT link closure, or
board-level validation. The latest bin-level coverage authority is
[`thermo5-reachability-closure-20261008.md`](thermo5-reachability-closure-20261008.md).

## Requirement-to-evidence matrix

| ID | Requirement | Existing stimulus | Checker / assertion | Functional bin or count | Evidence and status |
| --- | --- | --- | --- | --- | --- |
| AXI-01 | Hold valid and all payload/user fields stable while `valid && !ready`; count accepted beats only on handshake. | `thermo5_sku_fifo_boundary_test`; normal and bubble cases. | `thermo5_source_monitor`: `AXIS_STABLE`; accepted-beat monitor and `write_src()` compare data, frame start, and gain. | `source_cg.cp_stalled.backpressured`; `source.monitor.stall_cycles`. | Seven-case generic and XPM logs under their respective run roots pass; FIFO-boundary test requires nonzero stall count. PASS for tested source backpressure. |
| CDC-01 | Preserve lane-0-first sample order across the 14:8 gearbox and asynchronous FIFO; legal residual sequence only. | Bit-true, FIFO-boundary, FIFO-empty, reset/replay, and reset-sweep tests. | `thermo5_pa_scoreboard`: 32 accepted source beats and 56 ordered MATLAB-matched words on each plane. RTL assertions check legal residual count, frame alignment, and output hold. | `source_cg.cp_full.full`; `core_cg.cp_underflow.empty`; scoreboard counts `source_checked=32`, `checked=56`. | Generic and XPM seven-case baselines PASS. The exact gearbox order is checked end-to-end; occupancy-state-specific functional coverage is not separately closed. |
| FIFO-01 | Exercise FIFO full/backpressure and empty/starvation behavior. | `thermo5_sku_fifo_boundary_test`; `thermo5_sku_fifo_empty_test`. | Full case checks accepted beat/output counts after recovery. Empty case checks seven matched words, sticky underflow, and no frame protocol error. | `source_cg.cp_full.full`, `source_cg.cp_stalled.backpressured`, `core_cg.cp_underflow.empty`; `fifo_full_cycles`, `source_stall_cycles`, `underflow_cycles`. | Generic and XPM seven-case logs PASS. Underflow is intentional in the negative starvation scenario only. |
| RST-01 | Flush partial data and start a new scoreboard comparison epoch after reset. | `thermo5_sku_reset_test`; `thermo5_sku_reset_sweep_test` at residuals 2, 4, 6, 10, and 12. | Scoreboard resets source/output indices on reset; tests require reset epoch counts and a complete fresh 32/56 replay. | `source_cg.cp_reset.reset`; `coverage.reset_reassertions`; `scoreboard.reset_epochs`. | Generic and XPM reset/replay logs PASS. This verifies the common two-reset epoch used by the UVM BFM. |
| RST-02 | Exercise source and core reset requests independently, including release ordering and XPM common-reset response. | UVM BFM currently calls `reset_both()` and asserts both together. A separate XPM FIFO reset testbench exists under `dv/verif/block/axis/`. | Directed FIFO reset test and per-instance reset synchronizers; path-specific RDC remains separate. | UVM `cp_reset` does not distinguish independent reset requests. | OPEN in the full-chain UVM plan. Do not infer independent-reset closure from simultaneous UVM reset or generic/XPM bit-true results. |
| INT-01 | Exercise the first x2 interpolation stage under bubbles and downstream blocking. | `thermo5_sku_bubble_backpressure_test` with source valid gap and PA stalls. | Observation-only counters check stage holds; MATLAB scoreboard still drains all 56 words. | `interp1_hits`, `interp1_stage1_empty_hits`, `interp1_stage0_hits`, `interp1_output_hold_hits`. | Bubble test passes in both FIFO variants. The current generic exact URG retains four interpolation line/branch bins: valid-payload bounds do not establish coverage for invalid startup payload evaluation. Keep them OPEN pending targeted legal stimulus or scoped proof. |
| INT-02 | Exercise the second x2 interpolation stage and preserve order through its backpressure. | `thermo5_sku_bubble_backpressure_test`. | Observation-only counters plus four-plane MATLAB scoreboard. | `interp2_hits`, `interp2_stage1_empty_hits`, `interp2_output_hold_hits`. | Latest generic and XPM bubble logs show nonzero observations and 56 checked words. Other uncovered instance conditions remain in the URG inventories; no blanket interpolation closure. |
| GAIN-01 | Apply frame gain only at the required frame boundary and preserve metadata across the FIFO/gearbox. | Bit-true, reset/replay, and bubble tests use MATLAB frame-start/gain vectors. | `thermo5_pa_scoreboard.write_src()` compares every accepted beat's `frame_start` and `frame_gain`; output comparison checks resulting samples. | `source_cg.cp_start.frame`; `coverage.frame_starts` (expected 3). | Existing generic/XPM seven-case baselines PASS. The event bin counts frame starts; value correctness is checked by the source metadata comparison and output oracle. |
| DPD-01 | Verify the frozen one-tap identity DPD over signed endpoint inputs; retain exact four-plane behavior. | Extreme-vector MATLAB payload, bit-true test with `+EXPECT_SIGNED_EXTREMES`. | Source monitor measures accepted input endpoints; scoreboard checks all 56 words against the matching MATLAB oracle. Independent identity-domain RTL sweep is documented in `thermo5-uvm-coverage.md`. | `source_cg.cp_signed_min.present`; `source_cg.cp_signed_max.present`; `signed_min_beats`, `signed_max_beats`. | New one-case runs PASS for generic seed 606101 and XPM seed 606102; both observed 32 min-hit beats and 32 max-hit beats, 32 source beats, 56 words, and zero UVM errors/fatals. These are separate one-case VDBs and were not merged into the seven-case code-coverage reports. |
| PA-01 | Keep all four `pa_valid` bits aligned and check plane ordering/alignment word by word. | Bit-true and bubble tests. | `thermo5_pa_monitor` rejects divergent plane-valid bits; scoreboard compares all four plane values at the same accepted word index. | `core_cg.cp_pa_word.four_plane_word`; `coverage.pa_words` (expected 56). | Generic and XPM seven-case baselines PASS with 56 ordered words on each plane. |
| PA-02 | Hold output valid and all four data planes stable during PA backpressure. | `thermo5_sku_bittrue_test` with ready stress; bubble and FIFO-boundary tests. | `thermo5_pa_monitor`: `STALL_VALID` and `STALL_DATA`; test requires a nonzero output stall where configured. | `core_cg.cp_pa_stall.stalled`; `monitor.stall_cycles`; `coverage.pa_stall_cycles`. | Generic/XPM regression includes PA stalls; latest XPM extreme one-case also observed source stalls but no PA stalls. Keep source and PA stall evidence distinct. |
| ERR-01 | Reject a frame start not aligned to the 56-sample boundary. | `thermo5_sku_illegal_frame_test`. | Expected RTL `$error` text plus sticky `protocol_error` observation; the negative test is not required to drain a PA golden frame. | `core_cg.cp_illegal.bad_frame`; `coverage.protocol_error_cycles`. | Both seven-case regressions include the expected negative assertion and zero UVM errors/fatals. Treat the assertion failure as expected only in this named test. |
| STOP-01 | Stop processing into idle and recover without replaying stale data. | Current bit-true and reset/replay tests deassert `core_enable` after drain; reset tests replay a fresh frame. | Scoreboard checks full drain and a new reset epoch. No full-chain test currently checks output quiescence after an independent stop request, then restarts without reset. | Existing `cp_underflow`, `cp_pa_word`, and reset counts do not prove stop/idle/restart semantics. | OPEN. Parent-level GT and board recovery are outside this UVM top and remain separate integration signoff. |

## Code-coverage disposition (current-source update, 2026-10-08)

Older Oct 5/6 reports are historical. The fresh current-source generic and
real-XPM databases remain separate because the XPM report includes vendor
hierarchy.

| FIFO build | Fresh raw URG | Reviewed adjusted URG | Remaining status |
| --- | ---: | ---: | --- |
| Generic | 87.16% | 99.66%* | Four interpolation line/branch bins and 288 reachable high-counter direction bins remain OPEN. |
| Vivado XPM | 80.12% | 96.71%* | Same 288 reachable high-counter directions, vendor line/condition/branch/toggle bins, and `stage1_valid -> invalid` FWFT transition remain OPEN. |

*Adjusted values are the reviewed bit21 URG view, not recalculated on bit22.
Latest raw values are from the bit22 same-source URG reports.

The latest bit22 current-source full-chain stream checked **4,194,309 output
words** in each FIFO build against an independent integer oracle. Its first
2,097,158 words were verified against the MATLAB-validated fixture before the
integer-model extension. All four 64-bit output planes match, all 16 DPD lane
counters clear after reset, and both logs report zero UVM errors/fatals.
`sample_count[22]` toggles both ways in all 16 lanes for generic and XPM;
bits31:23 remain reachable/open. Raw URG includes all source/vendor bins.
Adjusted URG is an exact-bin disposition view, not raw coverage and not
100%. Exact counts, hashes, VDB provenance and per-bin status are in the
[`reachability review`](thermo5-reachability-closure-20261008.md).

The current-source local one-command licensed package PASS is recorded in
`runs/thermo5_current_source_dv_resume_20261008/dv_package.json` for digest
`0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8` (202
RTL/DV files; dirty worktree). Hosted CI has not run on that dirty source.
Four one-fault-at-a-time detector experiments are in
[`thermo5-fault-detection.md`](thermo5-fault-detection.md); they ran under
XSim, not VCS-UVM, so do not claim UVM mutation testing. The one-command
licensed regression entry and required inputs are in `dv/uvm/sim/README.md`.

No blanket coverage waiver is applied. Configuration/proof exclusions are
scoped to exact bins; reachable high-counter bits and unresolved XPM bins
remain OPEN. Functional coverage, raw code coverage, formal proof, and
integration signoff are distinct evidence categories.

## Checker and scope caveats

- The source and PA scoreboard now calls `uvm_fatal` on a metadata, sample,
  or plane mismatch, so the normal PASS marker cannot follow that mismatch.
  The earlier XSim mutants were not rerun as VCS-UVM mutants; both FIFO
  builds did pass the complete post-hardening licensed regression. The
  outer launcher also requires zero UVM errors/fatals and the expected
  golden-word and drain contracts.
- The seven-case runs verify the specified generic/XPM digital FIFO variants;
  they do not prove metastability resolution, CDC/RDC signoff, generated GT
  reset behavior, serial alignment, PA electrical behavior, or board output.
- Code-coverage percentages include different hierarchy for the two builds
  and are not comparable across the generic and vendor-XPM runs. Functional
  covergroups and MATLAB scoreboard results are reported separately.

## Reproduction commands

The usual licensed Rocky/VCS commands are documented in
`dv/uvm/sim/README.md`. To repeat the signed-endpoint functional test, use
`thermo5-vcs-run` with `THERMO5_TESTNAME=thermo5_sku_bittrue_test`, the
extreme MATLAB vector directory, and `THERMO5_EXTRA_ARGS=+EXPECT_SIGNED_EXTREMES`;
choose a fresh `THERMO5_OUT` for each FIFO build.
The audited local bridge tasks used for this evidence are
`thermo5-signed-extremes-generic` and `thermo5-signed-extremes-xpm` in
`tools/rocky-bridge.tasks.json`. They have a no-reuse guard for their fixed
run-directory names.
