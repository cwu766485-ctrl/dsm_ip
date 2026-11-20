# DSM thermo5 DE final closure — 2026-11-20

**Release verdict: BLOCKED. No DE RC, tag, or merge was created.**

Branch `work/thermo5-vcu118-architecture-research`, HEAD
`30ba6cb5ef53d0a9bed4889e1b0efdb881bdecef`. The worktree was already dirty at
entry and remains uncommitted. This round changed no product RTL or Golden. It
added the 16-frame runner fix, run manifests, closure documentation, and a
fresh EF1 candidate4 and selected MASH A candidate4 v11 OOC routes with exact
XPM reset stage-zero constraints.
All previous DCP, VCD, logs, reports, failed runs, and unstaged work remain in
place. New runs use `fix01` through `fix04`,
`live_long_16frame_blocked_repro_01`, the earlier EF1 audit at
`runs/de_final_closure_20261120/ef1_candidate4_ooc_new01/`, and the new route at
`runs/de_final_closure_20261120/ef1_candidate4_ooc_v11/`; no existing
experiment output was overwritten.

Vivado/XSim: 2026.1, SW Build 6511674. Vivado part: `xcvu9p-flga2104-2L-e`.
The VCU118 GT Wizard behavioral simulation used dual RAW 14.000 Gb/s GTY
channels with 125 MHz reference and 64-bit user data at 218.75 MHz.

## 1. Blocker Closure Matrix

| Gate | Status | Result / blocker | Next action |
|---|---|---|---|
| Original 16-frame XSim BLOCKED reproduction | PASS | In a fresh isolation directory, the generated `compile.bat` fails with exit 1 because the child PATH cannot resolve `xvlog`; no DUT simulation runs. The original nine-attempt manifest remains unchanged. | Use the corrected launcher and a fresh run directory. |
| 16-frame continuous AXIS-to-MASH-to-GTY digital loopback | PASS | 84,224 PA words/lane, 5,390,336 bits/lane; TX/RX serial bit-true, lane skew 0, `sent=emitted`, no underflow, overflow, or protocol fault. | Keep this as bounded simulation evidence; extend with same-harness backpressure/reset/epoch tests. |
| 16-frame receiver metrics | PASS | First frame only, fixed source offset 528 and no lag search: EVM RMS 2.551442%, SNDR 31.864285 dB, BER 15/37,376. | Measure all frames separately if the acceptance contract requires it. |
| Reset-during-traffic regression | PASS | Existing one-frame active-traffic common-reset/restart digital test passes with TX/RX bit-true and zero lane skew; it is a separate harness and run. | Integrate reset/epoch stress into the 16-frame elastic-buffer harness. |
| STOP/Restart regression | PASS | Existing two-frame STOP/drain/restart digital test passes TX/RX bit-true and zero lane skew; it is a separate harness and run. | Add repeated restart and randomized boundary/backpressure cases to the product harness. |
| Integrated EF1/MASH mode commit and isolation | NOT_RUN | No dual-architecture EF1+MASH candidate Top or same-chain mode-switch regression was built. | Define/use the approved product Top, then verify stopped-only commit, PA contract isolation, and no stale apply. |
| Mailbox block Formal | PASS | Scoped candidate3 v7: 25/25 assertions, 28/28 non-vacuity checks, 11/11 covers. | Retain as a block-level proof only. |
| EF1 current-source routed timing | PASS (scoped OOC route only) | Fresh candidate4 v11 routed DCP: report WNS/TNS +0.171/0 ns, WHS/THS +0.027/0 ns; router estimate +0.159/0 and +0.026/0. Exact two generated XPM reset stage-zero D pins are checked for `ASYNC_REG` before exception. | Resolve the remaining `report_clock_interaction` unsafe asynchronous rows and supply actual VCU118 parent clock/IO/reset constraints before product signoff. |
| EF1 product Full-Top timing | NOT_RUN | EF1 OOC route is not an integrated VCU118 top; parent XDC and board pin/clock budget are absent. | Supply approved board-level integration constraints, then route the actual product top. |
| MASH A routed timing | PASS (scoped OOC only) | New v11 routed DCP: WNS/TNS +0.037/0 ns, WHS/THS +0.025/0; router estimate +0.019/0 and +0.025/0. | Close unsafe asynchronous clock interactions and add approved VCU118 parent clock/IO/reset constraints before product signoff. |
| MASH B current-source routed timing | NOT_RUN | Candidate4 run is still marked `PREPARED_NOT_LAUNCHED`; legacy Tcl v3 OOC route failed. | Keep paused per scope; no need to explore a new candidate. |
| Vivado CDC / SpyGlass RDC | BLOCKED | 3 reset-critical findings, 101 CDC-15 mailbox warnings, and 17,895 RDC errors in 86 structural signatures remain without final disposition. | Audit reset integration and all signatures; fix real defects or document exact proof-backed tool disposition. |
| Full EF1+MASH Top Formal | NOT_RUN | No top-level proof harness/report covers combined reset epoch, atomic configuration commit, mode isolation, stale-apply exclusion, FIFO reset/busy, and serializer behavior. | Build and run the top proof after the exact integration contract and parent reset model are fixed. |
| EF1+MASH full-top routed PPA | NOT_RUN | No combined top DCP or parent-level VCU118 XDC/budget. Singleton/OOC data cannot substitute. | Route the integrated top after singleton and CDC gates close. |
| Board RF EVM / ACLR | NOT_RUN | No VCU118 RF capture or measurement. | Measure on board with the RF path and calibrated instrumentation. |
| DE Freeze | BLOCKED | Required formal, CDC/RDC, EF1, combined-top timing, and same-harness reset/backpressure gates are open. | Do not create an RC until each gate is closed. |

## 2. CDC/RDC Disposition

The fresh EF1 v11 and MASH A v11 routed Vivado CDC reports each retain three
unsafe Critical reset-related CDC endpoints: one Core→AXI-Lite and two
Core→AXIS. The detailed candidate4 mailbox CDC-15 report has 101 warnings
(99 DPD configuration bits and 2 architecture bits). The
critical findings are one CDC-10 reset path from
`core_abort_sync/sync_q_reg[1]/C` to
`u_product/u_cfg/cfg_epoch_source_sync/sync_q_reg[0]/CLR`, plus two CDC-11
paths from the same source into the XPM FIFO reset boundary
(`rd_reset_in_wr_reg[0]/CLR` and `rd_reset_sync_reg[0]/D`). The 101 CDC-15
warnings are held bundled-data mailbox paths: 99 DPD configuration bits and 2
architecture bits. Mailbox Formal and OOC max-delay/bus-skew constraints
support the digital bundled-data protocol, but do not close reset release,
physical skew, parent reset pulse width, or product-top CDC/RDC signoff.

The EF1 post-route STA audit checked exactly seven asynchronous first-stage
cells with `ASYNC_REG=TRUE/1`: two XPM FIFO reset synchronizer stages and the
`run_s1`, `arch_lock_s1`, `ingress_closed_c1`, `source_error_c1`, and
`arch_locked_c1` control synchronizers. Exact stage-zero STA exclusions
remove the unsafe asynchronous setup relationship from the in-memory timing
view, while held mailbox and Gray-pointer buses remain bounded with
datapath-only max delay and bus skew. This resolves the STA classification
for that routed OOC DCP, not the three Vivado CDC findings or the reset-output
functional contract. No blanket clock-group exception was used.

SpyGlass candidate4 reports 17,895 unwaived `Ar_resetcross01` Errors with the
tool reason `Qualifier not found`, plus 12 informational synchronized
crossings. The native rows reconcile into 86 structural signatures. Existing
textual hierarchy buckets are:

| Hierarchy bucket | Messages | Signatures | Disposition |
|---|---:|---:|---|
| MASH state and enable cones | 5,754 | 16 | OPEN_REVIEW |
| Interpolator 2 and FIFO payload | 5,105 | 10 | OPEN_REVIEW |
| DPD history and pipeline | 3,700 | 12 | OPEN_REVIEW |
| Interpolator 1 elastic payload | 2,864 | 11 | OPEN_REVIEW |
| Other frontend/control | 191 | 15 | OPEN_REVIEW |
| Generic asynchronous FIFO | 179 | 9 | OPEN_REVIEW |
| Configuration and reset epoch | 114 | 13 | OPEN_REVIEW |

The seven buckets reconcile all 17,907 native report rows (17,895 Errors and
12 Info) and 86 signatures (80 Error signatures and 6 Info signatures), as
recorded in
`runs/de_resetfix_spyglass_candidate4_04/rdc_triage_02/summary.json` and
`structural_signatures.csv`. Every signature remains `OPEN_REVIEW`; this is
textual classification, not a proof that a qualifier is logically unnecessary
or that the crossing is safe. No waiver was applied.

The shared analyzer reason is `Qualifier not found`; the run scope declares
candidate reset names and three clocks, but the report alone does not tell
whether each missing qualifier reflects a real reset-use defect, a valid/enable
cone the analyzer did not resolve, or an RTL/SGDC hierarchy mapping issue.
The largest groups include centered Interpolator-2 to FIFO payload (4,922),
Interpolator-1 elastic payload (2,416), and candidate MASH stage state (2,113
each for two reset relationships). These remain OPEN pending a per-group
trace from reset source through valid/enable to the consuming register. The
candidate4 SpyGlass CDC run has 0 CDC Errors and 0 unsynchronized crossings
in its stated Generic-FIFO candidate scope; it does not clear Vivado's 3
Critical reset findings or the RDC run.

The older 45,778/239 Runtime report and 10,539 frontend-only report have
different top/source/reset configuration and rule setup; counts are not a
before/after metric. No broad waiver or source-level suppression is approved.
The three reset-critical findings need the parent reset controller, local
release synchronizers, PA mute/isolation, and reset pulse contract reviewed
together. The 86 groups need per-group valid/enable/reset-cone review before a
safe disposition can be signed.

## 3. Full-Top Formal Report

**Full EF1+MASH Top Formal: NOT_RUN.** The existing 25/25 proof is candidate3
mailbox-block scope only. VC Formal V-2023.12-SP2 used fixed digital clocks
(AXI-Lite 35 ns, phase `{0,17}`; Core 16 ns, phase `{5,13}`), formal POR, and
AXI AW/W/AR stability while stalled. It did not add assumptions or weaken
properties. All 28 non-vacuity goals and 11 covers passed.

That result does not establish top-level reset-epoch behavior across the
AXIS/AXI-Lite/Core/GTY domains, Runtime mode isolation, FIFO reset/busy
protocol, PA contract, or serializer continuity. The exact top-level combined
environment and assertions are absent, so no top proof was inferred from the
mailbox result. Preserve the earlier v6 two-unconverged proof and its logs as
diagnostic history; v7 supersedes it only for the scoped mailbox block.

## 4. EF1/MASH Routed Timing and PPA

The repository has no VCU118 parent timing XDC with clock source, board pin
locations, reset input budgets, and interface input/output delays. EF1/MASH
OOC studies use core 218.75 MHz, AXIS 125 MHz, AXI-Lite 100 MHz, provisional
0.2 ns I/O budgets, and `HD.CLK_SRC` unset. This cannot represent the
device-level or board-level launch/capture relationship.

| Configuration / evidence | Status | Setup WNS / TNS (ns) | Hold WHS / THS (ns) | LUT / FF / DSP / BRAM / CARRY8 | Power estimate | Scope |
|---|---|---:|---:|---|---:|---|
| EF1, legacy Tcl v3 routed DCP | FAIL | −0.435 / −31.817 | +0.006 / 0 | 47,227 / 49,874 / 496 / 6.5 / 4,239 | 3.589 W | Historical OOC; mailbox/reset exceptions were incomplete. DCP SHA `1ffc21214ceaa14392fd2dd5b1a2fb4bf69c540357007730390e9a781b4797c0`. |
| MASH A, legacy Tcl v3 routed DCP | FAIL | −0.377 / −30.773 | +0.004 / 0 | 35,880 / 47,745 / 496 / 6.5 / 2,981 | 3.449 W | Historical OOC; not the current candidate signoff. |
| MASH A, candidate4 v9 routed DCP + exact in-memory audit | PASS | +0.240 / 0 | +0.032 / 0 | 35,851 / 47,733 / 496 / 6.5 / 2,981 | 3.420 W | Historical scoped OOC read-only audit; no reroute. Routed DCP SHA `0645758fc5a89ea58683acd3d45188bfa4209faeac2ef906584e2ddd5f291e29`. |
| MASH B, legacy Tcl v3 routed DCP | FAIL | −0.435 / −28.402 | +0.006 / 0 | 35,860 / 47,759 / 496 / 6.5 / 2,981 | 3.445 W | Historical OOC; current MASH B candidate was not routed. |
| EF1 candidate4 / v9 fresh routed DCP, raw report | FAIL | −0.244 / −0.244 | +0.009 / 0 | 47,064 / 50,040 / 496 / 6.5 / 4,239 | 3.558 W | Raw OOC report has one asynchronous XPM `syncstages_ff_reg[0]/D` endpoint; routed DCP SHA `49c85415d4e7d16a033fc51d9067ce5f7edf8c3b1c989aa7232297c946db9a3d`. |
| EF1 same v9 routed DCP, exact stage-zero post-route audit | PASS | +0.254 / 0 | +0.027 / 0 | 47,064 / 50,040 / 496 / 6.5 / 4,239 | 3.558 W | Scoped OOC read-only reanalysis; not rerouted after exception correction. Superseded by v11 for route evidence. |
| EF1 candidate4 v11 corrected-exception routed DCP | PASS (scoped OOC only) | +0.171 / 0 | +0.027 / 0 | 47,061 / 49,829 / 496 / 6.5 / 4,239 | 3.532 W | Fresh synthesized, placed and routed DCP SHA `08e392ab75f23b17afcc4e68065916cf01a3be5c2747ca879c5f9ea8cbcb5a50`; 0 unconstrained internal endpoints, 3 reset inputs lack input delay. OOC `HD.CLK_SRC` and interface `HD.PARTPIN_LOCS` are absent. Clock interaction still reports asynchronous unsafe pairs; not product signoff. |
| MASH A candidate4 v11 corrected-exception routed DCP | PASS (scoped OOC only) | +0.037 / 0 | +0.025 / 0 | 35,883 / 47,731 / 496 / 6.5 / 2,981 | 3.426 W | Fresh DCP SHA `784ffc0b10eb75992585e9b9161e99496867432d1250fa75372846c0631cd060`; router estimate WNS +0.019 ns, 0 unconstrained internal endpoints, 3 reset inputs lack delay, unsafe clock interaction remains. |
| EF1-only product Full Top | NOT_RUN | — | — | — | — | Parent XDC and integrated board top absent. |
| EF1 + MASH A product Top | NOT_RUN | — | — | — | — | No integrated DCP or complete top constraints. |

The older EF1 raw v9 failing path was the Core-domain XPM FIFO reset request register
`fifo_rd_rst_ic_reg_replica/C` to the AXIS-domain first reset synchronizer
`rrst_wr_inst/syncstages_ff_reg[0]/D`. The clocks have no common primary
clock; the apparent 0.003 ns requirement produced a −0.244 ns slack on 0.228
ns data delay (0.079 ns cell, 0.149 ns route), with −0.009 ns skew. AMD XPM
source marks the synchronizer stage as `ASYNC_REG`. The read-only exact audit
then reports a real Core setup path from
`g_interp2_centered.u_interp_2/q0_i_reg[13][2]/C` to
`u_interp2_to_tid_fifo/data_i_mem_reg[0][409]/D`: 4.298 ns data delay
(1.696 ns cell, 2.602 ns route), 15 logic levels, −0.009 ns skew, +0.254 ns
slack. The worst hold path has +0.027 ns slack. Audit `check_timing` reports
zero unconstrained internal endpoints and three external reset inputs without
input delays. The v9 read-only audit's clock interaction showed no remaining
unsafe inter-clock STA row; the later corrected v11 routed reports still
identify three unsafe reset CDC endpoints. Both v11 `report_cdc` summaries
show one unsafe Core→AXI-Lite endpoint and two unsafe Core→AXIS endpoints.
The associated reset/epoch paths and PA isolation contract remain open for
system-level review.

The fresh v11 route applies the two generated XPM reset synchronizer
`syncstages_ff_reg[0]/D` exceptions before implementation and verifies
`ASYNC_REG=1` on both cells. Router completion reports zero unrouted nets and
zero node overlaps. Final `report_timing_summary` gives WNS/TNS
`+0.171/0 ns` and WHS/THS `+0.027/0 ns`; router-estimated timing is
`+0.159/0 ns` and `+0.026/0 ns`. The worst setup path is inside the Core DPD
DSP/CARRY chain from
`g_memory_dpd...g_lane[1].u_dpd/r4_full_s2[0]__1/DSP_A_B_DATA_INST/CLK` to
`...g_lane[1].u_dpd/p_49_out__0/DSP_A_B_DATA_INST/B[15]`: data delay 4.099 ns
(2.663 ns cell, 1.436 ns route), 11 logic levels, clock skew −0.017 ns. The
worst hold path has +0.027 ns slack. `check_timing` reports zero unconstrained
internal endpoints and three reset inputs with no input delay. The clock
interaction report still marks AXI-Lite→AXIS as `Timed (unsafe)` and
AXIS→Core as `Partial False Path (unsafe)`; these asynchronous crossings need
protocol-level review and exact CDC disposition. In addition, this OOC run
has no parent `HD.CLK_SRC` or interface `HD.PARTPIN_LOCS`, so its positive STA
is not a board timing signoff.

The first corrected-constraint EF1 reroute evidence is under
`runs/de_final_closure_20261120/ef1_candidate4_ooc_v11/`; its routed DCP SHA is
`08e392ab75f23b17afcc4e68065916cf01a3be5c2747ca879c5f9ea8cbcb5a50`, its run
Tcl SHA is `02a59cfdc8afad4c8314cc340eb62461dbef839a478a9637365ef5a1166cf112`,
and `run_manifest.json` records 29 RTL source hashes, exact constraints,
metrics and tool version. Routed timing, Worst-20, exceptions, clock
interaction, bus-skew, CDC, utilization, power, DCP, log and journal are
preserved in its `implementation/` directory.

The selected MASH A v11 OOC evidence is under
`runs/de_final_closure_20261120/mash_a_candidate4_ooc_v11/`; routed DCP SHA
`784ffc0b10eb75992585e9b9161e99496867432d1250fa75372846c0631cd060`, Tcl SHA
`02a59cfdc8afad4c8314cc340eb62461dbef839a478a9637365ef5a1166cf112`, with
29 RTL source hashes in its manifest. Final WNS/TNS is `+0.037/0 ns`,
WHS/THS `+0.025/0 ns`; router estimate is `+0.019/0 ns`, `+0.025/0 ns`.
Its worst setup path runs from centered Interpolator-1
`q0_i_reg[5][6]/C` to the Interpolator-to-DPD elastic FIFO
`data_i_mem_reg[1][185]/D`: data delay 4.513 ns (1.768 ns logic, 2.745 ns
route), 14 logic levels, and −0.010 ns skew. Resources are 35,883 LUT,
47,731 FF, 496 DSP, 6.5 BRAM tiles and 2,981 CARRY8; vectorless power is
3.426 W. `check_timing` has zero unconstrained internal endpoints and three
reset inputs with no input delay. The clock interaction still lists AXI-Lite→
AXIS as `Timed (unsafe)` and AXIS→Core as `Partial False Path (unsafe)`.
Therefore this is a scoped OOC timing result, not product signoff.

Earlier fresh EF1 evidence is under
`runs/de_final_closure_20261120/ef1_candidate4_ooc_new01/`: routed DCP SHA
`49c85415d4e7d16a033fc51d9067ce5f7edf8c3b1c989aa7232297c946db9a3d`, source
hash list SHA `17a8580deb53d3ba7adfbcd9917c8acf648c85eea6cbc943350190dd2a9e2a10`,
and run manifest `run_manifest.json`. Vivado is 2026.1 Build 6511674. The
post-route audit report set is in `post_route_cdc_stage0_audit_v2/`; it
re-analyzes the existing routed DCP without modifying it.

MASH A audit's post-exception worst path is a real Core path through the DPD
DSP/CARRY cone: `u_product/u_frontend/g_memory_dpd...g_lane[11]...r4_full_s2[0]`
to `...p_49_out__0/DSP_A_B_DATA_INST/B[11]`. It has 4.014 ns data delay
(2.605 ns logic, 1.409 ns routed net), 12 logic levels, and −0.017 ns clock
skew; slack is +0.240 ns against 4.571 ns. Hold worst slack is +0.032 ns.
The read-only exception audit excludes only the verified XPM reset
synchronizer stage-zero D pins in memory; the DCP itself is unchanged. Mailbox
bundles retain explicit max-delay and bus-skew bounds. No entire clock group
was cut. The exception report, clock interaction, check-timing, CDC, and
Worst-20 reports are preserved alongside the DCP under
`runs/de_resetfix_ppa_08/candidate4/mash_a/implementation/audit_stage0_01/`.

All power numbers are vectorless default-activity estimates and are not board
power measurements. The PPA machine-readable table is
`de_ppa_matrix_20261120.csv`.

## 5. 16-Frame / Reset / STOP Functional Regression

The original blocked attempt history remains at
`runs/live_long_16frame_02/manifest.json` (nine launcher/compile attempts, all
before DUT simulation). A fresh isolated reproducer in
`runs/live_long_16frame_blocked_repro_01/` returns exit 1 with `xvlog` not
recognized, confirming the launcher root cause. The working child PATH order
is `Vivado/bin` first, then `Vivado/bin/unwrapped/win64.o`, so vendor launcher
scripts initialize the simulator loader correctly.

The fixed 16-frame run at `runs/live_long_16frame_fix04/` passes using the new
launcher helper. In this same fresh project, Vivado scripts-only, Compile,
Elaborate, runner, and PASS-marker checks all exit 0. Snapshot
`tb_vcu118_live_long_continuous_cdc_v4_behav` was built. Compile has one
non-fatal testbench warning (`in_ready` used before declaration, line 52). The
full no-wave run emits:

```text
LIVE_DRAIN_DIAGNOSTIC drain=1 backend_underflow=0 serializer_underflow=0 protocol=0 sent=84224 emitted=84224
LIVE_AXIS_PA_PREFILL_PASS words=84224 frames=16 stop_after_final_frame=1
GTY_TX_SERIAL_BITTRUE_PASS lanes=2 words=84224 bits_per_lane=5390336 starts=22866,22866 skew_ui=0 line_rate=14.000Gbps
GTY_RX_LOOPBACK_BITTRUE_PASS lanes=2 words=84224 bits_per_lane=5390336 starts=23713,23713 skew_bits=0
```

The serial output for both lanes matches the independent continuous Golden
for all 84,224 words; first mismatch is `null` for both lanes. Receiver
metrics use the first frame and fixed source offset 528 with no lag search:
EVM RMS 2.551442%, SNDR 31.864285 dB, uncoded BER 15/37,376. Digital receiver
metrics are not RF/ACLR measurement.

Separate preserved tests cover common reset during active traffic followed by
restart (`runs/live_reset_restart_launcher_01/console.log`) and two-frame
STOP/drain/restart (`runs/live_stop_restart_launcher_01/console.log`). Both
are bounded passes with TX/RX serial bit-true and zero lane skew. They use a
different prefill harness from the 16-frame elastic-buffer test. Thus 16-frame
continuous supply, reset-during-traffic, and STOP/Restart have each passed in
their respective bounded tests, but the combined randomized stress case is
still open. The 16-frame harness uses constant epoch 0, no random backpressure,
and STOP only after its last frame.

Run manifest, source and generated-model SHA-256, both serial capture hashes,
Golden hashes, receiver JSON, and logs are recorded in
`runs/live_long_16frame_fix04/manifest.json` and `source_sha256.txt`. The earlier
`fix01` pass is retained independently. Board RF EVM and ACLR remain
**NOT_MEASURED**.

## 6. RC Readiness Verdict and Reproduction Commands

**RC readiness: BLOCKED.** The 16-frame startup blocker is closed, and the
fresh EF1 and selected MASH A v11 OOC routes have positive scoped post-route
STA. DE Freeze remains
blocked by undisposed Vivado CDC and SpyGlass RDC, missing full-top Formal,
missing VCU118 parent constraints, no integrated EF1+MASH routed Top, and
reset/backpressure/epoch behaviors split across bounded test harnesses. Do
not create a release commit or tag.

From Windows, in the research worktree:

```bat
rem Reproduce the original BLOCKED launcher diagnosis; expected process exit 1.
cmd.exe /d /s /c "E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\live_long_16frame_blocked_repro_01\reproduce_blocked.cmd"

rem Generate a new project in a fresh directory; the Tcl refuses an existing output.
set XILINX_VIVADO=D:\AMDDesignTools\2026.1\Vivado
call %XILINX_VIVADO%\bin\vivado.bat -mode batch -source E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\research\vcu118_arch\sim_live_long_16frame_scripts_only.tcl -tclargs E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\live_long_16frame_NEW\project

rem The helper compiles, elaborates, runs no-wave XSim, checks the PASS markers,
rem writes per-stage return codes, and refuses any existing outputs.
call E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\research\vcu118_arch\run_live_long_16frame_xsim.cmd E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\live_long_16frame_NEW\project\project\gty_sim.sim\sim_1\behav\xsim
```

The runner puts `Vivado/bin` before `unwrapped/win64.o`, preserves each stage
exit code, runs without waveform capture, and checks the 16-frame, TX, and RX
PASS markers. Original generated source vectors and all old failed evidence
remain intact.

Existing reset and STOP regressions (each is a separate bounded test):

```bat
call D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\research\vcu118_arch\sim_live_reset_restart.tcl -tclargs E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\live_reset_restart_NEW
call D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\research\vcu118_arch\sim_live_stop_restart.tcl -tclargs E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\live_stop_restart_NEW
```

The `*_NEW` destinations must be absent before launch; the existing passing
run directories are read-only evidence.

Reproduce the scoped Mailbox Formal v7 in a fresh output directory, from WSL
Rocky-8.10. The original v7 output is preserved; do not rerun into it:

```bash
wsl.exe -d Rocky-8.10 -- bash -lc 'export VC_FORMAL_HOME=/opt/Synopsys/vc_formal/V-2023.12-SP2 VC_STATIC_HOME=/opt/Synopsys/vc_formal/V-2023.12-SP2 : "${LM_LICENSE_FILE:?Configure the licensed Synopsys server in the environment}" "${SNPSLMD_LICENSE_FILE:?Configure the licensed Synopsys server in the environment}"; root=/mnt/e/workspace/chip/dsm_ip/runs/thermo5_vcu118_arch_research; out=$root/runs/de_candidate3_independent_reset_formal_REPRO; test ! -e "$out" || exit 2; mkdir "$out"; export MAILBOX_FORMAL_ROOT=$root MAILBOX_FORMAL_OUT=$out; cd "$out"; "$VC_FORMAL_HOME/bin/vcf" -batch -fmode FPV -f "$root/research/vcu118_arch/formal_cfg_mailbox_candidate3_independent_v7.tcl" 2>&1 | tee console.log'
```

Repeat the EF1 OOC route and exact post-route audit only in fresh output
directories. This reproduces the scoped evidence; it does not supply the
missing VCU118 parent constraints:

```bat
set XILINX_VIVADO=D:\AMDDesignTools\2026.1\Vivado
call %XILINX_VIVADO%\bin\vivado.bat -mode batch -source E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\research\vcu118_arch\run_ppa_abort_candidate_resetfix_xpm_v11.tcl -tclargs ef1 E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\de_final_closure_20261120\ef1_candidate4_ooc_REPRO\implementation b
rem For the selected MASH A OOC run, use tclargs: mash <fresh-output-dir> a.
call %XILINX_VIVADO%\bin\vivado.bat -mode batch -source E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\research\vcu118_arch\run_ppa_abort_candidate_resetfix_xpm_v11.tcl -tclargs mash E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\de_final_closure_20261120\mash_a_candidate4_ooc_REPRO\implementation a
call %XILINX_VIVADO%\bin\vivado.bat -mode batch -log E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\de_final_closure_20261120\ef1_candidate4_ooc_REPRO\implementation\post_route_audit.vivado.log -journal E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\de_final_closure_20261120\ef1_candidate4_ooc_REPRO\implementation\post_route_audit.vivado.jou -source E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\research\vcu118_arch\audit_ef1_routed_cdc_stage0_v2.tcl -tclargs E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\de_final_closure_20261120\ef1_candidate4_ooc_REPRO\implementation\routed.dcp E:\workspace\chip\dsm_ip\runs\thermo5_vcu118_arch_research\runs\de_final_closure_20261120\ef1_candidate4_ooc_REPRO\post_route_cdc_stage0_audit
```

Rebuild the 86-signature RDC classification into an absent, fresh directory:

```bash
python3 research/vcu118_arch/cluster_candidate4_rdc_csv.py \
  --input runs/de_resetfix_spyglass_candidate4_04/rdc/abort_candidate4/thermo5_ppa_top_v4/rdc/rdc_verify_struct/spyglass_reports/clock-reset/Ar_resetcross01.csv \
  --out runs/de_final_closure_20261120/rdc_triage
```

The candidate MASH A OOC PPA launch script and Tcl are preserved under
`runs/de_resetfix_ppa_08/candidate4/mash_a/run.cmd` and
`research/vcu118_arch/run_ppa_abort_candidate_resetfix_xpm_v9.tcl`. Do not
reuse the old output directory; use a fresh directory and the real VCU118
parent clock/IO/reset constraints before any product timing claim. Existing
Formal, CDC/RDC, and historical OOC PPA reports remain the evidence sources;
no Full-Top PASS is claimed.
