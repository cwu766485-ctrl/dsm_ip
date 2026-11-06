# Thermo5 TX Open Closure Round 1 — 2026-11-05

## Result

This round closes the live UVM EF2 numeric check for the exercised packet and
DPD scenarios, refreshes the full 110-seed system-random campaign, and repairs
the long STOP/PA-stall test sequence. It does **not** close final TX Coverage
or Formal signoff. The full system-cross model still has gaps, Raw DUT Code
Coverage remains below 100%, and the two legal Centered-Cubic `q1_tail`
assertions still have no attempts.

## Source and product identity

- Branch: `codex/thermo5-final-integration`.
- HEAD before this round: `6bef1cbd66a55bbec5601a5d36fa4c86f85bfd26`.
- The VCS runners record that HEAD, but the round was compiled from the dirty
  worktree. Exact modified source-file hashes are in
  [`thermo5-tx-open-closure-round1-20261105.json`](data/thermo5-tx-open-closure-round1-20261105.json).
- Product configuration: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120,
  20-bit state; four 64-bit PA planes; DPD_MAX_TAPS=1, Identity reset image;
  AXI-Lite control and Generic FIFO.
- Changes are in UVM, Python vector generation, regression launchers and the
  Makefile. Product RTL, the frozen algorithm, RX and AI-DPD were not changed.

## P1 — live EF2 stage checking

The UVM Unified Scoreboard now loads independent Python-generated EF2 I/Q
sidecars and compares every accepted 32-lane EF2 word as it passes the DUT
stage. It checks word order and all 32 signed 16-bit I/Q lanes; missing,
malformed or wrong-length references are fatal, and any lane mismatch is an
error followed by a test failure. Sidecars are generated from the same
explicit input, frame gain and legal one-tap DPD coefficients as the PA
reference vectors.

The online checker passed in 178 legal runs: 110 system-random packets,
60 DPD/gain/input cases, and 8 COMMIT-boundary cases. Each run also completed
the independent Python trace replay where the runner defines it. A deliberate
single-bit mutation of EF2 I lane 0 was detected at word 0 and failed the UVM
test as expected. Reset-truncated streams continue to use the independent
Python trace Oracle, which compares only causally available output across the
reset epoch; the online sidecar mode is not enabled for those reset cases.

## P2 — system campaigns and cross matrix

| Requirement | Evidence this round | Disposition |
|---|---|---|
| DPD x Gain x Input Profile | 60/60 legal tuples; URG cross reports 60 expected, 0 uncovered, 60 covered. Includes Identity, attenuation, boost, cubic and quintic one-tap classes; low/nominal/high gain; four input profiles. | PASS |
| COMMIT x Frame Boundary x PA Stall | 8 COMMIT trials; URG cross 2/2 covered. | PASS |
| Source Bubble x PA Stall x FIFO Full | 110-system-random trace audit observed source-gap with zero-ready and partial-ready PA stalls while FIFO-full events occurred. These are trace-derived packet scenarios; the current model does not export an exact URG cross bin for this tuple. | PARTIAL — add an explicit sampled cross before signoff |
| STOP x TLAST x Drain | Directed 64-beat packet test passed: STOP issued mid-packet, accepted TLAST, drained all 112 output words, observed seven PA partial-stall cycles after TLAST/STOP, and STATUS returned to idle. Python replay matched CDC/EF2/PA 112/112 with zero underflow. There is no dedicated URG three-way cross bin yet. | Behavior PASS; coverage model OPEN |
| Reset x Pending COMMIT | 8 Reset trials; URG cross 4/4 covered across short/long prefixes and attenuate/boost pending coefficients. | PASS |
| RUN x Prefill x Source Gap | The 110-seed packet traces include `RUN_PREFILL_SOURCE_GAP`; the runner checks accepted traffic and replay. The current summary is trace-derived rather than an exact URG cross. | PARTIAL — add an explicit sampled cross before signoff |
| STATUS x COMMIT x STOP | URG cross 1/1 covered in the COMMIT campaign. | PASS |

The refreshed system-random campaign passed 100 short packets plus 10 long
packets, with profiles distributed 28 random, 28 extreme, 27 range-stress and
27 EF2-saturation. All 110 UVM logs show the EF2 reference loaded and zero
EF2 mismatches; the suite also checks zero unexpected underflow and runs the
Python stage Oracle. Its URG merge completed successfully. The campaign
summary lists 20 observed scenario labels; this is not a claim that every
possible Cartesian combination is closed.

The long STOP test previously treated 112 output words as two 32-beat
packets, while graceful STOP ends the accepted packet at TLAST. It now sends
one legal 64-beat packet, waits for accepted TLAST, then applies partial PA
backpressure while the remaining centered-interpolator outputs drain. This
removes the testbench deadlock without changing DUT behavior.

## P3 — Coverage, Assertion and Formal status

The latest canonical full-product Raw/Adjusted baseline remains unchanged:

| Metric | Raw | Adjusted |
|---|---:|---:|
| Branch | 524/637 | 524/637 |
| Condition | 657/849 | 657/849 |
| Line | 3338/3796 | 3338/3796 |
| Toggle | 91112/104480 | 91112/104480 |

This round's 110-seed URG report is a separate campaign report, not a merge
with the full canonical VDB inventory, so it is not substituted for the
Raw/Adjusted signoff baseline and no global coverage delta is claimed. Existing
legal-product Functional Coverage remains 412/412 rows (206 distinct bins,
13 groups); the new DPD matrix and control crosses are reported separately.

There are still 371 pending waiver candidates, zero approved waivers and zero
active exclusions. No denominator, DUT, VDB or Exclusion file was altered.
The fail-closed code gate remains `RAW_100_OPEN`.

In the fresh legal 110-seed URG report, the DUT assertion row is 13/15 with zero
failures. The two DUT properties without attempts are exactly:

- `thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1.unnamed$$_1`
- `thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2.unnamed$$_1`

Both map to `assert(q1_tail)` at
`rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310`. Two additional
without-attempt properties belong to UVM register-map library code. Legal
regressions had zero unexpected assertion failures. The intentionally mutated
EF2 reference failure is kept as a separate expected-negative result.

No new Formal proof was run because this round changed no RTL or Formal
harness. The previously reported full-chain DPD Identity and outstanding
counter guard goals remain INCONCLUSIVE/OPEN; no inconclusive result is treated
as a proof. Real XPM and GT Wizard simulation, Vivado timing/PPA, FPGA routed
implementation and physical RF/QAM256 BER remain NOT_RUN.

## Commands and evidence

The principal commands were:

```bash
PYTHONPATH=dv/uvm/refmodel/python VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  python3.12 dv/uvm/sim/run_thermo5_system_random.py \
  --random-seeds 100 --long-seeds 10 --seed-base 721000 \
  --out runs/thermo5_open_closure_round1_20261105/system_random_full

PYTHONPATH=dv/uvm/refmodel/python \
  python3.12 dv/uvm/sim/run_thermo5_product_dpd_matrix.py \
  --seed-base 735000 \
  --out runs/thermo5_open_closure_round1_20261105/dpd_matrix

PYTHONPATH=dv/uvm/refmodel/python VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  python3.12 dv/uvm/sim/run_thermo5_randomized_control.py \
  --reset-cases 8 --commit-cases 8 --seed-base 1045000 \
  --schedule-seed 20261105 \
  --out runs/thermo5_open_closure_round1_20261105/randomized_control

make -C dv/uvm/sim thermo5-axil-long-frame-vcs-run \
  THERMO5_VECTORS="$PWD/runs/thermo5_centered_stop_restart_vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_open_closure_round1_20261105/make_long_stop"

PYTHONPATH=dv/uvm/refmodel/python python3.12 \
  -m unittest discover -s dv/uvm/refmodel/python/tests -v
```

VCS was V-2023.12-SP1_Full64; Python was 3.12.13. Python tests passed 62/62.
The VDBs, full logs, traces and URG HTML reports are under the ignored
`runs/thermo5_open_closure_round1_20261105/` directory. Their summary/log
hashes and the tested source-file hashes are in the adjacent machine-readable
evidence JSON. This local worktree has not been pushed or merged.
