# Thermo5 TID input range toggle audit

## Completed same-build follow-up (2026-10-06)

Current-source generic and XPM builds each run signed endpoints and the
four-word signed-endpoint plateau `range_stress` oracle. The source checker
observes 32/1184 accepted beats; the independent MATLAB PA scoreboard checks
56/2072 words on all four planes. In the merged after report, every one of
the original **162/162** per-instance/kind/bit gaps has **1->0=Yes and
0->1=Yes**, separately for generic and XPM.

Evidence: `runs/thermo5_dv_package_delivery_20261006/coverage/closure.json`,
`baseline/<fifo>/toggle_bit_delta.csv`, `audit_before/`, `audit_after/`, and
`coverage{,_after}/`. The parser reads covered rows as well as red rows,
expands bit ranges, and requires each after bit to exist. This supersedes the
historical license blocker below. Signed endpoints alone reduced 162 rows to
24; the plateau stimulus closes the remaining offset-branch sign bits after
the two interpolators. Raw generic/XPM scores remain separately owned.

## Historical investigation

Date: 2026-10-06 (Asia/Singapore). Status: **OPEN** pending a current-source
generic VCS/URG run. Scope is the frozen thermo5 SKU and the 162 generic
`OPEN_TID_INPUT_RANGE_STRESS` rows in the current hardened regression audit.

## Exact generic URG rows

Source inventory: `runs/thermo5_frozen_regression_hardened_20261006/generic/audit/urg_uncovered_toggle_signals.csv`.
All six summarized groups below are MSB-only (`bit 15` of each signed 16-bit
lane). Every row reports `toggle=No`, `one_to_zero=No`, and `zero_to_one=No`.

| Instance | URG kind | Signal | Uncovered vector bits | Rows |
| --- | --- | --- | --- | ---: |
| `thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].u_tid` | Port Details | `in_i_poly_vec` | 31, 47, 95, 143, 159, 175, 191, 207, 223, 239, 255, 271, 287, 303, 319, 335, 351, 367, 383, 399, 415, 431, 447, 463, 479, 495, 511 | 27 |
| same | Port Details | `in_q_poly_vec` | 15, 31, 47, 63, 79, 95, 111, 127, 143, 159, 175, 191, 207, 223, 239, 255, 271, 287, 303, 319, 335, 351, 367, 383, 415, 431, 447 | 27 |
| same | Signal Details | `in_i_pipe` | 31, 47, 95, 143, 159, 175, 191, 207, 223, 239, 255, 271, 287, 303, 319, 335, 351, 367, 383, 399, 415, 431, 447, 463, 479, 495, 511 | 27 |
| same | Signal Details | `in_q_pipe` | 15, 31, 47, 63, 79, 95, 111, 127, 143, 159, 175, 191, 207, 223, 239, 255, 271, 287, 303, 319, 335, 351, 367, 383, 415, 431, 447 | 27 |
| `thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[3].u_tid` | Port Details | `in_i_poly_vec` | 15, 31, 47, 63, 79, 95, 111, 127, 143, 159, 175, 191, 207, 223, 239, 255, 271, 287, 303, 319, 335, 351, 367, 383, 415, 431, 447 | 27 |
| same | Port Details | `in_q_poly_vec` | 31, 47, 95, 143, 159, 175, 191, 207, 223, 239, 255, 271, 287, 303, 319, 335, 351, 367, 383, 399, 415, 431, 447, 463, 479, 495, 511 | 27 |

The remaining 256 uncovered toggle rows in the generic inventory are outside
this TID input-range disposition. The XPM inventory remains separately owned
and must not be merged with generic FIFO coverage.

## Existing stimulus and independent oracle

The existing MATLAB extreme payload at `runs/uvm_thermo5_extreme_20261003/`
contains 56 frame/gain entries, 448 I/Q source samples, and 56 expected words
for each of four PA planes. Its first input frame includes signed endpoint and
high-dynamic values (`-32768`, `+32767`, intermediate magnitudes, zero, and
small signed values); the signed-endpoint VCS log confirms 32 accepted beats,
32 min-hit beats, 32 max-hit beats, and 56 MATLAB-checked output words.

I reused those exact vectors with the existing full-chain XSim testbench and
its independent four-plane MATLAB oracle. The run passed:

- Command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_thermo5_i2_d1_axis.ps1 -Seed 61006 -Words 56 -VectorDir .\runs\uvm_thermo5_extreme_20261003 -StressPaReady`
- Log: `runs/uvm_thermo5_i2_d1/axis_xsim_seed61006_words56/console_xsim.log`
- Result: `THERMO5_I2_D1_AXIS_BITTRUE_PASS source=32 output=56 stalls=15`.

No new vector or testbench was needed. This XSim result validates that the
existing legal extreme stimulus is still bit-true through the frozen chain;
XSim does not provide the VCS per-bit toggle result needed to close these URG
rows.

## Signed-endpoint VDB compatibility

The generic endpoint VDB is
`runs/thermo5_dv_closure_generic_20261006/cov_thermo5_sku_bittrue_test_seed606101.vdb`;
the corresponding XPM VDB is in the sibling
`thermo5_dv_closure_xpm_20261006` directory. The generic endpoint compile used
the same top, filelist, VCS version, and generic FIFO as the hardened generic
build. It is nevertheless not source-matched: the endpoint `simv` was built at
2026-10-05 16:09:36 UTC, while the hardened generic `simv` was built at
16:22:35 UTC. `dv/uvm/env/thermo5/thermo5_pa_scoreboard.svh` changed at
16:21:36 UTC, between those builds. Therefore the endpoint VDB must not be
merged into the hardened URG database. The XPM endpoint VDB is also ineligible
for the generic merge by FIFO implementation.

## Closure state and next run

No fresh VCS/URG coverage was run because the VCS license/compiler environment
is currently reported unavailable. No VCS command was retried. The 162 rows
remain **OPEN**, with no before/after bit-direction comparison available.

After the main owner confirms the VCS license is restored, compile the generic
SKU from the current source, run the same endpoint vectors with coverage, and
merge the new case only with that exact compile's `simv.vdb` and generic
baseline cases. Use a fresh run directory. A representative run-only command
from the Rocky project root is:

```bash
mkdir -p /mnt/e/workspace/chip/dsm_ip/runs/thermo5_tid_toggle_20261006/generic
./runs/thermo5_frozen_regression_hardened_20261006/generic/simv \
  +UVM_TESTNAME=thermo5_sku_bittrue_test \
  +VEC_DIR=/mnt/e/workspace/chip/dsm_ip/runs/uvm_thermo5_extreme_20261003 \
  +ntb_random_seed=61006 \
  -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir /mnt/e/workspace/chip/dsm_ip/runs/thermo5_tid_toggle_20261006/generic/cov_tid_extreme_seed61006.vdb \
  +EXPECT_SIGNED_EXTREMES \
  -l /mnt/e/workspace/chip/dsm_ip/runs/thermo5_tid_toggle_20261006/generic/tid_extreme_seed61006.log
```

Before URG merge, verify zero UVM errors/fatals, 32 accepted source beats, 56
four-plane golden words, and that the new VDB was produced by the matching
current generic compile. Then compare the six summarized groups above against
the new generic URG inventory, preserving separate one-to-zero and
zero-to-one results for each row. Until that run exists, neither XSim PASS nor
the earlier endpoint VDB closes the toggle gaps.

## Record

- Changed file: this audit only.
- Reason: capture exact per-instance/bit toggle gaps, assess endpoint VDB
  compatibility, and record the bit-true XSim check and current blocker.
- Checks run: current generic CSV inspection; endpoint VDB build-time/source
  comparison; existing-vector four-plane XSim bit-true run.
- Remaining limitation: no matching post-scoreboard-change VCS/URG coverage is
  available, so per-bit directions remain uncovered and OPEN.
