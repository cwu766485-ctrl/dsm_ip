# Thermo5 Compile-Time DSM Architecture

Date: 2026-11-21 (Asia/Singapore)
Research branch: `work/thermo5-vcu118-architecture-research`
Baseline source HEAD: `aa78ce7a821760acd74bba2a96c68ff147f90909`
Tool: Vivado/XSim 2026.1, SW build 6511674
Target: VCU118 part `xcvu9p-flga2104-2L-e`

Changed source files, regression evidence, and routed DCPs are itemized by
SHA-256 in `sha256_manifest.tsv`. The final source commit is recorded in Git
after the report freeze; generated run data remains local under `runs/`.

## Result

The new product top is `tid32_thermo5_compiletime_tx`, parameterized by
`DSM_ARCH`. Its nested generate branches elaborate only one DSM. The existing
`tid32_thermo5_runtime_tx` remains available and its runtime mode-switch test
still passes. The compile-time top retains AXI-Lite RUN/STOP and DPD
configuration; DSM selection is fixed at synthesis/elaboration and a write to
the runtime DSM mode register is rejected with DECERR.

All three compile-time XSim configurations passed the 32 AXI-beat / 56 PA-word
independent Golden test with randomized PA-ready stalls. The Runtime Top
regression passed 8 streams across all 6 directed architecture transitions,
with 448 words checked, 728 stall cycles, and one reset. These are bounded
digital regression results, not UVM coverage signoff.

The VCU118-part synthesis checks found only the requested generate branch, no
unselected DSM or runtime DSM backend, no blackbox cells, and no latch cells.
All three configurations passed the bounded compile-time XSim Golden test.
EF1 and MASH completed OOC place-and-route, but both fail 218.75 MHz setup
timing on the shared centered-cubic Interp2-to-FIFO path. EF2 synthesis is
complete and its unrolled feedback path fails timing; EF2 routing was not run.
These are new Product Top results, not board-level or GTY signoff.

## Static configuration contract

| `DSM_ARCH` | Selected core | PA mask | PA weight | Interpolator / DPD | Runtime DSM selection |
|---:|---|---|---|---|---|
| 0 | EF1, first-order TIDSM, `STEP=7168` | `4'hF` | Four equal planes | Centered cubic ×2, one-tap identity DPD by default | Not present; mode write DECERR |
| 1 | EF2, second-order TIDSM, `STEP=5120` | `4'hF` | Four equal planes | Centered cubic ×2, one-tap identity DPD by default | Not present; mode write DECERR |
| 2 | MASH 1-1 with accumulator residue | `4'h3` | PA0:PA1 = 1:2 | Centered cubic ×2, one-tap identity DPD by default | Not present; mode write DECERR |

The top-level `pa_valid` is atomic over the statically active mask. The inactive
MASH PA planes are driven to zero. `pa_ready` is interpreted over the active
mask. Frame start/end, tail, and configuration ID remain associated with the
accepted PA transaction. The core rate contract remains one 64-bit output word
per active plane per core cycle when ready; this test did not include a GTY
serializer or prove continuous board-level transmission.

Common top defaults are `W=16`, `GAIN_W=16`, `DPD_MAX_TAPS=1`,
`INTERP_TAPS=2`, centered cubic enabled, and XPM FIFO enabled for the recorded
XSim/PPA flows. Existing Runtime Top RTL and historical experiments were not
replaced. The shared frontend now omits its unused legacy DSM instance when an
external DSM backend is selected.

## Structural and functional evidence

| Check | Result | Evidence |
|---|---|---|
| EF1 compile-time XSim / Golden | PASS | `runs/de_compiletime_20261121_01/arch0_xsim_final02/simulation.log` |
| EF2 compile-time XSim / Golden | PASS | `runs/de_compiletime_20261121_01/arch1_xsim_final01/simulation.log` |
| MASH compile-time XSim / Golden | PASS | `runs/de_compiletime_20261121_01/arch2_xsim_final01/simulation.log` |
| Runtime Top regression | PASS | `runs/de_compiletime_20261121_01/runtime_baseline_xsim/simulation.log` |
| Existing EF1 directed frontend smoke | PASS | `runs/uvm_thermo5_i2_d1/axis_xsim_parallel_generic_causal_ef1_seed20261122_words56/console_xsim.log` |
| UVM VCS regression | BLOCKED | VCS executable is absent from this environment; no VCS pass is claimed |
| Physical RF / GTY serializer measurement | NOT_RUN | Outside this compile-time digital top experiment |

For compile-time XSim each architecture checked 56 Golden output words. EF1 and
EF2 reported channel mask `F`, equal-plane contract, and zero UVM errors/fatals.
MASH reported mask `3`, weighted contract, and zero UVM errors/fatals. Runtime
regression reported `RUNTIME_PRODUCT_PASS`, 448 total checked words, 8 streams,
6/6 directed transitions, 5 negative checks, 728 stall cycles, 187 partial
stalls, and one reset.

## PPA scope and final result

The PPA flow targets the VCU118 device `xcvu9p-flga2104-2L-e`, with Core
4.571 ns (218.75 MHz), AXIS 8 ns (125 MHz), AXI-Lite 10 ns (100 MHz), and
0.2 ns data I/O budgets. It is an out-of-context part implementation: parent
`HD.CLK_SRC`, package pin locations, board I/O budgets, and reset input delays
are unavailable. Three reset inputs have no explicit I/O delay. The routed
clock-interaction report explicitly marks AXIS-to-Core `No Common Clock` and
`Partial False Path (unsafe)`. That CDC/constraint row remains OPEN; its
inter-clock slack is not evidence of a safe asynchronous crossing. No
whole-clock-group false path is present. Do not interpret these runs as
parent-board timing or CDC/RDC closure.

| Product configuration | Routed WNS / TNS | Hold WHS / THS | Routed LUT / FF / CARRY8 | BRAM / DSP | Power estimate | Result |
|---|---:|---:|---:|---:|---:|---|
| EF1 (`DSM_ARCH=0`) | −2.712 / −6264.759 ns | +0.027 ns / 0 | 47,068 / 49,921 / 4,473 | 6.5 / 671 | 5.292 W, vectorless, Medium | FAIL |
| MASH 1-1 (`DSM_ARCH=2`) | −2.818 / −4411.104 ns | +0.029 ns / 0 | 34,231 / 45,671 / 3,085 | 6.5 / 671 | 4.834 W, vectorless, Medium | FAIL |
| EF2 (`DSM_ARCH=1`) | Route not run | Synthesis WHS +0.049 ns | Synth LUT 53,442 / FF 23,207 / CARRY8 5,391 | 6.5 / 668 | Not run | FAIL at synthesis timing; research only |

EF1 routed worst path is `q_count_reg[0]_rep__2/C` in centered Interp2 to
`data_i_mem_reg[0][470]/D` in the Interp2-to-TID FIFO. Data delay is 7.263 ns
(4.652 ns logic, 2.611 ns routed net), 24 logic levels including 7 CARRY8;
clock skew is −0.010 ns. MASH's corresponding path starts at
`q0_i_reg[2][15]_replica/C` and ends at `data_i_mem_reg[1][122]/D`, with
7.369 ns data delay (4.608 ns logic, 2.761 ns net), 24 levels including
7 CARRY8, and −0.010 ns skew. This is a real synchronous shared-frontend
timing failure, not a CDC path. Both routes have 0 unconstrained internal
endpoints, but the missing reset input delays remain a boundary constraint
gap. Hold timing passes in these OOC runs; setup timing does not.

The current run exception set is scoped to asynchronous reset synchronizer CLR
pins, marked single-bit synchronizer first-stage D pins, XPM FIFO reset
stage-zero D pins, and physically bounded mailbox/Gray-pointer datapaths. No
whole-clock-group false path is used in this compile-time Tcl. Despite these
targeted exceptions, Vivado still reports the AXIS-to-Core crossing as a
partial false path (unsafe); this requires CDC/root-cause review. The timing
results above are produced with that exact exception set. Inspect
`routed_exceptions.rpt`, `routed_clock_interaction.rpt`, `check_timing.rpt`, and
the setup/hold worst-20 files before adopting the flow in a parent top.

An early EF1 route attempt stopped at `opt_design` with Vivado's generic
`[Synth 20-411]` error and is preserved. The subsequent fresh DCP route
completed. A Q-pin-bound experiment emitted `Constraints 18-515` path
segmentation warnings and is excluded. MASH route and EF1 route outputs use
unique immutable directories. Current DCPs, logs, and reports are listed with
SHA-256 digests in `sha256_manifest.tsv`.

EF2 is research-only. Its current synthesis path is a real intra-Core feedback
path from the Interp2-to-TID FIFO read-pointer/data logic through the unrolled
EF2 second-order TIDSM to `err1_i_q_reg[11]`: synthesis WNS `−93.246 ns`,
TNS `−43,219.352 ns`, 419 logic levels including 194 CARRY8, and 97.798 ns
data-path delay. No timing exceptions were used to hide this path.

Historical `thermo5_ppa_top_v4` EF1/MASH results remain useful reference data
only and are explicitly separated in `ef1_mash_ppa_comparison.csv`: their
different top/source/resource configuration makes them non-equivalent to the
new compile-time product top. Do not carry their positive WNS into this
architecture's signoff.

## Reproduction

Run each compile-time Golden test to a new, non-existing output directory:

```powershell
python .\dv\uvm\sim\run_thermo5_compiletime_xsim.py --arch 0 --out .\runs\<new-ef1-dir> --vectors .\runs\de_compiletime_20261121_01\vectors --xpm --seed 610216
python .\dv\uvm\sim\run_thermo5_compiletime_xsim.py --arch 1 --out .\runs\<new-ef2-dir> --vectors .\runs\de_compiletime_20261121_01\vectors --xpm --seed 610216
python .\dv\uvm\sim\run_thermo5_compiletime_xsim.py --arch 2 --out .\runs\<new-mash-dir> --vectors .\runs\de_compiletime_20261121_01\vectors --xpm --seed 610216
```

Use `research/vcu118_arch/run_compiletime_ppa.tcl` with Vivado 2026.1. For a
fresh synthesis/routed run, pass `<DSM_ARCH> <new-output-dir> 1`. EF2 synthesis
without route uses final argument `0`. A route-only rerun may pass a saved
synthesized DCP as the fourth argument, but every run must use a new output
directory. Existing successful and failed outputs remain under
`runs/de_compiletime_20261121_01/ppa/` and are not tracked as source files.

The repository's required AXI-Lite OOC smoke rerun is separately recorded as
`FAIL` for timing on its actual routed result. The fixed Tcl port check passed;
the direct `cmd.exe` run completed on ZU15EG (`xczu15eg-ffvb1156-2-i`) with
WNS/TNS `−0.283/−0.542 ns`, 2 setup failing endpoints, and WHS/THS
`+0.015/0 ns`. The worst endpoint is `draining_status_c_reg/C` to
`u_cfg/draining_sync1_reg/D`: Core-to-AXI-Lite, 0.269 ns data delay, with a
0.004 ns requirement because the clocks have no common period. Vivado reports
`No Common Clock` / `Partial False Path (unsafe)`; the synchronizer first
stage is not excluded by this legacy smoke constraint set. This is a CDC/STA
constraint issue to review, not evidence of an intra-Core datapath failure.
The next path is the corresponding `tx_active_sync1_reg/D` crossing.

That ZU15EG run routed with 0 unrouted nets and 0 overlaps, but it is not a
timing PASS: 528 input ports and 310 output ports lack I/O delays, and the OOC
flow lacks `HD.CLK_SRC`/package pin placement. Routed resources are 44,453 LUT,
52,763 FF, 4,529 CARRY8, 6.5 BRAM tiles, and 496 DSP. Vectorless power is
3.033 W at Medium confidence, without SAIF. `report_cdc` generated an empty
file and is not usable as CDC evidence. The full timing report, DCP, summary,
run command and console log are in
`runs/de_compiletime_20261121_01/required_axil_ooc_direct02/`.

The PowerShell wrapper returned an empty log while leaving Vivado processes
running. Two wrapper attempts produced separate synthesis DCPs and were
stopped; their unique outputs were retained. The corrected full Tcl flow was
run in the foreground through `cmd.exe`, with its complete console copied to
the run folder. This ZU15EG smoke is separate from, and cannot replace, the
VCU118 compile-time results above.
