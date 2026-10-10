# Thermo5 verification closure resume - 2026-10-09

## Current closure position

This update records the latest verified scope; it does not declare full
coverage closure. The current frozen SKU remains `INTERP_TAPS=2`,
`DPD_MAX_TAPS=1` with identity coefficients and generic or real XPM FIFO.

| Item | Latest evidence | Disposition |
|---|---|---|
| Four-plane bit-true generic/XPM UVM | Current-source licensed regression and independent 4.19M-word generic/XPM runs passed, zero UVM errors/fatals; source digest and run manifests are in `runs/thermo5_current_source_dv_resume_20261008/` and `runs/thermo5_bit22_urg_20261008/`. | PASS for the tested vectors, seeds, clocks and reset contract; not physical GT/PA signoff. |
| Natural DPD counter toggles | Latest frontier records `sample_count[22:0]` both directions in all 16 lane counters for both FIFO builds. | Bits 23-31 remain 288 unhit directions per FIFO, reachable and OPEN. No force, width reduction or waiver. |
| Generic interpolation clamp | Four `round_sat` clamp line bins and four branch arms remain open. Current proof is valid-payload qualified; invalid startup slot payload is not constrained by that proof. | OPEN; do not transfer a valid-only proof or dismiss these as unreachable. |
| XPM wrapper reset tuples | Common reset/core-first release hit line 52 tuple `1/0`; line 57 tuple `1/1/1/0` and line 59 tuples `1/0/1/1`, `1/1/1/0` remain open in the matching-binary exact delta. | OPEN; legal full-chain replay passes, but these native bins are not closed. |
| XPM FWFT transition | `curr_fwft_state` remains 8/9; `stage1_valid -> invalid` did not hit during the public-reset attempt even though stage1 occupancy was observed and the four-plane replay passed. | OPEN; no internal force or waiver. |
| Other XPM model bins | Collision/read-X, startup/GSR, reset-default and vendor toggle bins still need per-signature disposition. The fixed half-period proof for selected `<=1500 ps` collision-window branches is scoped to the current testbench and has not been transferred into native URG exclusions. | OPEN unless a row is explicitly proven and matched to a native signature. |

## Fault-detection evidence

`runs/thermo5_fault_detection_xsim_20261009/summary.txt` reports a clean
baseline and four detected injected faults. The full-chain XSim bit-true
checker detected PA-plane swap at word 32, stalled-plane corruption, and
late frame-gain application at word 46. The isolated FIFO reset probe caught
a stale word after reset (`valid=1`, `empty=0`, data `2468`). The mutant copies
are generated under `runs/`; canonical RTL was not changed by the injection.

A new VCS-UVM runner is available at
`dv/uvm/sim/run_thermo5_fault_detection_vcs.py`. Its first attempt is recorded
at `runs/thermo5_vcs_fault_injection_20261009/manifest.json` and stopped before
compilation: VCS could not connect to its license server. Therefore there is
no VCS-UVM mutation result yet. Re-run it in a licensed Linux shell after
license connectivity is restored; expected gate is clean baseline PASS plus
each mutant caught specifically by the UVM `BITTRUE` checker.

## Clean-environment CI evidence

The CI syntax payload was copied into a new scratch workspace and passed
Python compilation plus workflow-structure smoke checks:
`runs/thermo5_clean_ci_syntax_20261009/`. The GitHub Actions workflow now
includes the VCS fault runner and long-counter audit helper in its Python
syntax step. This is a clean local syntax check only: GitHub Actions was not
dispatched on the current dirty source, and the licensed self-hosted UVM job
has not run against a clean checkout of this source.

## Next closure sequence

1. Restore VCS license connectivity and run the VCS-UVM mutation runner; keep
   its baseline and mutant logs/hash manifest as evidence.
2. Close the next practical counter threshold only with a natural, checked
   stream. The prior bit-22 throughput estimates about 105 minutes per FIFO
   for bit 23; decide whether both FIFO runs fit the available license window.
3. Investigate generic interpolation clamp bins and XPM FWFT/reset rows by
   their exact native URG signatures. Add only legal public-interface stimulus
   or a matching proof; otherwise leave each item OPEN.
4. Dispatch the licensed CI workflow from a clean checkout with the private
   vector inputs configured, then retain the immutable workflow run/artifact
   ID. A local syntax pass is not a hosted regression.

Résumé claims may describe the verified frozen-SKU UVM/bit-true regressions,
the measured raw coverage scores, and the XSim checker fault injections with
their exact scope. Do not claim 100% coverage, completed VCS-UVM mutation
testing, clean hosted CI, or complete verification signoff yet.
