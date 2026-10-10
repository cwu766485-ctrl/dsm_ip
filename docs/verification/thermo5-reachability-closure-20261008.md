# Thermo5 coverage reachability review - 2026-10-08 (bit22 update)

## Decision

Coverage exclusions are limited to exact frozen-configuration evidence and
scoped proofs that are mapped to native URG signatures. They are an adjusted
view, not simulation hits and not a 100% signoff. Reachable bins remain in the
denominator until hit. Unreviewed vendor bins and inconclusive proof transfers
remain OPEN.

## Current-source long-stream result

The frozen SKU is INTERP_TAPS=2, DPD_MAX_TAPS=1 with identity coefficients.
The current 202 RTL/DV source package digest is
`0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`; the
compiled regression package manifest is
`runs/thermo5_frozen_regression_fwftmon_20261008/manifest.json`. The SKU
testbench SHA256 is
`ffed776359d7e25ddd2e7fd6125c83720ba26b36486fda3aa05bad70c4423e2e` and the
SKU config SHA256 is
`cc81f7bef5baa50e8cf8e7baea233c9e020ee1527415b937de4388b1fc3d80e3`.
The independent integer oracle generated 4,194,309 output words. Its first
2,097,158 words were checked against all eight files of the MATLAB-validated
fixture before the oracle extension was used for the longer run; see
`runs/thermo5_bit22_oracle_20261008/oracle_manifest.json`. Generic and real
Vivado XPM VCS runs both passed four-plane bit-true checking for all 4,194,309
words. Each then checked that all16 DPD lane counters clear after public
reset. Both logs report zero UVM errors/fatals, output=4,194,309, and the
long-counter reset PASS marker. Generic/XPM CPU times were 3,079.040/
3,112.410 seconds, seeds 610078/610079. Logs are under
`runs/thermo5_frozen_regression_fwftmon_20261008/{generic,xpm}/`.

The exact same-binary URG merge includes `simv.vdb`, the baseline root VDBs,
the explicitly added nested bit21 VDB, and the new bit22 VDB for each FIFO.
`tools/hw/thermo5_long_counter_delta.py` verifies that `sample_count[22]` toggled in both
directions in 16 distinct DPD lane instances for both FIFO models. Along with
the prior same-binary bit21 evidence, `sample_count[22:0]` is now hit in both
directions across all16 counters. `sample_count[31:23]` remains open: 9 bits x
2 directions x 16 instances = 288 reachable toggle bins per FIFO. No counter
bin was waived or internally forced. The per-bit evidence is in
`runs/thermo5_bit22_urg_20261008/{generic_delta_audit,xpm_delta_audit}/`.

Raw DUT hierarchy coverage:

| FIFO model | Overall | Line | Condition | Toggle | Branch | FSM | Assertions |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Generic | 87.16% | 86.85% | 78.90% | 84.73% | 72.45% | 100.00% | 100.00% |
| Vivado XPM | 80.12% | 76.73% | 68.84% | 82.05% | 62.19% | 90.91% | 100.00% |

## Reviewed adjusted URG

The reviewed exclusion generator checked current RTL source hashes against the
saved exact-bin ledgers and checked linked formal proof manifests for source
identity, blackbox count, and setup violations. Its policy permits only exact
configuration/scoped-proof records; it deliberately retains reachable
counter bits, unqualified interpolation payloads, unresolved XPM transitions,
and unmapped vendor candidates. The native URG exclusion files are under
`runs/thermo5_bit21_reviewed_exclusions_20261008/{generic,xpm}/`; each
`manifest.json` contains selected counts, proof-manifest hashes, and any
unmapped candidates. The adjusted URG reports were rerun on the same VDB sets.

| FIFO model | Adjusted score | Line | Condition | Toggle | Branch | FSM | Assertions |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Generic | 99.66% | 99.84% | 100.00% | 99.62% | 98.51% | 100.00% | 100.00% |
| Vivado XPM | 96.71% | 99.43% | 91.16% | 99.61% | 93.30% | 96.77% | 100.00% |

These adjusted percentages are the reviewed bit21 view only; the exclusions
were not rerun against the bit22 databases. The table above is the latest raw
bit22 URG result and must not be combined with bit21 adjusted percentages as
if they came from one report.

Adjusted means exact bins have been removed from the URG denominator under
documented evidence; it must never be described as raw coverage or 100%.
Generic still has four interpolation round/saturation line bins, four related
branch arms, and the 288 reachable counter toggles open. The interpolation
interval proof covers valid payloads only; it does not cover invalid startup
payload evaluation.

XPM still has the same 288 reachable counter toggles, 14 vendor line, 44
condition, 46 branch, and 37 toggle bins, plus one `curr_fwft_state` transition
(`stage1_valid -> invalid`) open. The exact residual inventory is in
`runs/thermo5_bit21_reviewed_exclusions_20261008/xpm/inventory/`.
Nineteen exact vendor branch candidates could not be mapped to the
reviewed exclusion signatures and remain open; vendor ownership alone is not a
waiver. The reset/FWFT properties that were inconclusive remain open. Details
and hashes are in the XPM exclusion manifest and the existing
`thermo5-xpm-exact-followup-20261007.md` review.

## Commands and evidence

The bit20, bit21, and bit22 oracle/long-stream commands, run logs, binary
provenance, and raw URG directories are retained under `runs/thermo5_bit{20,21,22}_*` and
`runs/thermo5_frozen_regression_fwftmon_20261008`. The exact exclusion command is reproducible
with `tools/hw/thermo5_urg_exclusions.py`; its inputs are the matching
`thermo5_converge_long_20261007/ledger` files, same-source proof manifests,
the XPM vendor review manifest, and the fresh native URG `fullexclude.*` dump.

To re-audit the bit22 raw delta, use the corresponding bit21 `all_current_plus_bit21`
directory and bit22 `generic` or `xpm` URG directory as `--before` and `--after`
arguments to `tools/hw/thermo5_long_counter_delta.py`. The helper requires 16
distinct lane instances and both toggle directions for the selected bit, and
records the full per-bit JSON/CSV result; it applies no exclusions.

No RTL, MATLAB model, testbench, or bit-true check criterion was changed for
this closure.
The worktree already contained unrelated user changes; no existing changes or
generated run artifacts were deleted.

## Remaining work

1. The next natural threshold is bit23. A complete 8,388,615-word run is
   expected to take roughly 105 minutes per FIFO at the measured bit22 rate;
   this is a cost estimate, not an unreachability argument. Never force or
   deposit internal counter state to manufacture toggle coverage.
2. Review each remaining XPM vendor condition/branch/toggle using exact source
   and native signatures. Keep unmatched and inconclusive items OPEN.
3. Keep the FWFT `stage1_valid -> invalid` transition OPEN until a legal
   external reset sequence hits it or a non-vacuous proof establishes its
   unreachability under the frozen integration contract.
4. Do not claim coverage closure while any reachable bin remains unhit.

At the measured bit21 throughput (about1,460 checked output words/s per VCS
run), a natural bit31 rising edge would require about17 days per FIFO run.
This is a cost estimate, not a proof of unreachability and not a waiver basis.
