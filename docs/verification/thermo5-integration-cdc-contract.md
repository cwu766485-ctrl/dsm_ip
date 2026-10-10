# Frozen thermo5 integration clock/reset and CDC contract

## Current CDC-fix and real-XPM evidence (2026-10-05)

The fresh current-source synthesis/route attempt at
`runs/thermo5_parent_cleanroute_20261005_2117/` used a newly generated
`synthesized.dcp`, not the earlier routed checkpoint.  The synthesis wrapper
again ended with a late Vivado feature-license error *after* writing that DCP,
so it is not a clean synthesis PASS.  The independent route from the new DCP
ended normally and its direct end-of-route report gives WNS `+0.264 ns`, WHS
`+0.011 ns`, TNS/THS zero, and zero setup/hold failing endpoints under the
provisional OOC I/O budgets.  This directly positive route improves the prior
direct-route/reopened-checkpoint discrepancy, but `11 ps` hold margin is
fragile and not board/system STA signoff.

The fresh `report_cdc` still has exactly two critical CDC-11 paths.  Neither
has been waived or false-pathed:

| CDC-11 destination | Path-specific evidence | Status |
| --- | --- | --- |
| Parent `tx_active_meta_reg/D` | The Wizard's `tx_active` is generated in the TX-user-clock domain.  `thermo5_qsfp_gt14_parent.sv` receives it through the explicit `ASYNC_REG` two-flop `tx_active_meta/sync` chain in the free-run domain.  The reset-only parent XSim rerun in this same directory passes forced TX-active loss, immediate PA blanking, reset assertion, and recovery. | **OPEN**.  Do not duplicate the source flop in TX user clock: that clock may stop on link loss, which could hide the falling transition. |
| Wizard `bit_synchronizer_gtwiz_reset_userclk_tx_active_inst/i_in_meta_reg/D` | The generated Vivado Wizard source explicitly instantiates its own `bit_synchronizer` into `gtwiz_reset_clk_freerun_in`; its TX reset FSM waits for the synchronized active indication before releasing TX reset. | **OPEN** vendor-IP crossing.  No exception is added; closure requires an AMD-supported reset/CDC disposition or a verified generated-IP configuration change. |

The same fresh directory's reset-only parent XSim passes 64 accepted AXI
beats to 112 output words plus power-good, TX-active, and common-reset
recovery.  It intentionally skips RX word comparison; four-lane RX recovery,
CDC-6/CDC-26 review, actual clock/pin/I/O budgets, and analog/board behavior
remain outside this OOC conclusion.

The full-chain licensed VCS UVM rerun uses the actual Vivado 2024.1 XPM
sources mounted in Rocky WSL and passes seven cases plus URG merge at
`runs/uvm_thermo5_i2_d1_xpm_rerun2_20261005/`. To satisfy VCS's single-
writer rule on declaration-initialized reset synchronizers, only three
`always_ff` keywords in `rtl/axis/dsm_xpm_async_fifo.sv` changed to clocked
`always`; event controls, assignments and reset/data logic did not change.
Fresh focused XPM reset, P0 7/7 and IP smoke XSim pass.

## Reset, I/O-budget and four-lane closure attempt (2026-10-04, historical)

`rtl/axis/dsm_xpm_async_fifo.sv` now synchronizes both local reset requests
into the XPM-required `wr_clk` domain before asserting the common XPM reset.
The focused XSim at `verif/out_xsim_xpm_async_fifo_reset/console_xsim.log`
passes for initial dual reset, read-only and write-only reset requests, stale
data flush, and clean post-reset writes/reads. The first attempted test used
depth 4 and correctly failed XPM configuration DRC (minimum supported depth
is 16); the test was corrected to depth 16 and rerun. This is block-level
reset evidence only; the subsequent real-XPM full-chain UVM rerun is recorded
in the current section above.

At that stage the parent health controller removed `tx_active` from its ordinary
freerun-domain status vector; a falling TX-active signal asserts readiness
reset/PA blanking asynchronously, while recovery is accepted only after the
200-MHz free-run domain observes stable GT status. The generated GT Wizard's
own TX-active synchronizer remains a separate vendor CDC-11 path and is not
waived. The expanded parent testbench compares complete 56-word, 256-bit RX
loopback frames (four ordered 64-bit lanes), with power-good loss, TX-active
loss, reset, blanking and replay. Current XSim recovered TX link at 2.659 us
and delivered 32 AXI beats / 56 TX words, but timed out at 25.0075 us with
`rx_frames=0`. The generated GT Wizard has `RX_SLIDE_MODE=OFF`; RX word
alignment/health is unproven and the four-lane loopback gate remains open.
Do not equate TX link-ready with RX aligned/ready.

The parent XDC now applies provisional external timing assumptions: AXI
inputs 0.20..2.00 ns; AXI ready/full, core status/PA blanking, and free-run
link-ready outputs 0..1.50 ns. The AXI/free-run inputs are defined at 125/200
MHz, respectively; reset remains asynchronous. These are explicit analysis
budgets, not measured board or SoC numbers. Replace them with real
launch/capture min/max delays before system signoff. Routed `check_timing`,
CDC, clock-interaction and setup/hold are pending on this revision.

Vivado synthesis at `runs/thermo5_qsfp_parent_closure_20261004_2216/`
produced `synthesized.dcp`, clocks and utilization (40,399 LUT, 48,311 FF,
496 DSP, 6.5 BRAM tiles, four GTH), but its wrapper exited nonzero with
`Failed to load feature 'vivado'`. A separate checkpoint continuation
obtained the Implementation license and completed `opt_design` plus pre-place
DRC (zero errors/critical warnings). The interactive execution session ended
after about 45 minutes with code `1073807364` during `Physical Synthesis In
Placer`; no Vivado exception appears in its log. A detached route retry from
the same checkpoint is running at
`runs/thermo5_qsfp_parent_route_retry_20261005_0015/`. No post-route
WNS/WHS/CDC/check_timing evidence exists yet. Licensed VCS UVM
recompilation was previously blocked in Rocky WSL by `Cannot find license
file`; new stimulus remains unverified and URG bins stay open.

## Routed parent audit in progress (2026-10-04)

The four-GTH parent at
`runs/thermo5_qsfp_parent_20261004_141521/` completed routing with
WNS +0.198 ns, WHS +0.010 ns, no setup/hold failing endpoints and a
4.571-ns GT user clock. Its `report_cdc` is **not closed**: 273 CDC-1,
two CDC-10 and two CDC-11 critical rows remain. Most user-logic CDC-1
rows originate from the free-run `link_ready_q` driving core-domain TXDATA;
the reset-combination also causes CDC-10. The parent RTL now uses the
core-local reset-ready for the continuous TX boundary and registered
link-ready directly as the asynchronous reset request. New GT parent XSim,
P0 7/7 and IP smoke PASS on this revision. The `162254` route failed to
check out a Vivado feature license during synthesis, so it yielded no STA.
The retry at `runs/thermo5_qsfp_parent_20261004_192407/` reached route and
generated a DCP: formal WNS +0.257 ns, WHS +0.010 ns, TNS/THS zero and no
failing endpoints. The independent read-only DCP audit also completed. The
route wrapper reported a late Vivado license failure at process exit despite
the routed checkpoint and Vivado's normal-exit marker; do not use its exit
code as a clean-run claim.

CDC-1 fell from 273 to eight and CDC-10 to zero. All eight remaining CDC-1
rows go from `u_rst218/sync_q_reg[1]` into the XPM FIFO's source-clock reset
FSM; the two CDC-11 rows concern GT Wizard TX user-clock-active fanout into
the parent health synchronizer and the Wizard reset controller. These remain
critical/open pending an explicit vendor-reset/RDC review, not a blanket
waiver. Methodology reports one TIMING-9 unknown CDC. The setup worst path
is within thermo5 TID state, while the hold worst path is within DPD; both
have positive routed slack.

The routed OOC reports 468 input and 6 output ports without parent I/O
delays; AXI125 and free-run200 also lack `HD.CLK_SRC`. Those open
integration constraints limit the reported STA to the implemented internal
paths. The XPM shared-reset FSM and generated GT reset-controller crossings
need separate path-by-path disposition; a vendor IP boundary is not a
blanket CDC/RDC waiver. No dedicated RDC or board-clock signoff is claimed.

## Continuous four-plane GT TX boundary (2026-10-03)

`fpga/zu15eg/rtl/thermo5_qsfp_gt14_parent.sv` now connects the frozen
2-tap/identity-DPD1/XPM front end to a generated four-channel raw-64 GTH
Wizard under the *assumed* 125-MHz MGT reference. All four planes share the
Wizard TX user clock. The generated Wizard maps consecutive 64-bit slices of
`gtwiz_userdata_tx_in[255:0]` to channels 0..3; the parent maps PA planes
0..3 into those slices in that order. `run_request_axi` is synchronized into
the TX user-clock domain. Loss of TX initialization asserts both source and
core resets; each releases through its own local reset synchronizer.

The GT has no `ready` input and never pauses serialization. The new
`thermo5_raw64_continuous_tx` accepts all four PA words in lockstep, sends
`64'hAAAA_AAAA_AAAA_AAAA` on **every** idle cycle, and requests PA blanking
through `pa_enable=0`. A payload word is allowed only with all four valids,
`run_request`, and TX link-ready. A partial-valid word, a gap inside a
56-word superframe, or payload while stopped sets sticky `stream_fault`.
Gaps between completed superframes are legal. The external PA must remain
disabled until a board-specific blanking path and GT pipeline latency are
measured and compensated; `pa_enable` is a synchronous **request**, not a
proven analog switch or an assertion that 0xAAAA idle is RF-silent.
The AXI producer must prefill the XPM FIFO and raise `run_request_axi` at a
frame-safe boundary; a 56-word frame must then be supplied continuously.
Stopping midway is detected, not losslessly backpressured by the GT. XPM
`wr_rst_busy`/`rd_rst_busy` inhibit FIFO traffic during reset recovery.
Reset/GT startup may also serialize undefined symbols while PA blanking is
required. A common TX user clock establishes word alignment at the GT input,
but the current buffer-mode GT configuration does **not** prove deterministic
inter-channel serial phase alignment at four PA inputs. That requires an
explicit phase-alignment/deskew and measured output-skew contract.

Directed XSim for the continuous boundary passes complete-frame idle,
mid-frame gap, partial-valid and stopped-residual checks. The generated-GT
parent behavioral XSim passes 32 AXI beats to 56 PA words, post-frame idle,
clean stop and common-reset recovery under ideal clocks. This test does not
compare recovered GTH RX words with the MATLAB bit oracle or prove serial
inter-channel phase; parent routed CDC/RDC/STA are separate gates.

## QSFP parent integration gate (2026-10-03)

The board schematic's QSFP1 TX/RX lanes map to GTH bank 128; Vivado package
planning independently verifies all four `GTHE4_CHANNEL_X0Y4..X0Y7`
sites and the `GTHE4_COMMON_X0Y1` reference-clock site on the target
XCZU15EG. The schematic labels that reference-clock output 156.25 MHz.
Vivado GT Wizard accepts four lanes at 14.0625 Gb/s / 156.25 MHz, and at
14.0 Gb/s / 125 MHz, but **rejects** 14.0 Gb/s / 156.25 MHz. Therefore the
digital integration target is the generated 14.0/125 configuration under an
**ideal 125-MHz dedicated GT reference-clock assumption**. This assumption
allows behavioral verification and a prospective FPGA implementation flow;
it does not establish that the board supplies 125 MHz. The physical parent
and board-output claim require a verified clock-generator configuration,
programming sequence, lock/jitter and reset behavior. No parent-level CDC/RDC
or routed STA is claimed from these IP-generation probes.

Changing to 14.0625 Gb/s would also change the raw-64 user clock to
219.7265625 MHz and the 14:8 FIFO long-term throughput balance; this is a
different architecture and needs user approval, new vectors, synthesis and
timing. It is not an implicit substitute for the frozen 14.0-Gb/s target.

Date: 2026-10-03. Target: `tid32_thermo5_axis_frontend_tx_ooc`, XPM FIFO,
2-tap interpolation, one-tap identity DPD. This is an **integration
requirement**, not a claim that the archived OOC checkpoint meets external
I/O or reset timing.

| Boundary | Contract | Verification still required |
| --- | --- | --- |
| `clk125` / AXI source | 125 MHz, 8.000 ns. AXI valid, frame marker, gain and 14-complex payload launch synchronously to this clock and remain stable until ready. | Parent clock source, insertion/jitter, min/max input delays and ready/full output delays. |
| `clk218` / core | 218.75 MHz, 4.571428571 ns. `run_request` is a **core-clock synchronous** level. DPD configuration, if programmable, is core synchronous and changes only at a safe frame boundary. | Parent launch register or explicit synchronizer if the request originates in AXI/CPU clock domain; core input/output delays. |
| Clock relationship | Treat AXI and core clocks as asynchronous; transfer sample/metadata only through the XPM async FIFO. | Review actual generated clocks and all clock-pair paths after parent integration. |
| `rst125_n`, `rst218_n` | Each may assert asynchronously. Release must be synchronized to its own clock. Assert both together for an XPM reset epoch; keep traffic and `run_request` low until both domains have completed reset and XPM busy is clear. | Parent reset tree, assertion overlap, release ordering, recovery/removal, and core-only/source-only reset scenarios. Core-only reset is not an accepted XPM traffic contract. |

`syn/thermo5_integration_contract.tcl` requires explicit numeric min/max I/O
budgets; it adds no reset or `run_request` false path. It must be sourced in
the **parent** design after supplying those eight variables. The archived
OOC script instead applies `set_false_path -from {rst125_n rst218_n
run_request}` and leaves 565 inputs and 264 outputs without delay. Its
internal WNS/WHS (+0.316/+0.027 ns) must not be used as interface STA.
The integration Tcl is not yet applied to a placed parent design.

## Routed-checkpoint CDC path disposition

The reproducible source is `syn/report_thermo5_cdc.tcl` on the archived
`thermo5_i2_d1_a1/routed.dcp`; `tools/hw/thermo5_audit_reports.py` exports
every reported path to `runs/uvm_thermo5_i2_d1/integration_audit_20261003/cdc_paths.csv`.

| Source / destination | Reported rows | Disposition |
| --- | ---: | --- |
| `s_axis_aclk` -> `core_clk` | 2 | XPM write Gray pointer CDC-6 and reset CDC-3, each two stages with `ASYNC_REG`; inspect XPM parameters and reset use, not a user-RTL waiver. |
| `core_clk` -> `s_axis_aclk` | 2 | XPM read Gray pointer CDC-6 and reset CDC-3, same review. |
| `run_request` -> `core_clk` | 7,858 | 7,826 CDC-1 and 32 CDC-13. Raw OOC input has no launch clock and is false-pathed. Resolve with a **core-synchronous parent source and timed path** or add a real CDC synchronizer; do not waive as harmless. |
| `rst218_n` -> `core_clk` | 38,446 | Includes 19,042 CDC-26, 16,633 CDC-1, 2,480 CDC-13, 259 CDC-2 and 32 CDC-7. Reset release and recovery/removal need parent-level RDC/STA; the raw count is not a count of independent faults. No blanket exception. |
| `rst125_n` -> source/core | 119 | Includes 53 CDC-1 and 66 CDC-13. This source reset also drives the shared XPM reset; inspect both destination domains. No waiver. |

The four clock-to-clock rows are the only paths with an identified launch
clock in this OOC report. The 46,423 input-port-clock rows cannot be signed
off by assuming they are all false positives. Next gate: integrate the
contract with actual parent launch/reset logic, rerun routed `report_cdc`,
`report_clock_interaction`, `check_timing`, setup/hold and scoped RDC. No
SpyGlass CDC/RDC run or parent-level STA pass is claimed here.

The parent must expose a register that launches the level-sensitive
`run_request` on `clk218`; a CPU/AXI-domain request requires a separately
verified handshake or synchronizer before that register. A shared raw
reset may assert asynchronously, but `rst125_n` and `rst218_n` must each
deassert through a local reset synchronizer. Their release must be treated
as one FIFO epoch, with AXI traffic and `run_request` held off until both
domains and XPM reset-busy are ready. The current OOC wrapper merely
**assumes** these parent behaviors. Without its real parent clock source,
reset tree, I/O min/max delays, and four actual GT pin/refclk assignments,
the CDC/RDC and serializer/board integration gate cannot be closed.

## 2026-10-04 closure rerun

The XPM FIFO block test asserts read-side-only and write-side-only reset,
checks common-XPM-reset synchronization, stale-data flushing, post-reset
read/write integrity, and immediate handshake blocking while either local
reset crosses the synchronizer window. It passes in Vivado 2024.1 XSim. The
P0 suite passes 7/7 and the IP smoke suite passes.

The four-GTH parent wrapper's final-RTL synthesis is running in
`runs/thermo5_qsfp_parent_closure_20261004_2216/`. The 256-bit recovered RX
word bus receives a provisional min/max output budget from the route Tcl,
after synthesis exposes the actual GT Wizard RX user clock. Earlier synth
attempts were stopped before reports and are not STA evidence. The updated parent testbench
is intended to compare 56 recovered words across all four 64-bit planes on
normal, lock-loss recovery and post-interruption replay, plus continuous idle
and PA blanking. No parent-loopback result is claimed until it runs. Wizard
CDC-11 and XPM reset CDC-1 findings remain open pending fresh routed reports
and path-specific review.

The assumed AXI, status and recovered RX-word min/max delays are provisional
budget placeholders; replace them with actual parent timing before signoff.
QSFP serial pins terminate at hard GT primitives and are
covered by transceiver constraints, while serial phase/deskew and analog PA
blanking remain physical contract/measurement items outside digital OOC STA.

The 2026-10-03 XSim PRBS/known-word BERT and frozen 2-tap/DPD1 four-plane
ideal serializer loopback are useful digital behavioral checks, not a
parent-level clock/reset or physical 14-Gb/s GTH signoff.

## 2026-10-05 routed parent review

The routed checkpoint `runs/thermo5_qsfp_parent_route_retry_20261005_0015/`
meets the currently applied *provisional* constraints: 218.75-MHz core WNS
+0.278 ns, WHS +0.010 ns, TNS/THS 0, and no setup/hold failing endpoints.
`check_timing.rpt` reports zero no-clock, unconstrained internal endpoints,
or outputs without delay; its only no-input-delay port is the intentionally
asynchronous `reset_n`. The design still lacks actual parent clock-source
placement, package pin placement for the AXI bus, and measured launch/capture
budgets. The assumed delays therefore establish only a constrained OOC
implementation result, not board/system I/O signoff.

The routed `report_cdc` no longer lists the prior eight XPM reset CDC-1 or two
parent CDC-11 rows. This is not closure: it reports four CDC-10 critical rows
from the Wizard `gtwiz_userclk_tx_active` synchronizer output to
`health_meta_reg[4:7]/CLR`, plus one CDC-7 critical row to
`link_ready_q_reg/CLR`. Four CDC-15 warnings on `health_stable_count`, four
CDC-26 LUTRAM read/write warnings, and two XPM CDC-6 gray-pointer warnings
also remain. The new critical reset paths must be inspected and fixed or
given a path-specific, evidence-backed disposition; no automatic waiver.

The focused XPM dual-reset test passes initial, read-only, and write-only
reset epochs with stale-data flush and post-reset integrity. The parent GT
reset-only XSim passes 64 accepted AXI beats / 112 output words, with
power-good, TX-active, and common-reset recovery. Full RX comparison is still
open: the external serial-pin loopback times out with `rx_frames=0`; a
separate Wizard near-end PMA-loopback experiment synthesizes, but its RX
comparison also times out (`rx_done=1`, `rx_cdr=1`, `rx_clk=0`, no frame,
`rxdata=55...`). Its reset-only diagnostic passes. Neither result proves
four-lane RX recovery or external serial phase/deskew.

## CDC RTL follow-up candidate (2026-10-05)

Inspection traced the routed CDC-10 rows and the CDC-7 row to the parent
`always_ff` block using asynchronous `negedge tx_active[0]` alongside global
reset. The candidate RTL removes TX-active from the asynchronous reset event,
adds a two-stage TX-active level synchronizer in the free-running 200-MHz
domain, and uses that synchronized level for link qualification/reset. Raw
TX-active remains in the PA blanking combinational gate for fast fault
response. A local reset synchronizer now qualifies reset release into the
free-running health controller. This is an implementation hypothesis, not a
closure claim: Vivado could not be relaunched after the edit (launcher exit 1
with empty output), so no new simulation, synthesis, or routed CDC report
exists. The previous CDC-7/10 findings remain the latest measured report.
