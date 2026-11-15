# Thermo5 VCU118 timing closure study

This evidence is from the isolated `work/vcu118-ab-ppa` worktree at base
commit `dfa34dbd4848499448f2ddb146ead9f324db8490` (product source commit
`599959a9ed84eeefb24354df88d0f5296178ecef`), using Vivado 2026.1 and
`xcvu9p-flga2104-2L-e`. It does not modify the `thermo5` mainline.

## Root-cause audit

The original routed checkpoints were audited without recompilation. Original
worst setup paths were:

| Case | Clock pair | Slack (ns) | Data delay (ns) | Logic levels | Cell/logic (ns) | Net/route (ns) | Root cause |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| A | core -> AXI-Lite | -0.276 | 0.261 | 0 | 0.080 | 0.181 | status synchronizer input not excepted |
| B | core -> core | -2.744 | 7.294 | 24 | 4.820 | 2.474 | cubic interpolator to elastic buffer |
| C | core -> core | -97.148 | 101.700 | 396 | 42.924 | 58.776 | EF2 scalar feedback expansion |
| D | core -> core | -97.717 | 102.268 | 389 | 41.999 | 60.268 | EF2 scalar feedback expansion |

The complete Worst-20 machine-readable summaries and raw reports are in
`runs/thermo5_timing_audit_20261114/*/`. Clock interaction, CDC,
methodology, exceptions, and check-timing reports are retained per case.
`report_cdc` reports XPM/async-reset structural findings (CDC-1/7/13 and
related warnings); they are not treated as clean CDC signoff.

## A closure

The OOC constraint script now false-paths only the two confirmed status
synchronizer inputs, `tx_active_status_c -> tx_active_sync1` and
`draining_status_c -> draining_sync1`. The configuration mailbox remains a
10 ns `set_max_delay -datapath_only` path. A fresh timing-driven route passed
the tool's setup/hold gate:

| Path class | WNS (ns) | WHS (ns) |
| --- | ---: | ---: |
| Core -> Core | +0.141 | +0.011 |
| AXI-Lite -> AXI-Lite | +6.036 | +0.050 |
| Source -> Source | +4.787 | +0.039 |

The corrected routed checkpoint, timing/utilization/power reports, and logs are
under `runs/thermo5_vcu118_A_cdc_fixed_timing_20261114_2310/`; the follow-up
CDC audit is under `runs/thermo5_vcu118_A_cdc_fixed_audit_20261115/`. The OOC
result still has `HD.PARTPIN_LOCS`/`HD.CLK_SRC` and missing external I/O delay
limitations, so it is not board-level timing signoff.

## EF2 architecture study

The existing `PAIR_LOOKAHEAD` implementation was tested against the scalar
reference with iverilog for 4096 cycles. It passed 2664 accepted words with
backpressure, bubbles, positive/negative clamps, an exact negative tie, and a
midstream reset. VCS was unavailable in this Linux environment.

| Variant | Description | LUT | FF | CARRY8 | Synth WNS (ns) | Result |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| E0 | Original 32-lane serial expansion | 5301 | 210 | 636 | -91.093 | timing fail |
| E1 | Exact pair lookahead | 7616 | 210 | 832 | -67.360 | timing fail |

E1 reduces the standalone critical path but increases LUT/CARRY8 substantially
and remains far from 218.75 MHz. No E2 block predictor was implemented because
the exact pair candidate is not timing-qualified; adding registers across the
feedback dependency would change the state/output contract. `PAIR_LOOKAHEAD`
therefore remains experimental and is not selected by the product wrappers.

## B timing-driven baseline completion

The earlier timing-driven run stopped during `phys_opt_design` and had no
physical result. To check that no legal physical optimization result had been
missed, the preserved original B synthesized checkpoint was resumed through
`opt_design`, placement, physical optimization, and route in
`runs/thermo5_vcu118_B_timing_resume_20261115/`. It completed with WNS
`-2.739 ns`, WHS `+0.014 ns`, 46,029 LUT, 49,768 FF, 668 DSP, 6.5 BRAM tiles,
and 0 URAM. The critical path remained a 24-level centered-cubic output to
`u_interp2_to_tid_fifo` input path at 7.291 ns (4.708 ns logic, 2.583 ns net).
This improved the previous route by only 0.005 ns and did not close timing.

## B Cubic pipeline ECO

The isolated ECO in `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv`
registers the exact signed pre-adds `a=x0+xp1` and `b=xm1+xp2`, plus even
samples and metadata, then computes the exactly equivalent Q14 accumulator
`(9*a-b)<<10` with the existing rounding/saturation in the final stage. This
preserves the coefficient polynomial, bit-true output sequence and transaction
metadata while adding two cycles of first-valid latency. A differential
iverilog test compared against the original source RTL over 19 inputs, three
frames and synthetic tails, with shared randomized output backpressure; 16
outputs matched bit-for-bit and metadata-for-metadata. The 1024-vector
sustained test passed with zero bubbles (II=1), and Verilator lint passed.
XSim was attempted but could not start because Linux-to-Windows `cmd.exe`
interop failed before xvlog; it is not claimed as passed.

Vivado 2026.1 full OOC implementation completed under
`runs/thermo5_vcu118_B_pipeline_route_20261115/` with the same VCU118 part,
product top, 125/218.75/100 MHz clocks, generics, Synthesis directive and
constraints as baseline B. The elaborated configuration was checked. The
routed result is PASS: WNS `+0.307 ns`, WHS `+0.028 ns`, zero setup/hold failing
endpoints. The new worst path is a DPD DSP-stage path, 11 levels and 3.939 ns
(2.622 ns cell, 1.317 ns net). Resources are 48,624 LUT, 53,556 FF, 496 DSP,
6.5 BRAM tiles, and 0 URAM. Relative to the resumed routed baseline, this is
+2,595 LUT, +3,788 FF, -172 DSP; BRAM/URAM are unchanged. The additional
pipeline latency is two core cycles; sustained II remains one vector per
cycle. Power is Vivado vectorless without SAIF: 4.186 W total (1.693 W dynamic,
2.494 W static), not measured workload power.

The route has 112 warnings and zero critical warnings/errors. Material
limitations are OOC `HD.PARTPIN_LOCS` and `HD.CLK_SRC` omissions on external
ports/clocks, which limit port path routing/timing accuracy, and Vivado's
multiple-clock report reminder. Internal clocks remain constrained as modeled;
no global false path, reduced clock, or multicycle exception was added.
This is OOC closure evidence, not board-level signoff.

## B pipeline verification and strategy stability follow-up

The Windows XSim runner was repaired to invoke `xvlog.bat`, `xelab.bat`, and
`xsim.bat` directly with Vivado 2026.1 on PATH. Fresh XSim runs passed:

- Block differential: 19 accepted input vectors, 16 valid output vectors,
  three frames and synthetic tails, shared randomized backpressure, exact I/Q
  and Frame/Tail comparison, fixed +2-cycle latency. Pipeline reset and STOP
  while occupied both flushed the prior epoch; restart delivered six checked
  outputs per epoch.
- Sustained: 1025 accepted inputs, 1024 valid outputs, zero bubbles (II=1).
- Full product AXI-Stream XPM-FIFO bit-true regression: 32 source beats and
  56 output words matched the Python oracle across all four planes using
  Centered-Cubic, EF1, STEP=5120.
- Verilator `--binary --assert --timing` replayed the differential/reset/STOP
  test and passed, including the RTL SVA. Verilator lint also completed.

An AXI-Lite DPD configuration-commit test was also run with both Generic and
XPM FIFOs. Both runs failed, so they are not signoff evidence: the XPM run
timed out waiting for `dpd_config_boundary_probe` at a marked DPD input
handshake; the Generic run failed its DPD sample count (59/56). The failures
are preserved in `runs/uvm_thermo5_i2_d1/axis_xsim_axil_{xpm,generic}_centered_ef1_seed1_words56/console_xsim.log`.
The baseline-versus-ECO cause has not been isolated. Linux VCS and VC Formal
executables are unavailable in this environment; no simulation result is
claimed as Formal.

A second implementation strategy was run from the same
`synthesized.dcp`, preserving part, constraints, CDC exceptions, generics, and
clock targets, using `RuntimeOptimized` routing. Its full reports and DCP are
under `runs/thermo5_vcu118_B_pipeline_runtimeoptimized_20261115/`.

| Strategy | WNS (ns) | TNS (ns) | Setup failing | WHS (ns) | THS (ns) | Hold failing | LUT | FF | DSP48 | BRAM tile | URAM |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Existing full / Explore flow | +0.307 | 0.000 | 0 | +0.028 | 0.000 | 0 | 48,624 | 53,556 | 496 | 6.5 | 0 |
| RuntimeOptimized route | +0.249 | 0.000 | 0 | +0.028 | 0.000 | 0 | 48,624 | 53,556 | 496 | 6.5 | 0 |

RuntimeOptimized's worst path is again a DPD DSP cascade, 11 logic levels,
4.005 ns total (2.625 ns cell and 1.380 ns net) from
`r4_full_s2[0]` in lane 2 to `p_50_out__0/DSP_A_B_DATA_INST/B[11]`. The two
strategies differ by 0.058 ns setup margin; both have zero setup/hold failing
endpoints. RuntimeOptimized routed all 102,896 routable nets with zero routing
errors. Its vectorless, no-SAIF power estimate is 4.186 W (1.692 W dynamic,
2.494 W static; medium confidence), not measured power.

The observed DSP48 reduction from baseline B's 668 to ECO's 496 is accompanied
by CARRY8 usage of 4,785 and LUT usage of 48,624. The RTL explicitly moves
signed cubic pre-adds into registers and expresses the equivalent constant
polynomial as shift/add arithmetic, so the mapping shift from DSP to fabric is
consistent with the source structure. This is not itself an arithmetic
equivalence proof; the module differential test and full four-plane Python
oracle pass cover the tested bit-true cases. The AXI-Lite commit failure still
prevents full P0 signoff.

The Windows `cmd.exe` launch issue is resolved for the block runner. Existing
OOC warnings remain: 103 warnings, no critical warnings/errors, including
missing `HD.PARTPIN_LOCS` on external ports, missing `HD.CLK_SRC` on clock
ports, and the multiple-clock timing reminder. They limit external-port
timing/skew fidelity and board-level interpretation. No global false path,
core-clock relaxation, or multicycle exception was introduced.

No ECO commit or PR was created. Keep the candidate branch isolated until the
AXI-Lite commit test is baseline-compared and product reset/STOP/commit
coverage is complete.

## EF2 bounded next study

The recurrence is genuinely loop-carried: `u[n]=x[n]+2e1[n-1]-e2[n-1]`,
`q[n]=sign(u[n])`, `e1[n]=sat(u[n]-q[n]Q)`, `e2[n]=e1[n-1]`. For a block of
four samples, exact lookahead must resolve up to three preceding quantizer
decisions; naive speculation creates as many as 2^3 (or 2^4 if computing the
terminal state candidates) histories per real/imag branch. The existing pair
candidate already grew from 5301 to 7616 LUT while its synth WNS remained
`-67.360 ns`, so extending the same full-branch expansion to 32 lanes is a
no-go.

Bound the next exact study to CHANNELS=2, 4, then 8, one candidate at a time.
For each, require formal or exhaustive small-width equivalence of output bits,
state, saturation, reset and stalls; reject an experiment if it adds more than
25% LUT over serial expansion at the same CHANNELS or fails to improve the
critical path by at least 20%. Stop the sequence if CHANNELS=4 does not meet
both gates. A useful optimization hypothesis is to share common affine state
terms across candidate histories and derive only sign-dependent `+/-Q` deltas,
with saturation handled at the same state boundary; this must be proved before
implementation.

An independent communication-equivalent architecture candidate is a block
state-space noise shaper: compute a second-order error-feedback block update
from current state and a short input block using matrix/affine transforms,
then quantize with a bounded vector residue-correction pass. Unlike exact
legacy EF2 parallelization, this may change individual bits, so evaluate only
in a separate model/branch. Go requires meeting the one-vector-per-cycle,
four-output-plane contract and disjoint held-out EVM/SNDR/BER/PSD/adjacent-
channel leakage gates before any RTL prototype; exact-bit-truth and
communication-equivalent claims must remain separate. No EF2 architecture
change was implemented in this timing ECO.
