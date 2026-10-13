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

## Public-reset FWFT phase follow-up (2026-10-12)

A fresh XPM UVM binary was compiled from the current source with VCS
V-2023.12-SP1 and the Vivado 2024.1 XPM simulation models. Using only public
reset requests and read-only FWFT observation, the same binary ran:

- 16 prefetch-only attempts that waited until `stage1_valid` was observed and
  then asserted the common public reset at source-clock phases from0 to7.5ns
  in0.5ns steps;
- 400 prefetch-only reset-request trials (all 16 source-clock phases times 25
  core-clock delays); and
- 48 four-beat-prefix reset trials (four source-clock phases times 12 delays).

All 464 reset trials completed the 56-word four-plane oracle replay with zero
UVM errors/fatals. A baseline 56-word bit-true run was merged with these VDBs
using URG from the exact same binary. Report:
`runs/thermo5_xpm_fwft_phase_sweep_20261012/coverage_all_16phase_reset_sweeps/`.
`curr_fwft_state` is now 8/9 transitions: the previously missing
`both_stages_valid -> invalid` reset transition is Covered, but
`stage1_valid -> invalid` at vendor line1277 remains Not Covered. The isolated
post-stage1 attempt observed state `2'b10` with `rd_rst_i=0`, but waiting until
that observation before requesting reset is too late to align the internally
synchronized reset to the next FWFT edge. Expanding the legal public-reset
request search over all 16 source phases and 25 core delays did not hit the
transition either. It remains OPEN; no internal force/deposit or waiver was
used.

Per-run logs and VDBs are in the same run directory. The next experiment should
assert the public reset request before the stage1 window and correlate the
read-only `curr_fwft_state`/`rd_rst_i` values at each core edge. This remains a
testbench phase-search task, not a claim that the transition is unreachable.

## Edge-aligned observation follow-up (2026-10-12)

The reset-phase UVM test now optionally samples XPM FWFT state and `rd_rst_i`
before and after each `posedge core_clk` using `+FIFO_RESET_EDGE_OBSERVE`. For a
prefetch-only attempt, `+FIFO_RESET_WAIT_FWFT_STAGE1` asserts the common public
reset immediately when `stage1_valid` is observed instead of waiting another
core edge. The compiled XPM run passed its bit-true baseline and targeted reset
replay with zero UVM errors/fatals. Its trace observed `stage1_valid` with
`rd_rst_i=0`, then `stage2_valid`; `rd_rst_i` asserted two core edges later.
The exact target transition was not hit.

A new 400-point edge-observed public-reset search swept16 source-clock phases
by25 core delays. All trials passed their four-plane replay and UVM error/fatal
checks; across the sweep there were 5,464 stage1 edge samples, zero samples
with stage1 and `rd_rst_i` simultaneously asserted, and zero
`stage1_valid->invalid` transitions. This is phase-search evidence only, not a
formal reachability proof or waiver. The transition remains OPEN. Runner,
summary, and logs are under `runs/thermo5_xpm_fwft_edge_observe_20261012/`;
runner: `dv/uvm/sim/run_thermo5_xpm_fwft_edge_sweep.sh`.
