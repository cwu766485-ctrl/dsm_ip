# Thermo5 UVM Regression Checkpoint

Date: 2026-11-13. Status: `DIRECTED_PASS; FULL_REGRESSION_OPEN`.

| Test / evidence | Candidate result | Baseline comparison | Status |
|---|---|---|---|
| AXI-Lite full-stream bit-true, seed 610216 | 32 source beats; 56 output words; four planes bit-true; 0 UVM Error/Fatal; 0 underflow | Same counts and pass using same test repair | PASS, directed |
| Independent trace oracle | Candidate and baseline traces pass; no underflow | Same | PASS, directed |
| AXI-Lite STOP/Restart | 112 ordered four-plane words | Not rerun on baseline | PASS, directed |
| Nine-reset sweep | Oracle: 206 CDC / 101 EF2 / 91 PA words; 0 underflow | Not rerun on baseline | PASS, directed |
| Full legal inventory | Not rerun | N/A | NOT_RUN |
| Complete negative regression | Not rerun | N/A | NOT_RUN |

The original timeout came from testbench RUN control: AXI-Lite RUN is
register-driven, while the shared test drove an unconnected `core_on()` signal
and created no AXI agent. The fix uses AXI-Lite transactions and stops after
accepted TLAST so queued output drains. Watchdog and functional checks were
retained.

Full-stream logs and traces are preserved in
`/tmp/thermo5_axil_compare_pr62_stopdrain_610216/` and
`/tmp/thermo5_axil_compare_candidate_stopdrain_610216/`. The STOP/Restart and
reset-sweep results are in the older rootfix evidence manifest; they are not
bound to current candidate HEAD `3b60f37`, so source/test hash binding must be
regenerated before integration. Do not treat the prior manifest as current
HEAD evidence. Current candidate RTL/TB/report hashes and the preserved tracked
diff are indexed by
`docs/verification/data/thermo5-cdc-quantified-debug/manifest.json`.

Reproduce under licensed VCS V-2023.12-SP1 with AXI-Lite mode,
`DPD_MAX_TAPS=1`, seed-610216 generated vectors and a fresh output directory;
then run `dv/uvm/refmodel/python/check_thermo5_monitor_trace.py` on the emitted
JSONL. The complete 594-scenario replay and full negative suite remain
required. No full regression signoff is claimed.
