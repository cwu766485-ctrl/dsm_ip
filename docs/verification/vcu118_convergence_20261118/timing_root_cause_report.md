# Timing root cause report — 2026-11-18

Status **FAIL**: these are OOC product-proxy results, not full-top or board signoff. Vivado 2026.1 build 6511674; xcvu9p-flga2104-2L-e; core 218.75 MHz, AXIS 125 MHz, AXI-Lite 100 MHz. EF1 and MASH run manifest source HEAD `6596ce703612af8b4e48c2489910e2e9dcaa14b8`; source and DCP hashes are in `runs/convergence_evidence_20261118_01/manifest.json` and each run manifest.

| Case | Overall WNS/TNS ns | WHS/THS ns | Core WNS ns | Worst setup |
|---|---:|---:|---:|---|
| EF1 CDC-bound | -0.352/-4.915 | +0.005/0 | +0.097 | `cfg_ack_core_reg/C` to `cfg_ack_sync1_reg/D`, asynchronous core→AXI-Lite |
| MASH A | -0.333/-31.374 | +0.006/0 | +0.104 | `cfg_mailbox_q_reg[9]/C` → `cfg_pending_core_reg[9]/D` |
| MASH B | -0.363/-31.574 | +0.004/0 | +0.070 | `cfg_mailbox_q_reg[192]/C` → `cfg_pending_core_reg[192]/D` |

EF1 ACK path launch/capture core/AXI-Lite edge separation 0.004 ns, data 0.337 ns (cell 0.079, route 0.258), skew -0.009 ns. Its setup endpoint is the first synchronizer stage: inspect CDC structure and reset contract before deciding on any narrowly justified constraint. Core→AXIS reset recovery and other synchronizer crossings also fail. Do not describe this as a single combinational logic failure or waive whole domains. EF1 has one exploratory `set_max_delay 4` mailbox-cell exception; hold remains timed, and its physical bundled-data/CDC contract is not signed off. MASH A/B have no valid timing exceptions in their respective reports. Actual report commands and paths are in each preserved run.

Candidate A/B alter midpoint arithmetic in the cubic stage feeding the elastic buffer; they are not two independently redesigned elastic-buffer structures. A has better measured WNS, B uses 70 fewer LUTs; neither is selected for product since complete metadata, reset, backpressure and product DV equivalence are not proven. Their arithmetic, sustained-output and streaming block tests passed, and candidate A has additional prior full-chain evidence. Nominal backend latency is 8 cycles and II=1 for the baseline runtime backend; end-to-end candidate latency is not newly measured.

The EF1 run reused a synthesized DCP with SHA-256 `4a8395da27c18f4405e9ef2891025ab3765ec82a092f3198fc44aebe3c12ceac`; a new full synthesis/route is running in `runs/ef1_fresh_synth_route_20261118_01/`. For each case inspect `setup_worst20.rpt`, `hold_worst20.rpt`, `exceptions.rpt`, `routed_timing_summary.rpt`, and `routed.dcp` in the directories listed in `ppa_comparison.csv`. The XDC contains provisional I/O budgets and has no board pin or external clock signoff.

Reproduction: from a fresh working directory use Vivado batch with `research/vcu118_arch/run_ppa_ef1_cdc_bound.tcl -tclargs ef1 <NEW_DIR> a` or `research/vcu118_arch/run_ppa_cubic_candidate.tcl -tclargs mash <NEW_DIR> a|b`; inspect native logs and completion markers.


## Additional atomic-update proof

VC Formal V-2023.12-SP2 `runs/mailbox_atomic_formal_04/properties.txt` reports
6 of 7 assertions proven, all 7 non-vacuous, and 4 of 4 covers hit. Proven
properties include boundary bundle selection, registered atomic update, stable
active data outside update, and ACK only after apply. `a_sample_stable` remained
inconclusive at depth 127 in this run, although the earlier smaller harness
`runs/mailbox_capture_formal_01/properties.txt` proved it under its own scoped
model. These results do not prove arbitrary-phase or independent-reset CDC.
The harness assumes a fixed 16:35 core/AXI-Lite period ratio and released common
reset; setup reset checking is disabled. Reproduce with a fresh output directory
and `vcf -batch -fmode FPV -f research/vcu118_arch/formal_cfg_mailbox_atomic.tcl`
after setting `MAILBOX_FORMAL_ROOT` and `MAILBOX_FORMAL_OUT` to absolute paths.
Source SHA-256: SV `345760b00ba8214c2af88626a66524a7ecc0739b1ee49ae70f04d78256b187c9`;
Tcl `7b05d4510ee33cfd88ce520b9b29b4b64f8da8b97dfc13bb321a1d9ee8d61d91`.

Fresh EF1 synthesis reports 0 errors, 0 critical warnings and 739 warnings;
warning categories and final implementation still require review.
