# Thermo5 TX Final Closure Baseline

- **Status:** `BASELINE_REVIEWED; PHASE1_LINUX_COMPLETE`
- **Date:** 2026-10-30 (Asia/Singapore)
- **Current base:** PR #7 head `f5394c3eaa6d283caf91c5c64b08a7d83c714a57`
- **Working branch:** `codex/thermo5-tx-final-closure` (independent follow-up; no merge performed)

## Scope and immutable product contract

This closure package covers the thermo5 transmit path. The frozen product
configuration is the GT-parent TX setting: centered-cubic x2+x2 interpolation,
EF2 TIDSM order 2, `STEP=5120`, 20-bit EF2 state, chronological sample order,
32 lanes, four thermometric output planes, `DPD_MAX_TAPS=1`, and the reset
identity coefficient image (`C1_RE[0]=0x4000`, all other coefficients zero).
The Linux VCS product configuration elaborates the Generic asynchronous FIFO
as a substitute for XPM. It does not elaborate the GT Wizard or establish a
physical four-lane RF path.

No RX, AI-DPD, TX algorithm RTL, default coefficient image, or product
configuration is changed by this follow-up. Algorithm candidates remain
separate benchmark configurations. The VCS product hierarchy and source of
truth are the actual TX parent and the thermo5 UVM filelist, not candidate
test configurations.

## PR dependency and source audit

The live PR stack is open and unmerged. Commit ancestry is continuous through
PR #7:

| PR | Head | Parent/base relationship | Scope/result retained |
| --- | --- | --- | --- |
| #2 | `494fb2c3cbb9aa964a589bf0b5aa545cdabf6fe6` | `thermo5` (`eb1081bc...`) | Gate 0 Generic/Linux baseline |
| #3 | `813db9c9a488b033dc4686553cbe3a06856acc0b` | PR #2 head | Gate 1 bit-true and Formal candidate equivalence |
| #4 | `d65ac3762d344c1001552890ae81cd9d243a4910` | PR #3 head | Gate 2 held-out Python model campaign |
| #5 | `0c974aa45b8875794d33195530242320b419c249` | PR #4 is an ancestor; PR #5 adds the Gate 3 report/fix commits | Historical multi-configuration Gate 3 evidence |
| #6 | `006d52deaaf8ef3980461a6d4efdf1d2c0aa7011` | PR #5 head | Product-only DUT denominator and waiver gate |
| #7 | `f5394c3eaa6d283caf91c5c64b08a7d83c714a57` | PR #6 head | Linux product coverage follow-up, Formal reachability and closure evidence |

PRs #2–#7 remain open and have not been merged. The current follow-up starts
from the exact PR #7 head and is intended as a new stacked PR. The complete
historical branch graph is locally available as `origin/pr/2` through
`origin/pr/7`.

Three source identities must remain distinct:

1. **Repository/report revision:** PR #7 head above. It includes later
   Formal-only harness and documentation changes.
2. **Product VCS source set:** `913be930bfcbbad0f78dbc90e06299db3d1bb337`,
   the exact simulation-input revision cited by the latest product report.
   The PR #7 Formal-only harness is not in
   `dv/uvm/sim/thermo5_sku_filelist.f`; it does not change this product VCS
   source set.
3. **Latest coverage-producing source revision:**
   `c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b`, tree
   `694457bbacf2eda2a061da910f404975fd75ec8d`. The later PR #7 commits add
   Formal-only evidence and do not alter the product simulation filelist.

The simulator setup recorded by the product run is VCS
`V-2023.12-SP1_Full64`, UVM through the licensed VCS distribution, top
`thermo5_sku_uvm_tb`, Generic FIFO, `THERMO5_USE_AXIL=1`,
`THERMO5_CENTERED_CUBIC=1`, `THERMO5_TIDSM_ORDER=2`, `THERMO5_STEP=5120`, and
`THERMO5_DPD_MAX_TAPS=1`. The product URG run includes 29 product-scoped
simulation VDBs plus the compile VDB; expected-negative and candidate VDBs are
not merged into product Raw coverage.

The Python golden/reference is the Python 3.12 fixed-point model under
`dv/uvm/refmodel/python/dsm_refmodel/`, primarily `thermo5.py`,
`thermo5_experiments.py`, and `thermo5_receiver.py`. Python 3.12 is available;
MATLAB is not required for Linux reference generation. The exact VCS input
source hashes and product configuration are indexed by
[`thermo5-tx-linux-coverage-closure-evidence.json`](thermo5-tx-linux-coverage-closure-evidence.json).

## Reconciled verification evidence

| Evidence family | Latest retained result | Current interpretation |
| --- | --- | --- |
| Gate 0 Generic/Linux baseline | PASS at verification SHA `04550289e1ecb5fa0e38168869d4f2539929cb80` | Historical evidence remains valid for its recorded source/configuration; do not call it a vendor-XPM or board signoff. |
| Gate 1 pair look-ahead and DPD candidate bit-true | VCS miter and scoped Formal pass; existing 2/4-tap images match their Python oracle | Candidate equivalence is retained. No hardware PPA evidence; old hand-picked DPD images are not fitted performance evidence. |
| Gate 2 QAM256 model campaign | 4 development + 4 held-out seeds; 12 symbols/seed; STEP 5120; digital BER `21/224256 = 9.3643e-5`, EVM 2.4640%, SNDR 32.1675 dB | Synthetic model screen only. Product BER/BLER/EVM/ACLR limits are undefined; no stable-link signoff follows. |
| Current product Raw code coverage | 81.99% aggregate; line 3190/3796, condition 583/846, branch 440/637, toggle 86951/104478, FSM state 13/13, transition 22/22 | Raw and adjusted are identical; zero approved waivers/exclusions. `RAW_100_OPEN` remains. |
| Current product Functional Coverage | 170/174 raw; all 170/170 legally applicable positive bins hit | Four raw bins remain under audit; candidate and expected-negative bins stay separate. |
| Current product Assertions | 13 successful, 2 uncovered, 2 without attempts, 0 failures; 13/15 attempted | Coverage evidence, not an all-assertions closure claim. |
| Formal | EF2 safety and several parameter/frame-tail/AXI-Lite reachability checks pass; DPD identity proof remains 1/13 proven, 12/13 inconclusive | Retain each proof’s exact scope. No blanket formal signoff. |

The latest open product gap ledger contains 18,593 rows and no extraction gaps.
The current code-coverage disposition is `RAW_100_OPEN`, with zero denominator
edits and zero waivers. The exact latest Raw report, source manifest, command,
and report hashes are listed in the PR #7 evidence JSON and the product
coverage report. Coverage data is not regenerated by this baseline review.

## Evidence-manifest integrity notes

- PR #5’s published source-file manifest is historical and is retained as
  published. Its evidence JSON reports five directory-tree digest mismatches
  out of twelve audited directories, despite matching file counts and byte
  totals. Seven directory hashes match. This remains an open reproducibility
  discrepancy; it is not repaired by rewriting historical hashes.
- PR #6’s product manifest is tied to its PR #6 source/configuration. Its
  source file hashes cannot all match the later PR #7 tree, and some artifacts
  are absent from the current local evidence snapshot. It remains historical;
  use the PR #7 exact-source product evidence for current coverage.
- PR #7’s latest product source manifest matches the VCS simulation input
  source set. Its exact raw URG report tree, raw summary tree, and gap-ledger
  tree have verified directory digests in the current local snapshot. The
  Formal-only harness revision is separately identified and is not silently
  mixed into the VCS run identity.
- Historical `PASS` labels are preserved only with their recorded source SHA,
  tool, configuration, and scope. No full Gate 0–3 regression is rerun as part
  of this Phase 0 review.

## Tool boundary

Available on the current Linux host: Python 3.12, Synopsys VCS, URG, Verdi,
and VC Formal. Vivado, XSim, and vendor XPM/GT Wizard sources are not available
in this Linux flow. The follow-up may run Generic-FIFO VCS and scoped Formal;
it will not claim routed FPGA timing/PPA, vendor GT behavior, or physical
QAM256 BER.

## References

- [Product-only Linux coverage closure](thermo5-tx-linux-coverage-closure.md)
- [TX final signoff status](thermo5-tx-final-signoff.md)
- [Algorithm A/B and equivalence evidence](thermo5-tx-algorithm-ab.md)
- [Current Phase 1 architecture and fitted-DPD ablation](thermo5-tx-design-ablation.md)
- [Gate 2 worst-case/model report](thermo5-tx-worst-case.md)
- [Feature/testpoint/coverage matrix](thermo5-tx-feature-matrix.md)
- [Gate 3 source and artifact manifest](thermo5-tx-gate3-evidence.json)
- [Latest product-only closure manifest](thermo5-tx-linux-coverage-closure-evidence.json)
