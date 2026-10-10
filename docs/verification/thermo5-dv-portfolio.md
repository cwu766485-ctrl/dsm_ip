# Thermo5 graduate design-verification evidence

Scope: frozen thermo5, two-tap interpolation, one-tap identity memory-DPD,
125 MHz AXI ingress, and four 64-bit output planes. Generic and real Vivado
XPM FIFO builds are compiled and measured separately. The project is a
graduate DV portfolio, with explicit integration limits rather than a claim
of production or board signoff.

## Current-source status (2026-10-08)

The local licensed current-source package passed for RTL/DV digest
`0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8` (202
files; worktree dirty). Generic and real-XPM bit22 long streams each passed
4,194,309 four-plane output words, with all 16 DPD lane counters cleared after
reset. The same-source URG delta confirms `sample_count[22]` toggled both ways
in all 16 lanes for both FIFO builds. Latest raw URG is 87.16% generic /
80.12% XPM. Reviewed exact-bin adjusted views remain the older bit21 reports
(99.66% / 96.71%) and were not recomputed for bit22; neither view is 100%.
Bits31:23, generic interpolation bins, and XPM vendor/FWFT bins remain open.
See the
[`current reachability ledger`](thermo5-reachability-closure-20261008.md) and
[`frozen-SKU feature matrix`](thermo5-frozen-sku-signoff-plan.md). Historical
scores and run directories below remain tied to their original dates/source
snapshots and are not the current totals.

## Coverage closure with an independent checker

Latest follow-up: `runs/thermo5_coverage100_closure_final_20261006/` has
raw scores **87.47% generic**, **80.25% XPM**, with no exclusions. All sixteen
DPD bits5:14 are both-direction hits after a 16,387-word oracle stream and
public reset; signed-gain saturation and pre-first-frame empty-core checks
also pass. Production-width unbounded counter proofs now cover all 32
bit/carry relations. See `thermo5-coverage100-assessment.md` for the updated
closure table, complete denominators, formal limits and board-free graduate
priorities. The evidence/table below describes the previous delivery.

Final evidence directory: `runs/thermo5_dv_package_delivery_20261006/coverage/`.
For each FIFO, `baseline/<fifo>/coverage/` is the before report and
`baseline/<fifo>/coverage_after/` is the after report. Both use the same
compiled `simv` and `simv.vdb`. Each test records its seed, oracle hash,
binary hash, log, command, and VDB in `closure.json`. The raw scores are
generic **87.00% -> 87.19%** and XPM **79.96% -> 80.06%**. The vendor
hierarchy makes the two implementations non-comparable.

| Gap and unhit cause | Legal stimulus | Independent checker | Same-build URG / formal result |
| --- | --- | --- | --- |
| Generic `u_interp_1:71`, operand `1/0`. Previous fixed-cycle stalls arrived before or after the bubble/occupancy window. | Send 24 beats before an 80-source-cycle bubble. On a core falling edge, observe stage1 empty with stage2/output valid, then hold only public PA ready low for 200 cycles. No internal force. | Source monitor checks 32 accepted beats and metadata; PA monitor checks held payload; scoreboard checks 56 words against four independent MATLAB planes. | Generic target row `Not Covered -> Covered`, 138 observed target cycles. XPM baseline already covers that row; directed case observes 139 cycles and retains `Covered`. |
| 162 TID bit15 rows per FIFO. Small-amplitude/random inputs and lane-varying extremes did not drive every offset branch through both signs after interpolation. | Signed endpoints plus four-word endpoint plateaus at unity gain, preserving the frozen two-tap/identity SKU. | Endpoint test checks 32/56 beats/words; plateau test checks 1184/2072. Every output plane is checked against MATLAB; source data/metadata and all 16 DPD counters are checked. | All **162/162** previously uncovered individual bit rows have **both 1->0 and 0->1 = Yes** in generic and XPM. `toggle_bit_delta.csv` expands URG ranges and requires the after bit to exist. |
| DPD count bits5:10. A 56-word frame does not reach enough counter transitions. | Continue across frame markers to 2072 words without resetting, with legal random PA backpressure. | Independent four-plane oracle plus each lane `sample_count=2072` and `saturation_count=0`. | All 16 lanes gain both directions for bits5:10; bit11 gains 0->1 only. Bits31:12 remain red in raw URG. |
| DPD count bits31:12 and bit11 falling. These require at least 4096 accepted samples since reset, exceeding the 2072-word experiment. | Scoped formal permits arbitrary signed payload and legal stalls; an independent ghost acceptance counter bounds each reset epoch to 2072. | Production `dpd_memory_poly` counter is compared to the interface acceptance count; bound and high-zero invariants are asserted. Accept, count-change, stall and recovery covers prevent an empty test environment. | Three assertions proven, four covers covered, two environment assumptions non-vacuous. `sample_count[31:12]==0` is proved **only within the 2072-input budget**. Monotonic count within that budget cannot fall from bit11=1 to 0. Unbounded high-counter verification remains OPEN; no raw URG exclusion is applied. |
| Reset `u_s_reset/u_c_reset:27`, operand `1/0`. Async clearing removes old stage0 before a separated active clock edge; a same-slot scheduling collision can expose old state. | Focused simulation asserts/releases reset away from active edges. Formal drives runtime reset on the falling edge, with reset release and later reassertion allowed. | Simulation checks asynchronous assertion and two-edge release in both clocks. Formal asserts cleared stage0/output and valid release; covers held reset, first release sample, released state and reassert/release. | Three assertions proven and non-vacuous; four normal covers covered; collision cover **uncoverable in the stated falling-edge model**. This is scoped disposition, not a full asynchronous timing/metastability proof. Red raw URG rows remain visible. |

Functional event coverage, raw code coverage, and scoped formal disposition
are distinct. No percentage is recomputed by silently dropping unreachable
rows. A legal source bubble intentionally creates FIFO starvation in the
interpolation test; the test checks protocol integrity and every final output
rather than treating that expected diagnostic as an unexpected failure.

## Two real bug cases with negative controls

Historical fix: `6deb79903b80a01a8d03b97afe71a247c7319c60`. The faulty
versions reconstruct its failure mechanisms on isolated current-wrapper
copies; they are not complete historical source revisions. Detailed AXI-Lite
sequences and limitations are in `commit-bug-case-studies.md`.

| Trigger | Incorrect behavior | Root cause | Fix | Regression evidence |
| --- | --- | --- | --- | --- |
| Unsafe commit is rejected; safety is disabled and a valid identity coefficient is committed without clearing the old sticky rejection. | New legal request is incorrectly rejected. | Previous sticky error is read before the new commit pulse has cleared it. | Gate failure classification with `!mp_commit_pulse`. | XSim and VCS fixed variants pass; removing only the guard triggers `BUG_STALE_REJECTION`. Legal AXI-Lite drives all operations. |
| After one successful commit, accept an AXIS sample, request a busy commit, then issue a legal soft-reset control write. | Cancelled transaction reports epoch=2, ack=1, bank=1. | Pending/inflight wrapper state survives reset and stale bank equality is classified as completion. | Guard completion with `!soft_reset`; cancel pulse, pending, inflight, ack, failed and target on reset. | XSim and VCS fixed variants preserve epoch=1, clear transaction state and restore bank0; faulty copies trigger `BUG_RESET_COMPLETION`. Reset/pending overlap is checked. |

## Reproducibility and automation

From Windows, with Rocky's configured licensed Synopsys environment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File dv/uvm/sim/run_thermo5_dv_package_wsl.ps1
```

From licensed Linux, choose a new output directory:

```bash
python3.12 dv/uvm/sim/run_thermo5_dv_package.py \
  --xpm-root /path/to/Vivado/2024.1 \
  --range-vectors runs/thermo5_gap_vectors_20261006/range_long \
  --out-dir runs/thermo5_dv_review
```

`--dry-run` writes a command plan without claiming a tool PASS. Required
local vector sets are the baseline 56-word set, independent payload seeds
101/202/303, endpoint 56-word set, and MATLAB-generated plateau 2072-word
set. They and the Vivado vendor sources remain local generated inputs; a
clean checkout must generate/stage them before running licensed jobs.

Outputs include `dv_package.json`, `diagnostics.json`,
`coverage/coverage_summary.md`, `coverage/closure.json`, per-FIFO
`toggle_bit_delta.csv`, `formal/formal_summary.json`, and
`bugs/summary.json`. Scoreboard/assertion failures and expected negative
controls are normalized into one diagnostic schema. Nonzero job status or a
missing checker/report gate fails the package. Source state includes commit,
dirty state and SHA256; test records include seeds, vector/binary hashes and
VDB paths; formal records include assertion, cover and vacuity gates.

The CI workflow `.github/workflows/thermo5-dv.yml` runs Python syntax checks
on hosted runners. Its manual licensed job requires
`THERMO5_LICENSED_CI=enabled`, a trusted `self-hosted,linux,synopsys` runner,
`THERMO5_VECTOR_ROOT` with `base/`, `endpoint/` and
`vectors_seed{101,202,303}/` for staging, `THERMO5_XPM_ROOT`, and
`THERMO5_RANGE_VECTORS`.
It executes simulation/scoreboard, VCS compiler lint diagnostics, and scoped
VC Formal. Compiler lint diagnostics are not a SpyGlass lint signoff.
The workflow has not been executed on GitHub in this session; the same
package entry is validated locally. An exploratory SpyGlass probe completed
with 3 errors and 49 warnings using the default top parameters (missing XPM
definition and an undersized tool memory threshold); it is not frozen-SKU
lint evidence or lint signoff. The report is preserved under
`runs/thermo5_lint_probe_20261006/` and requires a scoped frozen top before
acting on its remaining source warnings.

## Remaining integration limits

Two GT CDC-11 paths, actual parent I/O budgets, RX loopback and physical board
output remain OPEN. Raw high-counter URG hits, vendor bins and reset timing
outside the stated model remain OPEN. The unbounded counter transition
properties are proven; formal hits are not substituted for raw URG. These limitations
do not prevent showing the digital DV methodology and reproducible evidence
for graduate recruitment, but they prohibit full-system signoff claims.
