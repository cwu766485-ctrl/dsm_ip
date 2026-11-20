# DE timing root cause — 2026-11-18

## Scope and current status

**Status: see the latest v9 routed-DCP audit below.** Earlier sections preserve the chronology and interpretation of the legacy runs; they are not the latest status. Even the corrected v9 result is limited to an OOC research top and is not product/board timing signoff.

Run context: branch `work/thermo5-vcu118-architecture-research`, HEAD `30ba6cb5ef53d0a9bed4889e1b0efdb881bdecef`; Vivado 2026.1 build 6511674; device `xcvu9p-flga2104-2L-e`; clocks are Core 218.75 MHz, AXIS 125 MHz, AXI-Lite 100 MHz. The OOC top independently defines these three clocks and has no physical `HD.CLK_SRC`, so clock insertion delay/skew and parent timing remain outside this result.

## Latest MASH A candidate4 v9 routed checkpoint audit — 2026-11-19

**Status: PASS for routed OOC timing after a justified, exact reset-synchronizer endpoint exception; NOT product DE signoff.** The physical route completed with Vivado 2026.1 build 6511674 for `xcvu9p-flga2104-2L-e`, Core 218.75 MHz, AXIS 125 MHz, AXI-Lite 100 MHz, XPM asynchronous FIFO, candidate4 source set. The routed DCP is `runs/de_resetfix_ppa_08/candidate4/mash_a/implementation/routed.dcp`, SHA-256 `0645758fc5a89ea58683acd3d45188bfa4209faeac2ef906584e2ddd5f291e29`.

The original routed timing report, before the added exact endpoint exception, showed WNS/TNS `−0.258/−0.258 ns`, one setup endpoint, and WHS/THS `+0.012/0 ns`. The sole failing path launched from XPM `fifo_rd_rst_ic_reg/C` on `core_clk` and ended at `rrst_wr_inst/syncstages_ff_reg[0]/D` on `s_axis_aclk`; edge requirement was 0.003 ns, data delay 0.242 ns (0.076 cell + 0.166 route), skew `−0.009 ns`, uncertainty 0.035 ns. This is the asynchronous reset request entering stage zero of the XPM reset synchronizer. The routed-DCP audit checked `ASYNC_REG=TRUE` on exactly two XPM remote-reset stage-zero cells, then applied an in-memory false path only to their two D pins. It did not modify or save the DCP; all synchronizer stage-one+ paths, functional datapaths, and the existing bundled-data max-delay/bus-skew paths remained constrained.

With that scoped exception, the same routed netlist reports global and Core WNS `+0.240 ns`, TNS `0`, WHS `+0.032 ns`, THS `0`; AXI-Lite WNS `+6.438 ns`, AXIS WNS `+4.283 ns`, Core→AXIS WNS `+4.181 ns`, AXIS→Core WNS `+0.289 ns`, and AXI-Lite→Core WNS `+3.919 ns`. The worst Core path is a DPD DSP/CARRY chain (`r4_full_s2[0]` to `p_49_out`), 12 logic levels, 4.014 ns data delay (2.605 ns cell + 1.409 ns route), skew `−0.017 ns`, and slack `+0.240 ns`. The routed utilization is 35,851 LUT, 47,733 FF, 496 DSP, 6.5 BRAM tiles, and 2,981 CARRY8. Vectorless power estimates 3.420 W (0.938 W dynamic, 2.483 W static); the report warns that reset switching activity can make this estimate inaccurate.

Timing exceptions have no whole-clock-group cut. The report retains asynchronous-reset CLR exceptions, first-stage control synchronizer exceptions, the two held-mailbox datapath constraints (`max_dpo=4.571 ns`), XPM Gray-pointer source-period max-delay/bus-skew constraints, and the exact two added XPM reset stage-zero D endpoints. Routed CDC still reports 3 Critical-class reset crossings (CDC-10: one reset-epoch synchronizer CLR cone; CDC-11: two Core-reset-to-AXIS reset synchronizer cones), 101 CDC-15 held-mailbox warnings, 3 CDC-6 Gray-pointer warnings, and one CDC-26 LUTRAM collision warning. These remain protocol/reset-disposition review items; STA exceptions are not CDC waivers. `check_timing` finds three reset inputs without input delay (`core_aresetn`, `s_axil_aresetn`, `s_axis_aresetn`), no output-delay gaps, and no unconstrained data endpoints. Clock interaction still calls the clocks `No Common Clock`; OOC `HD.CLK_SRC` is unset for all three clocks.

Read-only audit artifacts are under `runs/de_resetfix_ppa_08/candidate4/mash_a/implementation/audit_stage0_01/` including Worst-20 setup/hold, Core paths, CDC details, exception, clock interaction, check-timing, utilization, and bus-skew reports. Audit Tcl SHA-256: `9c73c22d465a098c74cbd5ca9159bad919dc5f4b817ff39410cf061cf4d52889`. This is valid evidence for the existing routed placement under the audited exception, but a fresh v10 route with the exception present during implementation is still NOT_RUN. Parent clock source, reset pulse/physical output contracts, and board pin/interface timing are outside this OOC pass.

## Path 1: Core reset release into the AXIS FIFO reset synchronizer

The synthesized EF1 path with slack **−0.827 ns** is a recovery check, not a Core datapath path:

- Launch: `core_abort_sync/sync_q_reg[1]/C`, `core_clk`.
- Endpoint: `u_product/u_cdc/g_xpm_fifo.u_async_fifo/rd_reset_in_wr_reg[0]/CLR`, recovery against `s_axis_aclk`.
- Data delay: 0.720 ns (0.115 ns cell, 0.605 ns route); the unplaced fanout net reports 6,994 loads.
- Clock skew: −0.009 ns; uncertainty: 0.035 ns.
- The corresponding hold/removal path reports +0.321 ns.

`rd_reset_in_wr` is a two-flop asynchronous-assert/synchronous-release guard in `dsm_xpm_async_fifo.sv`; its output prevents writes until the remote read/Core reset has released through two write/AXIS clock edges. The recovery/removal check to its asynchronous reset pins is therefore not an ordinary timed data transfer. The prior XDC only excluded asynchronous CLR pins on names matching `*sync_q_reg*`, so these two reset-guard flops were missed. The next XDC revision extends the exception only to CLR pins of `rd_reset_in_wr` and `wr_reset_in_rd`, both marked `ASYNC_REG`; it does not cut clocks or the synchronizer D paths. The standalone FIFO reset test remains required for that disposition, and routed CDC/RDC must confirm the pattern matches only these local synchronizer cells.

## Path 2: AXI-Lite bundled mailbox sampled by Core

The worst AXI-Lite-to-Core synthesis path is **−0.283 ns**:

- Launch: `u_product/u_cfg/arch_mailbox_reg[0]/C`, `s_axil_aclk`.
- Endpoint: `u_product/u_cfg/arch_pending_core_reg[0]/D`, `core_clk`.
- Data delay: 0.276 ns (0.077 ns cell, 0.199 ns route); zero combinational logic levels.
- Clock skew: −0.008 ns; the arbitrary OOC phase leaves only 0.011 ns requirement at this edge.
- The clock-pair report counts 101 failing AXI-Lite-to-Core endpoints in the DPD/configuration and mode mailbox cones.

Both buses use four-phase request/acknowledge and remain stable at the AXI source until the Core applies the pending value and acknowledges it. Treating the unrelated clock pair as phase-related creates the reported negative edge case. The prepared XDC does not false-path these data buses: it bounds source clock-pin to destination-D datapath delay and bus skew to one Core period, shorter than the synchronized request/capture latency. This exception is conditional on Formal proof of source hold and exact capture. Existing candidate Formal v5 covers the 387-bit DPD pending bank but does not cover the separate runtime architecture mailbox; Formal v6 adds architecture mailbox hold, capture identity, pending stability and apply gating. Do not run the bundled-data timing exception as a product disposition until v6 passes non-vacuously with reachable architecture covers.

## Current synthesis evidence

The EF1 attempt 04 synthesis summary also reports Core-to-Core WNS +1.140 ns/TNS 0, but the full design summary fails on the inter-clock/reset/mailbox checks above. It is not a routed result. `report_clock_interaction` marks these clocks `No Common Clock`; no `set_clock_groups` is used. The XPM Gray-pointer transfers have separate source-period max-delay and bus-skew constraints to stage-zero D pins; they are not false-pathed.

The original synthesis reports are under:

- `runs/de_resetfix_ppa_04/ef1/implementation/synth_timing_summary.rpt`
- `runs/de_resetfix_ppa_04/ef1/implementation/synthesized_cdc.rpt`
- `runs/de_resetfix_ppa_04/ef1/implementation/clock_interaction.rpt`
- `runs/de_resetfix_ppa_04/ef1/implementation/exceptions.rpt`

MASH A has the same class of reset crossing and data-bundle path; see its preserved synthesis reports under `runs/de_resetfix_ppa_05/mash_a/implementation/`. The current MASH B route was launched later and is still running.

## Corrected constraint candidates

- `research/vcu118_arch/run_ppa_abort_candidate_resetfix_xpm_v4.tcl`: narrow async reset-synchronizer CLR exception, AXIS-to-Core first-stage synchronizer cut, and protocol-bounded DPD/architecture mailbox paths.
- `research/vcu118_arch/run_ppa_abort_candidate_resetfix_xpm_v5.tcl`: same constraints, but substitutes the reset-epoch candidate configuration module to match the scoped independent-reset Formal source.
- `research/vcu118_arch/thermo5_ppa_frontend_candidate3.sv`: OOC frontend that instantiates that reset-epoch candidate. This is research-only and is not canonical product RTL.

These are prepared hypotheses, not PASS evidence. Required next results are the v6 mailbox proof, reset-FIFO directed check, Tcl exception audit, full routed timing with Worst-20/hold/bus-skew reports, and a parent-clock/top-level route with actual clock source and interface budgets. Never use the present synthesis WNS as routed closure.

## Completed Tcl v3 exploratory OOC routes — 2026-11-19

The earlier EF1 and MASH A/B implementations completed routing. All three are
**FAIL** as timing studies under the legacy Tcl v3 exceptions: the four-phase
bundled mailbox data buses were still phase-checked as ordinary paths and the
XPM asynchronous-reset synchronizer source was not fully isolated at its
first-stage D pin. These runs are preserved and are not product signoff.

| Configuration | Overall WNS / TNS | Hold WNS / TNS | Core intra-clock | LUT / FF / DSP / BRAM / CARRY8 | Power estimate | Important remaining paths |
|---|---:|---:|---:|---:|---:|---|
| EF1 | −0.435 / −31.817 ns (138 endpoints) | +0.006 / 0 ns | −0.187 / −1.977 ns (33) | 47,227 / 49,874 / 496 / 6.5 / 4,239 | 3.589 W | AXI-Lite→Core mailbox −0.435 ns; Core→AXIS −0.342 ns; async reset recovery −0.378 ns |
| MASH A | −0.377 / −30.773 ns (236) | +0.004 / 0 ns | −0.029 / −2.157 ns (131) | 35,880 / 47,745 / 496 / 6.5 / 2,981 | 3.449 W | AXI-Lite→Core mailbox −0.377 ns; Core→AXIS −0.310 ns; async reset recovery −0.372 ns |
| MASH B | −0.435 / −28.402 ns (105) | +0.006 / 0 ns | +0.122 / 0 ns | 35,860 / 47,759 / 496 / 6.5 / 2,981 | 3.445 W | AXI-Lite→Core mailbox −0.335 ns; Core→AXIS −0.435 ns; async reset recovery −0.372 ns |

The worst mailbox endpoint in MASH B is
`u_product/u_cfg/cfg_pending_core_reg[321]/D`, launched by
`cfg_mailbox_q_reg[321]/C`: data delay 0.316 ns (0.079 cell, 0.237 route),
clock skew −0.009 ns, and only 0.011 ns of arbitrary-phase requirement. This
is a bundled-data crossing and is not a Core arithmetic path. EF1's actual
intra-Core critical path is centered-cubic interpolator state to the
interpolator-to-TID FIFO payload, −0.187 ns. MASH A's actual intra-Core worst
path is −0.029 ns and must still be closed after mailbox paths are handled.
MASH B's Core intra-clock paths meet timing in this study, but its
Core-to-AXIS and mailbox paths do not.

The three reports use Vivado 2026.1 build 6511674, device
`xcvu9p-flga2104-2L-e`, nominal clocks Core 218.75 MHz / AXIS 125 MHz /
AXI-Lite 100 MHz, and provisional 0.2 ns OOC I/O budgets. They lack parent
`HD.CLK_SRC`, board pin constraints and measured insertion delay. Power is a
vectorless default-activity estimate with a reset-activity warning, not a
reliable board power number. Raw DCP and report paths:

- EF1: `runs/de_resetfix_ppa_04/ef1/implementation/`
- MASH A: `runs/de_resetfix_ppa_05/mash_a/implementation/`
- MASH B: `runs/de_resetfix_ppa_05/mash_b/implementation/`

Routed DCP SHA-256 values are EF1
`1ffc21214ceaa14392fd2dd5b1a2fb4bf69c540357007730390e9a781b4797c0`, MASH A
`dff5f713712ecf93c898b9abbab7d5855cb15ef8019413f37b669d9dd910e47f`, and
MASH B `27b410ed422e904938a6686047eb339d0a9c90b6abfa98bae79d7b1ca1042908`.
The vectorless power figures each report roughly 2.48 W device-static power
and have high-fanout reset activity warnings; treat them as low-confidence
comparative estimates only.

## MASH cubic candidate functional equivalence

Candidates A/B have prior focused PASS evidence, independent of these timing
runs: arithmetic bit-true for W=4 across 65,536 cases and W=16 across 100,000
cases; sustained stream 1,025 accepted inputs / 1,024 outputs with zero output
bubbles; and candidate-to-reference stream equivalence across 3,575 outputs,
887 stalls, 668 input bubbles, and one reset. Logs are preserved under
`runs/cubic_candidates_bittrue_02/`,
`runs/cubic_candidates_sustained_01/`, and `runs/cubic_stream_equiv_01/`.
Thus arithmetic/stream equivalence is PASS within those tested contracts;
product Reset/STOP/mode-switch/CDC equivalence and full-top PPA remain open.

## Candidate4/Tcl v8 attempt and v9 retry — 2026-11-19

The first v8 MASH A attempt is **FAIL before route**, not a timing result.
`synth_design` completed, then the Tcl attribute guard rejected
`axil_reset_sync/sync_q_reg[0]` because the script accepted only the string
`TRUE`. Vivado 2026.1 returns the valid Boolean property as `1`. The exact
failure log is `runs/de_resetfix_ppa_07/candidate4/mash_a/vivado.log`; no
synthesized or routed DCP was written in that failed output directory.

The attribute encoding was independently checked by opening the preserved
EF1 synthesized checkpoint in
`runs/de_resetfix_ppa_07/attr_diag_01/`. All ten `dsm_reset_sync` cells in
that netlist (`axil_reset_sync`, `axis_abort_sync`, `core_abort_sync`, and the
two FIFO-local reset synchronizers) report `ASYNC_REG=<1>`. Diagnostic output
is in `cells.txt`; its DCP is the preserved
`runs/de_resetfix_ppa_04/ef1/implementation/synthesized.dcp`. This confirms a
Tcl Boolean-string comparison defect, not missing RTL synchronizer metadata.

The v9 script accepts only the true encodings `TRUE` or `1`, still fails closed
on any other value, and leaves the timing treatment narrow: async-reset CLR
pins and XPM reset synchronizer first-stage D pins only. Later stages remain
timed; mailbox bundles retain one-Core-period max-delay and bus-skew checks;
XPM Gray buses retain source-period bounds. No whole-clock group is introduced.
New outputs are prepared under `runs/de_resetfix_ppa_08/candidate4/`; MASH A
was relaunched first. MASH B and EF1 await the serial run. The v9 Tcl hash is
`3289a187091a988f56bb2073901fef8250c4fb8b0b1f7c888db9fe05f0b92f63`.

Formal v7 independently passes the scoped mailbox block (25/25 assertions,
28/28 non-vacuity goals, 11/11 covers). The v9 MASH A run has passed the
attribute guard: it selects 18 async reset CLR pins, 2 XPM reset first-stage D
pins, both held mailboxes (99 DPD bits and 2 architecture bits), and four XPM
Gray-pointer CDC instances (4/5-bit pointers with 4.571/8.000 ns source-period
bounds). Its synthesis CDC summary still reports three unsafe critical
output-cone endpoints: 1 Core→AXI-Lite and 2 Core→AXIS. These are not waived;
the detailed CDC report must be read from the routed checkpoint and the reset
output/PA contract remains open. `synthesized_cdc.rpt` is a summary report,
not final signoff.

### MASH A v9 synthesis path audit — 2026-11-19 09:36 SGT

The v9 MASH A implementation remains active; this is an intermediate synthesis
checkpoint, not routed timing. Its overall synthesis summary is WNS/TNS
`−0.361/−0.361 ns` at one endpoint, WHS/THS `+0.039/0 ns`; Core-to-Core is
`+1.140/0 ns`. The sole reported setup path is not a Core datapath: it launches
from the XPM FIFO read-reset register
`.../xpm_fifo_rst_inst/gen_rst_ic.fifo_rd_rst_ic_reg/Q` on `core_clk` and
terminates at `.../gen_rst_ic.rrst_wr_inst/syncstages_ff_reg[0]/D` on
`s_axis_aclk`. The clocks are declared independent and have no common period;
the synthesized edge pair leaves only `0.003 ns` nominal requirement. Cell
delay is `0.077 ns`, net delay `0.270 ns`, total data delay `0.347 ns`, clock
skew `−0.007 ns`, and uncertainty `0.035 ns`. This is the intended asynchronous
reset-request input to the first stage of AMD `xpm_cdc_sync_rst`, not a
synchronous data path.

The installed Vivado 2026.1 `xpm_fifo.sv` explicitly connects the read-reset
indication to `rrst_wr_inst.src_rst`; the installed `xpm_cdc.sv` declares
`syncstages_ff` with `ASYNC_REG="TRUE"`, assigns stage zero from `src_rst`,
and shifts later stages on `dest_clk`. This supports a narrowly scoped
first-stage-D exception, while later stages remain timed. The v9 selector
matched the wrapper-local `rd_reset_sync_reg[0]`/`wr_reset_sync_reg[0]` cells
but did not match this internal XPM chain, so its two logged XPM endpoints did
not include the actual critical endpoint. Tcl v10 adds an exact hierarchy/name
and `ASYNC_REG`-guarded selection for the two XPM FIFO remote-reset stage-zero
D pins; it will fail closed unless exactly two are found. Its SHA-256 is
`8af3a1669d50b78d1d8eb5a0862390493904ed66375ea74a84a1f942f6c6bbb3`.
A synthetic hierarchy-pattern check matched both intended stage-zero names and rejected an unrelated stage-zero name. The actual Vivado netlist/ASYNC_REG guard still must run. This targeted exception is prepared, not yet implemented or routed. The v9
route remains useful for reports and is not to be relabeled PASS.

A separate read-only timing/CDC audit is prepared at
`research/vcu118_arch/audit_mash_v9_routed_xpm_reset_exception.tcl` (SHA-256
`9c73c22d465a098c74cbd5ca9159bad919dc5f4b817ff39410cf061cf4d52889`). After
the v9 route exits, it will open that exact routed DCP, verify both XPM
stage-zero `ASYNC_REG` cells, apply only the two D-pin exceptions in-memory,
and emit full routed timing/CDC/clock/exception reports to a new directory.
It does not save or modify a checkpoint. This gives corrected STA evidence on
the completed physical implementation; a full v10 reroute remains available
if the corrected report reveals a true path that needs a changed placement.

v9 synthesized CDC still reports three unsafe output-cone endpoints (one
Core-to-AXI-Lite and two Core-to-AXIS). Those warnings remain open pending
hierarchical reset/PA isolation review and routed `report_cdc -details`.
Synthesis clock interaction lists Core and AXIS as having no common clock;
there are no whole-clock-group exceptions. The OOC top still lacks parent
clock source and board I/O constraints.

Regardless of v9 results, these remain OOC studies with provisional
input/output budgets and no parent `HD.CLK_SRC`/board pin constraints. Do not
call them product timing closure.

## Candidate refresh — 2026-11-18 23:54 SGT

Formal v6 now includes architecture-mailbox reset behavior in addition to the
DPD bundle: source hold, exact capture, pending stability, abort while the
AXI epoch gate is closed, reset defaults, and a post-reset-low requirement
before any architecture commit. Covers exercise pending mode requests across
both Core and AXI-Lite reset. It has not yet run; v5 remains the last proven
scoped result.

Prepared a separate PA-valid CDC candidate, `thermo5_ppa_abort_candidate_v4.sv`,
that removes the redundant combinational `core_epoch_n` gate from the top-level
PA-valid output. The product frontend receives `core_epoch_n` and its PA-valid
state is asynchronously reset by it. This is an equivalence hypothesis until
the directed reset/PA regression and fresh SpyGlass CDC run complete. It does
not change the two exported destination-local reset outputs.

Corrected Tcl v6 checks every targeted reset synchronizer cell for
`ASYNC_REG=TRUE` before applying a false path to its CLR pin. It continues to
constrain the mailbox bundle with max-delay and bus-skew bounds, and does not
cut either clock domain. No routed result has been generated from v6 yet.
