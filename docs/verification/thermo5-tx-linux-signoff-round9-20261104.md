# Thermo5 TX Linux Signoff — Round 9 Current-Source Refresh

Date: 2026-11-04 (Asia/Singapore)<br>
Branch: `codex/thermo5-tx-waiver-audit-round1`<br>
Base commit: `0279b8e4e64d3f7a1fe214b905c60d5018b5f726`<br>
Frozen product RTL SHA: `1236d49c72360aa62e316aea147528d93a1b3705`

## Signoff decision

Linux TX functional coverage is **PASS for the declared legally applicable bins**. Targeted current-source product compile, AXI-Lite product configuration, reset sweep, Python reference tests, and hardware utility tests are PASS. DUT code coverage and full-chain Formal remain **OPEN**. The final fail-closed coverage status is `RAW_100_OPEN`; no waiver or exclusion is approved, so Adjusted equals Raw. This is not FPGA, GT, RF, or complete TX signoff.

The product configuration remains Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state, four PA planes, `DPD_MAX_TAPS=1` with Identity reset image, AXI-Lite control, and Generic FIFO. No product RTL or frozen algorithm was changed.

## Round 9 coverage

Raw and Adjusted URG use one design VDB and the same ordered 248-test-VDB list. The inventory is mixed-provenance: 246 legal VDBs and two expected-negative VDBs. One current-source reset-sweep VDB replaced the prior reset-sweep VDB. This is not 248 fresh simulations from one verification-source SHA. All VDB trees and command arguments are fingerprinted in the manifests.

| Metric | Raw | Adjusted | Missing |
|---|---:|---:|---:|
| Branch | 525/637 (82.4176%) | 525/637 (82.4176%) | 112 |
| Condition | 658/849 (77.5029%) | 658/849 (77.5029%) | 191 |
| Line | 3,351/3,796 (88.2771%) | 3,351/3,796 (88.2771%) | 445 |
| Toggle | 84,340/104,480 (80.7236%) | 84,340/104,480 (80.7236%) | 20,140 |
| FSM states | 13/13 (100%) | 13/13 (100%) | 0 |
| FSM transitions | 22/22 (100%) | 22/22 (100%) | 0 |

The source-linked root-cause ledger contains **20,888 OPEN code records in 456 groups**. Its group labels are triage hints, not reachability dispositions. No bin was marked HIT or unreachable without exact evidence.

Legally applicable Functional Coverage is **392/392 (100%) across 12 groups**. The detail report retains 396 scoreable rows, including four uncovered rows belonging to two negative-test-only semantic bins duplicated in monitor/type views. It also preserves 24 existing URG-model-excluded rows. No valid bin was deleted and no denominator was changed.

## Assertions, waivers, and Formal

The legal-positive assertion report has 13 successes, zero failures, two uncovered properties, and two properties without attempts. Both no-attempt properties are `assert(q1_tail)` on the two Centered-Cubic interpolator stages. In the combined Raw inventory, the two expected-negative runs contribute two assertion failures; they are not legal-test failures.

The [Round 9 waiver review](thermo5-tx-waiver-review-round9.md) contains 371 exact candidates: 361 configuration-unreachable and 10 Formal-unreachable. All remain `PENDING`; approved=0, rejected=0, active exclusions=0. The tracked waiver CSV now points to the Round 9 candidate audit. The generated `.el` has no active directives. Raw is preserved unchanged.

The one-tap Identity DPD leaf proof remains PASS only within its proven no-stall scope (5/5 assertions, 3/3 covers, no assumptions or black boxes); full-chain Identity remains INCONCLUSIVE. The outstanding-counter guard assertions and exact Covers remain INCONCLUSIVE after the extended run (assertion depths 231/122; Cover depths 196/126; 1,364.76 s; zero assumptions and black boxes). Both guard branches remain OPEN.

## Linux checks run

| Check | Result | Evidence |
|---|---|---|
| Fresh VCS product compile | PASS, frozen product defines | `runs/thermo5_tx_closure_current/current_source_20261104/product_build/compile.log`, SHA-256 `5bc51c6295fdb0339ff8a075b5c9e0d22d3aa87c437fc2c1aee326c6e43ef07b` |
| AXI-Lite product configuration | PASS, seed 420101; one-tap config, four-plane bit-true compare, predictor mismatch 0; UVM W/E/F=0 | `runs/thermo5_tx_closure_current/linux_regression_20261103/axil_product_config_run.log`, SHA-256 `11e178006cb2241545a19858a695b628f18e9a951a5c070fffd281bcb96c4b51` |
| Current-source reset sweep | PASS, seed 610802; four partial DSP-frame resets and five CDC residual resets; bit-true replay complete; underflow/predictor mismatch/UVM W/E/F=0 | `runs/thermo5_tx_closure_current/current_source_20261104/product_build/thermo5_sku_axil_reset_sweep_test_seed610802.log`, SHA-256 `d59daee22ab3526cd6eeba0ffcb640bb69c7c4a2b91e123e7492754d9774a480` |
| Generic-core targeted UVM regression | PASS, seven cases; see retained run log | `runs/thermo5_tx_closure_current/linux_regression_20261103/generic_core_final3_regression.log`, SHA-256 `b3693f696e5a550692b9d7550db9022bebc92ee135c6c0155c746930dd84cc81` |
| Hardware utility tests | PASS, 43/43 | `python3.12 -m unittest discover -s tools/hw/tests -v`; log SHA-256 `1420689ed3c88d66a799e2dad208d4a8635a9f99908f9f84ebf548fc31a9708a` |
| Python integer reference tests | PASS, 59/59 | `PYTHONPATH="$PWD/dv/uvm/refmodel/python" python3.12 -m unittest discover -s dv/uvm/refmodel/python/tests -v`; log SHA-256 `e690a7f5ca9854d404d94ec3dee1d21d98ff842bae21813ee74aedbfe6b10bcc` |
| Same-list Raw/Adjusted URG | PASS; exact list, 0 exclusions, equal summaries | Report manifest SHA-256 `42861c12102b9cdd55cc51d8aed9a96ef9a70439839cc2e07434015def1fcf6a`; VDB manifest SHA-256 `81d1c0c64441c366795c415a91f4405a8bbe190033550805baafbc1076749fe6` |
| Fail-closed coverage gate | PASS with status `RAW_100_OPEN` | Gate JSON SHA-256 `fd9bf7d5a35cc38950ad94f00ef185a2b2a2b5f434bab0a02665a1f44523bcf6` |

The exact fresh VCS source/configuration manifest is `runs/thermo5_tx_closure_current/current_source_20261104/product_compile_manifest.json`, SHA-256 `36aacf88fa95269728eded27bc48e314c8e55877920379f70da00116b9a40d42`. Logs, vectors, reports and manifests are under ignored `runs/`; their hashes and paths are indexed by [`round 9 machine-readable evidence`](data/thermo5-tx-linux-signoff-round9-20261104.json).

After preserving the Round 9 evidence, `make -C dv/uvm/sim clean` removed 1,856 generated VDB directories and tool scratch trees, including all 18 root VDBs listed in the cleanup request. The logs, vectors, reports and manifests remain available. The VDB inventory and hashes are recorded, but URG must rebuild the databases before another merge.

## Remaining Linux closure

- Investigate and close reachable Branch, Condition, Line, and Toggle bins using legal public-interface stimulus and independent checkers; preserve all remaining bins as OPEN until then.
- Resolve the two outstanding-counter guard Branches; current product-bound Formal is inconclusive.
- Determine whether the two `q1_tail` properties need legal witnesses or a source-bound non-vacuous reachability proof.
- Improve full-chain DPD Identity Formal convergence.
- Resolve the source-gap/underflow operating contract; starvation evidence is not normal-stream signoff.
- Obtain independent waiver review before any exclusion is applied. Until then, Raw and Adjusted must remain identical.

## Outside Linux signoff

Real XPM FIFO simulation, GT Wizard simulation, FPGA PPA/routed timing, and physical RF/QAM256 BER remain unverified and require their vendor/platform flows. No FPGA or physical signoff is claimed.
