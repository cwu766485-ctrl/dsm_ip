# Frozen thermo5 instance gap closure

## Current selected-gap result (2026-10-06)

Superseding follow-up: `runs/thermo5_coverage100_closure_final_20261006/`
is PASS, with raw generic **87.47%**, XPM **80.25%**, zero exclusions.
All sixteen counters now cover bits5:14 in both directions (long stream
then checked public reset); bits31:15 remain reachable/unhit. Legal signed
gain stimulus closes frame-gain saturation; pre-frame enabled empty-core
stimulus closes generic CDC line190 `0/1/1`. The complete bin denominator
and next OPEN items are in `docs/verification/thermo5-coverage100-assessment.md`.
Unbounded full-width counter transitions have 35 proven assertions and four
covers. Arithmetic remains inconclusive; the exact-clock generic residual
repeat passes four assertions, nine covers and non-vacuous source stability,
zero black boxes. Raw URG remains unchanged. Older records follow.

The active evidence is `runs/thermo5_dv_package_delivery_20261006/` and
`docs/verification/thermo5-dv-portfolio.md`. Generic interpolation exact bin
is newly Covered; XPM was already Covered. All 162 TID bit15 gaps per FIFO
have both directions hit. DPD bits5:10 have both directions, bit11 rising
only, and high bits have a scoped <=2072-acceptance formal proof. Reset
collision bins are uncoverable in the explicit falling-edge-reset model,
with three non-vacuous assertions and four normal covers. Raw formal-related
URG gaps are retained; unrestricted high counter/reset timing, GT CDC-11,
real I/O timing, RX and board output remain OPEN. The older assignments and
OPEN notes below are historical planning records.

Date: 2026-10-06. Planning/review owner: primary GPT-6 Sol agent. Bounded
execution: GPT-6 Luna agents. Baseline is the fail-fast scoreboard run in
`runs/thermo5_frozen_regression_hardened_20261006/`. Its 14 directed UVM
results, six MATLAB-payload results, and two URG merges passed. A regression
PASS is the prerequisite for each new stimulus; it is not a coverage waiver.

## Decision rule

For each instance/bin, record one of: `HIT` with a new VDB/URG row and a
passing four-plane oracle, `PROVED_UNREACHABLE` with the exact frozen
parameter, RTL expression and finite/exhaustive proof, or `OPEN` with the
unmet condition. Preserve generic and real-XPM VDBs independently. An
isolated block hit is block evidence and does not close a full-chain SKU bin.

## Priority and assigned work

| Priority | Exact target | Closure evidence | Owner |
| --- | --- | --- | --- |
| 1 | Generic `u_frontend.u_interp_1`, `dsm_interp_x2_polyphase_vector.sv:71`, missing `!s1_valid && !s2_ready` operand 1/0 | Legal AXI bubble/PA stall test; check the state and all 56 four-plane MATLAB words; targeted URG row becomes covered for the same instance. Repeat with real XPM if the stimulus is portable. | Luna interpolation task |
| 2 | `u_cdc.u_s_reset` and `u_cdc.u_c_reset`, `dsm_reset_sync.sv:27`, missing operand 1/0 | Show reset assertion/release ordering, output hold for two local edges, and exact post-test URG rows; if edge sampling excludes the state, provide a scoped proof and retain the URG gap as OPEN. | Luna reset task |
| 3 | Two `core_clk218 -> freerun_clk200` GT TX-active CDC-11 paths | Inspect parent and Wizard chains, ASYNC_REG and destination uses against routed report; provide path-specific supported disposition or explicit OPEN. No waiver or false path. | Luna GT task |
| 4 | Sixteen DPD branch-gap rows at `dpd_memory_poly.v:198`; 32 longer-valid-stream counter toggle rows | Identify the missing branch arm/bit direction from URG source detail, then use legal long-frame stimulus or a parameter/state proof. Record each instance/bit; no aggregate inference. | Next Luna task after priority 1/2 |
| 5 | 162 TID input-range toggle rows | Reuse the independently generated signed-endpoint MATLAB vectors under the current hardened compiled SKU, merge their VDB only with the matching FIFO build, and compare per-instance/bit gap counts. | Next Luna task after priority 1/2 |
| 6 | Parent I/O budgets, RX user-clock/word recovery and serial deskew | Check in-repository board clock, package pin and min/max launch/capture evidence. Without actual parent values or working GT RX, keep system STA/RX/deskew OPEN. | Primary review after GT audit |

## Execution and review gate

- Use new run directories and keep generated vendor/tool content out of Git.
- Keep the frozen `INTERP_TAPS=2`, `DPD_MAX_TAPS=1`, identity coefficients,
  125-MHz AXI and 218.75-MHz core configuration unchanged.
- For UVM changes, require zero UVM errors/fatals, test-specific state hit,
  source/PA monitor counts, and all 56 four-plane golden comparisons.
- Attach the exact before/after URG row and source-state digest to each
  disposition. Update `thermo5-uvm-coverage.md`, `execution-frontier.md`, and
  `UPDATE_LOG.md` after reviewed results, not merely after launching tests.
- Parent clocks/pins/GT serial output remain integration gates independent of
  thermo5 UVM coverage.

## Reviewed dispositions (2026-10-06)

| Target | Evidence and disposition | Remaining gate |
| --- | --- | --- |
| Generic `u_interp_1` line-71 operand `1/0` | Legal bubble/PA-stall UVM test and exact-bin runner added; two compile attempts produced no usable VDB (latest VCS license connection failure). **OPEN**, not a hit. | Restore VCS, run the targeted test, verify all 56 four-plane words and the same-instance URG row; repeat with XPM separately. |
| Source/core reset line-27 operand `1/0` (two instances) | Independent two-clock XSim checks two reset epochs, asynchronous assertion and two-edge local release. Stable reset-low/stage0-high was not observed; simultaneous reset/clock scheduling is a race, not a valid reset state. Both exact URG rows **OPEN** pending reviewed scoped proof/VDB. | Resolve the URG exclusion using accepted formal/tool evidence; retain CDC/RDC as a separate gate. |
| GT TX-active CDC-11 (two routed paths) | Routed-checkpoint review identified the parent two-flop chain and Wizard five-stage destination chain, but both critical rows remain **OPEN**. | Vendor-supported path disposition or verified IP change, then fresh routed CDC/RDC. |
| DPD line-198 saturation branch (16 lane instances) | Missing arm identified from URG HTML. Frozen DPD1 identity algebra plus exhaustive 16-bit XSim proves valid saturation unreachable for every identical lane: **PROVED_UNREACHABLE for this SKU**. Existing URG rows remain red; no waiver added. | Keep proof scope tied to fixed parameters; reopen for programmable/non-identity DPD. |
| DPD `sample_count` toggle (32 rows) | Fresh full-chain XSim matched 1,008 four-plane oracle words, checked all 16 counters at 1,008, and traversed low-bit directions. No new VDB; high-bit and current URG directions remain **OPEN**. | Matching-build VCS/URG long-stream run; record each bit/direction, not an aggregate score. |
| TID input-range toggle (162 bit-15 rows) | Existing signed-endpoint vectors passed 56-word four-plane XSim. Their earlier VDB predates the hardened scoreboard build and must not be merged. All exact rows **OPEN**. | Run the same vectors on the current generic and then XPM compiled images, with separate URG merges. |
| Parent I/O and GT RX | Prospective OOC timing budget and positive direct-route slack do not establish board clocks/pins or RX recovery. **OPEN**. | Obtain source configuration and real I/O min/max budgets; fix RX word recovery before deskew/PA output claims. |

Detailed instance evidence is in the dated reset, GT, DPD, and TID audits under
`docs/verification/`. VCS-dependent targets were not rerun after the license
failure; none is relabeled as a coverage hit.
## 2026-10-06 measured follow-up

The same-build long-stream experiment is complete: generic and XPM each pass
1184 legal input beats, 2072 independent golden output words, and all 16 DPD
counter checks. URG shows a low counter direction (`sample_count[11]`
zero-to-one) in both builds while grouped high counter directions remain
OPEN. The exact interpolation condition remains OPEN after phase probes;
the trace demonstrates that the initial source bubble drains before the
downstream elastic slots become blocked. The next attempt must derive the
stimulus from observed handshake state rather than fixed cycle guesses.
