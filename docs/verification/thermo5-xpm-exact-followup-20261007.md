# Thermo5 XPM exact-bin follow-up

Date: 2026-10-07. Scope: the frozen `INTERP_TAPS=2`, identity `DPD_MAX_TAPS=1`
SKU with the actual Vivado 2024.1 XPM FIFO. This is an instance/bin triage of
the completed same-build run at
`runs/thermo5_followup_long_20261007/evidence_index.json`, not a new URG
merge, coverage waiver, or board/CDC signoff.

## Exact residual denominator

Raw XPM coverage is 80.27%; the guarded, scoped adjusted result is 97.08%.
The adjusted remainder under `runs/thermo5_followup_long_20261007/remaining_final/`
is 15 missing line bins, 32 condition bins, 461 toggle directions, 50 branch
arms and one FWFT FSM transition. The line CSV has 14 rows because vendor
memory line 4227 represents two missing bins. Of the 461 toggle directions,
448 are the 16 production DPD counters' bits 31:18. The other 13 directions
belong to vendor startup/reset/collision signals; they must not be conflated
with the legal high-counter backlog. Generic and XPM denominators differ.

## Cost-ranked, exact next checks

| Priority | Exact rows and reason | Bounded next experiment / evidence | Current disposition |
| --- | --- | --- | --- |
| 1 | `rtl/axis/dsm_xpm_async_fifo.sv:52,57,59`: exact reset-condition rows, including `wr_reset_sync[1]=1, rd_reset_sync[1]=0` and opposite-domain ready/valid guard combinations. | The GT parent asserts both reset requests in one epoch; single-sided full-chain reset violates that contract. The common-assert/core-first-release full-chain test is complete on the frozen-baseline XPM `simv`, with no-handshake guards and complete 56-word four-plane replay. Single-sided requests remain a separate block-level XPM-wrapper test, not a full-chain oracle claim. | **Test complete; residual tuples OPEN**. The exact same-binary URG delta is recorded in the Oct 8 section below. |
| 2 | Vendor `xpm_fifo_base` FWFT `curr_fwft_state` has eight of nine transitions; the missing `stage1_valid -> invalid` corresponds to synchronous `rd_rst_i` at vendor line 1277 while stage 1 is occupied. | Bounded attempt `runs/thermo5_xpm_fwft_reset_attempt_20261008/` observed stage1_valid with `rd_rst_i=0`, then asserted the legal common public reset and completed a 56-word four-plane replay. Same-binary URG did not hit the transition. Vendor logic advances stage1_valid to stage2_valid when RAM is empty or both_stages_valid when nonempty on the next read edge; the public reset path reaches XPM `rd_rst_i` through the wrapper write-clock synchronizer and XPM read-domain reset synchronizer. | **OPEN**; exact transition remains Not Covered before and after. No exclusion or qualified unreachable proof is claimed. |
| 3 | Vendor memory collision-window lines 3516-3521 and related conditions use `t_half_period_a/b <= 1500 ps`. In this testbench, the two free-running half-periods are 4000 ps and 2286 ps; the vendor model initializes both measured values to 3000 ps. | Map the simple fixed-clock proof below to each native URG statement/condition and rerun adjusted URG before any exclusion. Do not alter clocks solely to raise coverage. | **SCOPED_UNREACHABLE under the exact testbench clocks**; native URG transfer is still OPEN. |
| 4 | Vendor memory collision/read-X modeling at lines 4174-4181 and 4221-4227, including `force` and `release` of internal data; numerous remaining condition/branch arms describe asynchronous same-address collisions. | First establish a protocol-level no-overwrite/no-read-collision invariant for the actual FIFO and clock/reset contract. If a legal collision is reachable, use a separate checker that treats vendor X behavior explicitly; never force an internal collision for a numerical PASS. | **OPEN**; no safe transfer or exclusion proof accepted. |
| 5 | Vendor `glblGSR_xpmcdc`, `power_on_rst`, pointer CDC reset branches and memory period-detection toggles account for the 13 non-counter missing toggle directions. | Separate startup-only global GSR from runtime reset; bind the existing vendor reset-default proof (3/3 assertions, 3/3 covers) only to exact matching signals and source hashes. Verify each native URG direction before exclusion. | **OPEN** in adjusted URG. |
| 6 | Four project interpolation clamp line bins and four branch arms at `dsm_interp_x2_polyphase_vector.sv:91-92`. The existing formal bound is valid-payload qualified; the function can also evaluate invalid startup payload. | Add an explicit initialization/observability model or prove the clamp function bounds for every evaluated input. Do not transfer valid-only proof to invalid slots. | **OPEN**, separate from vendor XPM. |

Vendor XPM source was read-only; no vendor file or production RTL was edited.
For priority 3, `thermo5_sku_uvm_tb.sv` drives source `always #4` and core
`always #2.286` under `timescale 1ns/1ps`. The compiled XPM memory model
uses `timescale 1ps/1ps`, initializes both `t_half_period_*` variables to
3000 ps, and replaces each only once with the difference between its first
positive and negative clock edges. Therefore their complete value sets are
`{3000,4000}` ps and `{3000,2286}` ps, both strictly above 1500 ps. In the
fixed, free-running two-clock VCS testbench, the `<=1500` arms at vendor
lines 3516 and 3518 and the final fallback at 3521 cannot execute. The
reviewed vendor source SHA256 is
`103747b8aa5fec30dbcfe5b432a94e5a6153c02acc359b81e3d4d8692c479779`;
the testbench SHA256 is
`b35fd2791b4641d39c649e5a6dbcc7f9795031cda1ede98e85202cafe24e46ea`.
The matching VCS compile log names this vendor source. This is a scoped
parameter/timing proof, not a hardware collision proof and not an applied
native URG exclusion. A clock-generator change invalidates the argument.

The current focused reset-default formal manifest is PASS at
`runs/thermo5_xpm_reset_defaults_20261007/manifest.json` (3 assertions,
3 covers), but its exact URG transfer is not signed off. The separate FWFT
formal run is `FAIL_OR_INCONCLUSIVE` and supplies no closure.

## Execution blocker and next gate

The historical VHDX/license blocker is resolved. On 2026-10-08 the reviewed
Rocky license-health task reported a responding server. The modified-source
frozen generic/XPM regression passed at
`runs/thermo5_frozen_regression_fwftmon_20261008/manifest.json` with RTL/DV
digest `0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`.
The 131075-word four-plane closure passed at
`runs/thermo5_gap_closure_fwftmon_20261008/closure.json`. Core-first and
FWFT-target tests were then run on the same baseline XPM `simv`; all same-binary
VDBs merged to
`runs/thermo5_gap_closure_fwftmon_20261008/xpm_coverage_final_with_reset_fwft`.
Final raw DUT scores are 87.49% generic and 80.29% XPM. Prior adjusted
full-regression percentages were not recomputed for this modified UVM source.

The earlier Oct-8 same-binary comparison (before the read-only FWFT monitor
was added) is preserved at
`runs/thermo5_modified_source_gap_closure_20261008/xpm_coverage_core_first_final/exact_condition_delta.json`.
The new legal sequence asserts both public reset requests together, releases
core reset before source reset, checks for source/PA handshakes throughout the
common reset epoch, and independently replays all 56 four-plane words. It hits
XPM wrapper line 52 tuple `1/0`; line 57 tuple `1/1/0/1` was already covered by
the broader frozen baseline. Remaining exact wrapper rows are line 57 tuple
`1/1/1/0` and line 59 tuples `1/0/1/1`, `1/1/1/0`. They remain OPEN. No raw or
adjusted 100% result is claimed. A first Oct-8 package attempt used the
16,387-word directory with a 131,075-word parameter and stopped at preflight;
its partial evidence is preserved under
`runs/thermo5_current_source_dv_20261008/`.

The bounded FWFT attempt compiled a matching binary from the three UVM source
files listed with SHA256 in
`runs/thermo5_xpm_fwft_reset_attempt_20261008/exact_fwft_transition_delta.json`.
Its baseline bittrue test and reset-phase test both passed; the latter logged
`stage1_valid` (`2'b10`) with `rd_rst_i=0` at 336042 ps before common reset,
then passed all 56 oracle words/four planes with zero UVM errors or fatals.
Same-binary URG changed from 7/9 to 7/9 FWFT transitions; exact line 1277
`stage1_valid->invalid` stayed Not Covered. The experiment-only total score
changed 72.07% to 72.24% (top hierarchy 72.02% to 72.22%); these are not full
regression scores. This legal path therefore remains OPEN; no force/deposit,
waiver, exclusion, or hardware-level unreachability claim was used.

The latest-source final reset/FWFT comparison is recorded at
`runs/thermo5_gap_closure_fwftmon_20261008/exact_final_delta.json`. The same-
binary final merge hit wrapper line 52 tuple `1/0`; line 57 tuple `1/1/1/0`
and line 59 tuples `1/0/1/1`, `1/1/1/0` remain OPEN. The stage1-observed
public-reset test passed its oracle replay but did not hit
`stage1_valid->invalid`, which remains OPEN (8/9 FWFT transitions).

## Fresh source-bound package rerun (2026-10-08)

`runs/thermo5_current_source_dv_resume_20261008/coverage/closure.json` is a
fresh licensed same-source package closure (digest
`0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`). Raw XPM
coverage is80.27% after its 131075-word stream; this package report does not
include the separate core-first/FWFT VDBs used in the80.29% final merge above.
Its exact newly covered XPM condition is vendor line754 tuple `1/0`. The
project reset rows and the `stage1_valid->invalid` transition remain OPEN per
the separate exact same-binary comparison. Adjusted URG was
NOT_RECOMPUTED: the old candidate ledger denominator matches, but4,358 project
rows cite a changed testbench source hash and6,124 vendor rows are unhashed.
No exclusions or prior candidate dispositions were carried forward.
