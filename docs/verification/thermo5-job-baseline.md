# Thermo5 Job-Ready Baseline and Signoff Ledger

## Frozen digital configuration

The current thermo5 main-chain baseline is centered-cubic x2 interpolation,
fixed-point second-order TIDSM (`TIDSM_ORDER=2`, `STEP=5120`), 16-bit signed
input, 20-bit saturated error state, and chronological 32-sample processing.
The first-order/causal settings remain comparison configurations. The
experimental `PAIR_LOOKAHEAD` option is disabled in all product wrappers.

Do not merge results across different source SHAs, STEP values, interpolation
modes, state widths, FIFO implementations, or test inputs into one system
claim. The current Linux run package writes
`runs/thermo5_linux_ef2_signoff_<short-sha>/signoff_manifest.json`; it
cross-checks the SHA and configuration in each VCS/formal report and hashes
its evidence.

## Signoff layers

| Layer | Current disposition | What the evidence establishes |
| --- | --- | --- |
| Generic FIFO EF2 UVM regression | See current-SHA manifest | Digital bit-true, reset, FIFO boundary, backpressure, and expected negative-frame tests under the frozen configuration. |
| EF2 long-frame and saturation qualification | See qualification manifest | Three 2,072-word scenarios, oracle hashes, test-log hashes, and four required candidate/stall/rail crosses. This is targeted functional coverage. |
| EF2 arithmetic and streaming safety | PASS when the current-SHA formal job is present | Widened no-wrap/bounds, accepted-state updates, state hold, and output stability under stall. Not Python formal equivalence or a clamp-free proof. |
| Pairwise look-ahead numerical equivalence | PASS for the two-sample transfer; see formal and VCS miter reports | The proof covers arbitrary signed-16 samples and state for one pair; the 32-sample VCS miter checks the production core over 4,096 cycles. The optimization remains experimental. |
| Four-PA serializer loopback | PASS when current-SHA VCS evidence is present | Reassembles all four serialized lanes against EF2 output vectors using the vendor-neutral raw64 model. It does not instantiate the GT Wizard. |
| GT-parent link-loss recovery | PASS when current-SHA VCS evidence is present | Exercises immediate PA blanking, sticky fault, and reset recovery with a controllable GT stub. It is a digital parent-policy test. |
| Raw code coverage closure | OPEN | The clean Generic URG report scored 76.12% overall (82.63% line, 62.59% condition, 79.66% toggle, 100% FSM, 62.22% branch, 76.47% assertion, 69.26% group). Preserve uncovered bins; targeted functional crosses do not imply complete code coverage. |
| Real XPM FIFO / current GT Wizard TXP | OPEN | This Linux host has no Vivado/XPM or current GT Wizard simulation sources. Generic FIFO, behavioral serializer, and GT-stub tests do not replace vendor-model qualification. |
| FPGA timing and resource signoff | OPEN | No Vivado/XSim environment or routed timing result is available in this Linux flow. No Fmax/LUT/FF/DSP claim is made. |
| Behavioral RF chain | MODEL ONLY | Python DPA/output/noise simulations are sensitivity studies, not calibrated board measurements. |
| Physical RF QAM256 BER | OPEN | Requires the target board, RF chain, and receiver measurement. |

## Reproducible evidence package

Run `dv/uvm/sim/package_thermo5_linux_signoff.py` after the Generic regression,
URG merge, AXI-Lite STOP/restart, long-frame qualification, pair-look-ahead
VCS miter, and EF2/pair VC Formal jobs. The packager requires a clean Git
worktree, matching source SHA, the frozen EF2 configuration, passing expected
log markers, all four targeted crosses, both formal jobs, the four-PA
serializer loopback, and the GT-parent fault/recovery test. It records
SHA-256 values for the manifests, logs, selected URG reports, formal
properties, and oracle vectors.

The licensed `thermo5-dv.yml` workflow runs the same current-source EF2 checks
on a trusted self-hosted Synopsys runner when `THERMO5_LICENSED_CI=enabled`,
then uploads this review package as a commit-named GitHub Actions artifact.
Hosted runners only execute Python syntax/unit checks; they do not receive
vendor models, licenses, or EDA tools.
