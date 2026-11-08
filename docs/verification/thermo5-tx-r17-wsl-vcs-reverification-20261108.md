# Thermo5 TX Round 17 WSL VCS Reverification

**Date:** 2026-11-08
**Tested source:** `4d92ecb8467b095b50478065e29e9646f2cff27e` on `codex/thermo5-round16-coverage-closure`
**Thermo5 base:** `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`
**Decision:** tool availability and the listed Linux checks **PASS**; full Linux DV signoff remains **OPEN** (`RAW_100_OPEN`).

## 1. What changed from the earlier blocker report

VCS is usable in the current Rocky 8.10 WSL2 environment. The earlier “unsupported WSL2 kernel” conclusion was incorrect. The actual issue was a 32-bit/64-bit mode mismatch in tool discovery: the plain `urg -version` probe searched the default 32-bit `$VCS_HOME/linux` directory, while this installation is under `$VCS_HOME/linux64`. No `VCS_ARCH_OVERRIDE` was needed.

The successful tool probes were run in the configured login shell. `vcs -ID` reported `V-2023.12-SP1_Full64` on `linux64`; `vcs -location` resolved to `$VCS_HOME/linux64`; and `urg -full64 -version` reported URG `V-2023.12-SP1`, CovDB 13.1. Product UVM builds and simulations then completed with the VCS license available. The Formal reset smoke used VC Formal `V-2023.12-SP2`.

Use the 64-bit mode consistently:

```bash
vcs -full64 ...
urg -full64 ...
```

Do not use the plain `urg -version` result as a license or tool-availability test in this installation.

## 2. Frozen baseline

| Item | Value |
|---|---|
| Product | Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state |
| DPD | `DPD_MAX_TAPS=1`, Identity reset image |
| Interfaces / FIFO | AXI-Lite, Generic FIFO |
| Product RTL aggregate SHA-256 | `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003` |
| Compile fingerprint | `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7` |
| Compile inputs checked | 95; 0 hash mismatches |
| Kernel | `6.6.87.2-microsoft-standard-WSL2` |
| Tools | VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`; VC Formal `V-2023.12-SP2`; Python `3.12.13` |

No product RTL, product parameter, or frozen algorithm was changed for this rerun. The run began from a clean tracked worktree in the isolated PR #46 checkout. The original user worktree and its pre-existing edits were left untouched.

## 3. Linux regression matrix

| Suite | Result | Scope |
|---|---:|---|
| Generic FIFO product UVM | PASS | Bit-true, bubbles/backpressure, FIFO boundary/empty, reset/reset sweep, expected-negative frame |
| AXI-Lite product UVM | PASS | Register/configuration, coefficient transport, nonlinear-DPD scenario, STOP, reset and boundary tests |
| AXI-Lite product DUT-hierarchy coverage suite | PASS | Product hierarchy compile and URG merge; 8 Test VDBs included in the 551-VDB coverage set |
| System constrained random | PASS, 110/110 | Seeds 720000–720099 and long seeds 820000–820009; Python trace oracle checked each case |
| DPD / gain / profile matrix | PASS, 60/60 | Full 60 tuple matrix, including legal non-Identity one-tap coefficients; independent Python oracle |
| COMMIT boundary × PA stall | PASS, 2/2 | Both expected timing classes and both intended cross bins observed |
| Reset × pending COMMIT | PASS, 8/8 | All 4 intended cross bins observed |
| STOP / Drain / Restart | PASS | 2 packets; 112 ordered PA words matched the oracle and packet integrity audit passed |
| Unified SV scoreboard mutation | PASS, 6/6 | Lost, duplicate, reordered, wrong-frame, premature-config and EF2-corruption mutations detected; 7 checker errors caught |
| Python reference unit tests | PASS, 64/64 | `unittest` reference-model suite |
| VC Formal reset smoke | PASS, scoped | 3 reset assertions proven, 4 activity covers reached, 1 modeled collision cover uncoverable, 0 black-box instances |

The AXI-Lite nonlinear-DPD smoke scenario is not itself reported as a nonlinear bit-true check: that scenario's log says its arithmetic bit-true oracle is disabled. Independent arithmetic checking is provided by the 60-case DPD matrix and the System Random Python trace checks within their stated configurations.

Reproduction commands (run from the repository root, with a fresh ignored output directory):

```bash
make -C dv/uvm/sim thermo5-vcs-regression PYTHON=python3.12 \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_DPD_MAX_TAPS=1 THERMO5_FIFO_IMPL=generic \
  THERMO5_VECTORS="$PWD/runs/thermo5_r16_gate1_20261108/vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_r16_gate1_20261108/generic"

make -C dv/uvm/sim thermo5-axil-product-vcs-regression PYTHON=python3.12 \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_DPD_MAX_TAPS=1 THERMO5_FIFO_IMPL=generic \
  THERMO5_VECTORS="$PWD/runs/thermo5_r16_gate1_20261108/vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_r16_gate1_20261108/product"

make -C dv/uvm/sim thermo5-tx-system-random PYTHON=python3.12 \
  THERMO5_RANDOM_SEEDS=100 THERMO5_LONG_RANDOM_SEEDS=10 \
  THERMO5_RANDOM_SEED_BASE=720000 \
  THERMO5_RANDOM_OUT="$PWD/runs/thermo5_r16_gate1_20261108/system_random"

make -C dv/uvm/sim thermo5-tx-random-dpd-matrix PYTHON=python3.12 \
  THERMO5_RANDOM_OUT="$PWD/runs/thermo5_r16_gate1_20261108/dpd_matrix_campaign"

make -C dv/uvm/sim thermo5-tx-commit-boundary-stall PYTHON=python3.12 \
  THERMO5_RANDOM_OUT="$PWD/runs/thermo5_r16_gate1_20261108/commit_campaign"

make -C dv/uvm/sim thermo5-tx-reset-pending-commit PYTHON=python3.12 \
  THERMO5_RANDOM_OUT="$PWD/runs/thermo5_r16_gate1_20261108/reset_campaign"

make -C dv/uvm/sim thermo5-unified-scoreboard-mutation-vcs \
  THERMO5_DPD_MAX_TAPS=1 THERMO5_CENTERED_CUBIC=1 \
  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 THERMO5_FIFO_IMPL=generic \
  THERMO5_OUT="$PWD/runs/thermo5_r16_gate1_20261108/scoreboard_mutation"

cd dv/uvm/refmodel/python && PYTHONPATH=. python3.12 -m unittest discover -s tests -v

PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py --jobs reset \
  --out-dir runs/thermo5_r16_gate1_20261108/formal_smoke
```

The executed campaign commands and exact per-run logs are retained under the ignored directory `runs/thermo5_r16_gate1_20261108/`; the evidence manifest records SHA-256 hashes. Generated logs and VDB directories are not committed.

## 4. Raw and zero-exclusion Adjusted DUT coverage

The fresh Raw and Adjusted URG reports consumed the same validated input snapshot: one current-source Design VDB and 551 Test VDBs. Of the test VDBs, 362 are verified carry-forward data from the previous baseline and 189 were produced by the current-source campaigns above. The 362 carry-forward tests are not claimed as rerun in this round. The manifest records the same input-manifest SHA before and after URG and checks all 95 compile input hashes with zero mismatches.

| Metric | Raw covered / total | Raw | Zero-exclusion Adjusted covered / total | Excluded | Remaining |
|---|---:|---:|---:|---:|---:|
| Branch | 524 / 637 | 82.26% | 524 / 637 | 0 | 113 |
| Condition | 657 / 849 | 77.39% | 657 / 849 | 0 | 192 |
| Line | 3338 / 3796 | 87.93% | 3338 / 3796 | 0 | 458 |
| Toggle | 92072 / 104480 | 88.12% | 92072 / 104480 | 0 | 12,408 |
| FSM state | 13 / 13 | 100% | 13 / 13 | 0 | 0 |
| FSM transition | 22 / 22 | 100% | 22 / 22 | 0 | 0 |

There are 13,171 remaining Branch + Condition + Line + Toggle bins. Approved Waivers: 0. Applied Exclusions: 0. The new 189 current-source Test VDBs produced **zero additional exact DUT code hits** versus the 362-Test-VDB baseline. Their functional, transaction, oracle and mutation results still stand; they do not reduce the remaining code-coverage ledger. `Adjusted` here means a same-input report with no approved exclusions applied; it is numerically identical to Raw and is not a waiver signoff.

The aggregate DUT assertion report has 13 `SUCCESS`, 3 `FAILURE`, and 2 `UNCOVERED` statuses. The legal regression suites passed their checkers, while negative tests deliberately exercise defensive assertions; the three aggregate failures still require property-level review before any overall Assertion PASS can be claimed. The two uncovered product `q1_tail` properties remain open.

Coverage evidence identifiers:

- VDB manifest SHA-256: `e0f306b30b206df08b6c37991c940d855e4e03d0659640d38c066b4b6897b509`
- Current Design VDB tree SHA-256: `662b4f873f12f664fb2ddf22b0d69415952c96d2734814d7a6016ab6f65f50db`
- Compile fingerprint: `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`
- URG report manifest SHA-256: see `docs/verification/data/thermo5-r17/thermo5_tx_r17_wsl_vcs_reverification.json`

## 5. Formal, Waiver and remaining closure

The reset-only Formal smoke is current-source and non-blackboxed within its harness. It proves three reset properties and reaches four reset activity covers. One collision cover is reported uncoverable under the harness contract; it is not converted into a product waiver. This smoke does not close outstanding-counter saturation/underflow, full-chain DPD Identity, COMMIT → Pending → Apply → ACK → DONE, or the two legal product `q1_tail` obligations.

No independent Waiver approval was added. No official `.el` exclusion was generated or applied. The 371-item official waiver reconciliation and prior candidate evidence remain pending their exact-bin mapping, current-source evidence review and independent approval. In particular, do not interpret this zero-exclusion Adjusted report as an approved-waiver report.

Still open:

1. 13,171 DUT code bins remain open, including 113 Branch, 192 Condition, 458 Line and 12,408 Toggle bins.
2. Outstanding counter Formal is INCONCLUSIVE/OPEN; full-chain DPD Identity and the COMMIT lifecycle are OPEN.
3. Two product `q1_tail` assertions still lack legal attempts. Aggregate assertion statuses include three failures from the combined coverage set that must be classified property by property.
4. No actual XPM FIFO, GT Wizard, integrated physical CDC/RDC, Vivado timing/PPA, board, RF, or physical QAM256 BER validation ran.

**Signoff decision:** VCS/URG availability is PASS. The listed Linux regressions, Python oracle suite, mutation suite and reset Formal smoke PASS within their stated scopes. Full Linux DV / code-coverage / required-Formal signoff remains **OPEN**. This is not FPGA, GT, timing, RF or physical signoff. PR #46 remains Draft/Open and unmerged.

Machine-readable run and evidence hashes: [`thermo5_tx_r17_wsl_vcs_reverification.json`](data/thermo5-r17/thermo5_tx_r17_wsl_vcs_reverification.json). Full run artifacts remain in the ignored `runs/thermo5_r16_gate1_20261108/` directory in the isolated worktree.
