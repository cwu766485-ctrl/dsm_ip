# DSM V1.3 Round 5 — Coverage Closure Progress

Date: 2026-11-26 10:54 SGT

Source baseline: `work/dsm-v13-mash-uvm-round4` at
`2d2364f575d15bd2a3dafed4d45473db8cabbff1`. Round 5 branch:
`work/dsm-v13-mash-uvm-round5`.

## Status

**OPEN.** The requested 100% adjusted RTL code coverage and final DV sign-off
are not achieved. No Round 5 code exclusions were applied. The 2,463 Round 4
rows are module-page records, not demonstrated native instance-level bins.
Do not use their count as a per-instance numerator or denominator. The
functional adjusted closure reported in Round 4 remains scoped to its recorded
contracts and evidence; this report does not assert a new functional sign-off.

## Baseline parser audit

`round5_baseline_definition_inventory.csv` maps all 2,463 frozen rows to their
actual URG module titles, source locations, expressions, coverage kinds and
report hashes. The source file `rtl/dpd/dpd_poly.v` also declares
`dpd_sat_signed`: all 804 Round 4 rows from that file in the six Product
configurations map to `dpd_sat_signed`, not the `dpd_poly` module. This is a
module-definition report finding, not proof that the reported paths are
unreachable.

The old `coverage_id` collides across 1,922 rows; 983 extra rows have repeated
definition fingerprints under the audit's available fields. These are
collision indicators, not a count of redundant native URG bins: exact branch
or toggle identity and instance status still require extraction from the
instance-specific URG/VDB data. The separate instance percentage table lists
566 module-instance rows seen on the 61 referenced URG module pages. It does
not assert that a module-level missing bin is missing in every instance.
Native bin IDs, exact hit sets, parameter-instance applicability, and URG
numerator/denominator reconciliation are OPEN.

## Fresh replay and cumulative URG

The six Product/AXI-Lite builds were rebuilt from the Round 5 baseline. All
50 selected Round 4 VCS cases passed, and seven Round 4 configuration-local
URG runs passed. The MASH wrapper/core VDB was reused from Round 4; it was not
rebuilt or newly replayed. Fifteen Round 3 Product/AXI-Lite random campaigns
were then replayed against the six new binaries using their original vectors,
with vector SHA-256 checks and UVM checker PASS markers. All 15 passed. In
addition, all 31 Round 3 directed Product/AXI-Lite cases passed on the same
binaries. The six independent cumulative URG merges passed, with 20/21/13
Product VDBs and 13/14/15 AXI-Lite VDBs for EF1/EF2/MASH respectively. These totals include
isolated expected-negative VDBs from the original Round 4 selection; do not
interpret merged assertion failures without the existing isolation evidence.

| Configuration | Line | Branch | Condition | Toggle |
|---|---:|---:|---:|---:|
| EF1 Product | 88.38% | 75.92% | 80.03% | 84.38% |
| EF2 Product | 83.15% | 64.47% | 67.79% | 81.98% |
| MASH Product | 87.95% | 76.01% | 77.23% | 80.63% |
| EF1 AXI-Lite | 89.09% | 79.48% | 80.30% | 80.89% |
| EF2 AXI-Lite | 84.09% | 69.39% | 71.97% | 78.63% |
| MASH AXI-Lite | 88.71% | 79.66% | 80.30% | 76.63% |

All values are raw selected-DUT URG percentages. No reported metric decreased
against the replayed Round 4 selection. Equal or higher percentages do not
prove that every previously hit bin remains hit: a native-bin hit-set gate
is still required. The full Round 1–4 command inventory has not been replayed.

## Configuration observations

The testbench Product path drives one tap with identity coefficients tied at
its DUT ports. This is a **testbench constraint**, not a general proof that
Product input ports cannot receive other coefficient values. The AXI-Lite
path exposes writable C1/C3/C5 real and imaginary coefficient shadows and a
commit operation; reset identity does not prove non-identity values
unreachable. The six compile configurations and their preliminary parameter
values are in `round5_parameter_applicability.csv`; bin-specific parameter
propagation and proof remain OPEN.

## Remaining work

Complete native per-instance bin and direction extraction and reconcile URG
numerators/denominators. Rebuild and replay the remaining historical tests,
then enforce exact hit-set non-regression. Continue independent-checker DPD,
interpolator, gain, EF2 and MASH directed work; replay reachable formal
witnesses through the Product; prove and independently review only genuinely
unreachable exclusions. Audit all critical assertion antecedents and toggle
bits. A timeout or missing proof remains OPEN. No RTL ECO was made. CDC/RDC,
serializer, physical and board sign-off remain outside this result.

Run artifacts are under `runs/dsm_v13_round5_replay/`,
`runs/dsm_v13_round5_historical_random_v2/`,
`runs/dsm_v13_round5_historical_directed_v2/`, and
`runs/dsm_v13_round5_cumulative_urg_v2/`; generated logs and VDBs are not tracked.
The first historical replay had a harness-only false FAIL for the reset
campaign because its distinct PASS marker was not recognized; the logged UVM
run passed and the corrected replay passed all 15 cases.
