# Execution frontier

## Four-GTH continuous-TX parent checkpoint (2026-10-04)

- The frozen thermo5 2-tap/DPD1/XPM parent now instantiates the generated
  four-channel GT Wizard at 14.000 Gb/s per lane, raw64 user clock
  218.75 MHz, under an **ideal, unverified 125-MHz bank-128 reference**.
  A common TX clock, locally synchronized source/core resets, synchronized
  AXI `run_request`, and PA plane 0..3 to GT channel 0..3 mapping are RTL.
- The GT consumes words continuously, so the new boundary emits an idle
  0xAAAA... word while deasserting the external `pa_enable` request. A
  partial plane valid, a gap inside a 56-word frame, or stopped residual
  payload sets `stream_fault`. Complete-frame gaps are legal. Directed XSim
  PASS; generated-GT behavioral simulation accepted 32 AXI beats and
  observed 56 PA words, then passed post-frame idle, clean stop and common
  reset recovery.
- The first routed parent (`runs/thermo5_qsfp_parent_20261003_230847`)
  had WNS -1.336 ns, WHS +0.006 ns without AXI/core clock grouping; after
  read-only asynchronous re-timing its WNS was +0.293 ns but WHS -0.011 ns.
  Its CDC report exposed source-reset fanout into the core and combinational
  GT-health control. The XPM handshakes now use local-domain resets, GT
  health is synchronized and stable-qualified, and the AXI/free-run/GT clock
  families are declared asynchronous before implementation.
- The first corrected parent at
  `runs/thermo5_qsfp_parent_20261004_141521` completed route with internal
  WNS +0.198 ns, WHS +0.010 ns, zero failing endpoints and four GTH channels.
  Its CDC report improved from 677 to 273 CDC-1 rows, but still identifies
  a free-run `link_ready_q` driving 256 core-domain TX data registers, plus
  two CDC-10 reset paths. The TX boundary now uses local core reset-ready
  and the reset synchronizers take registered link-ready directly. Fresh GT
  XSim, P0 7/7, and IP smoke PASS on this revision. The `162254` route
  stopped at synthesis due to a transient Vivado feature-license failure;
  it is not a timing result. The retried single-process route at
  `runs/thermo5_qsfp_parent_20261004_192407` generated a routed DCP and
  formal WNS +0.257 ns, WHS +0.010 ns, TNS/THS zero, four GTH channels.
  A separate read-only DCP audit completed. CDC-1 fell from 273 to 8 and
  CDC-10 to zero; all eight CDC-1 are in XPM FIFO reset control, while two
  CDC-11 rows concern GT user-clock-active fanout. These critical rows and
  one methodology TIMING-9 remain **open**, not waived. The script wrapper
  reported a late Vivado feature-license error even though route, reports,
  checkpoint and Vivado's normal-exit marker were generated; rely on the
  independently reopened DCP, not the wrapper exit code alone.
  Required legacy `run_ooc_all_dsm.ps1 -Part xc7z020clg400-1` completed:
  12/14 PASS; `p0_ooc_mb_ef2` and `p0_ooc_mb_mash22` fail 100-MHz timing
  at -0.093 and -0.688 ns, exactly matching the 2026-09-19 baseline CSV.
  This is a distinct device/top/constraint, not a thermo5 GT-parent result.
  The routed parent has 468 input and 6 output ports without parent I/O
  delays and lacks AXI/free-run `HD.CLK_SRC`, so its internal STA
  must not be called complete parent/board timing closure.
  GT serial phase alignment, PA blanking latency, SI5341 programming and
  board output remain open.

## Physical four-GT integration gate (2026-10-03)

- **Digital-IC handoff decision:** keep the frozen exact-14.000-Gb/s,
  raw-64/218.75-MHz and Fs/4/3.500-GHz contract. Use an ideal, stable
  125-MHz dedicated GT reference-clock assumption for RTL/GT-boundary
  simulation and integration planning. This is a testbench/implementation
  assumption, **not** evidence that the board's SI5341 is programmed to
  125 MHz. Digital verification may proceed without waiting for board repair.
- Digital signoff still requires the four-plane word-order/valid/reset
  checks, parent clock/reset/CDC/RDC review, and (if a physical FPGA GT
  parent is claimed) routed STA. SI5341 programming, lock/jitter measurement,
  PA/RF output and hardware BERT belong to later FPGA/board validation.
- Existing frozen 2-tap/DPD1 full-front-end four-plane ideal-serializer
  XSim was rerun on 2026-10-03: 64 input words and 4,096 bits per path PASS;
  the testbench coefficient-port width warning was corrected without changing
  the driven identity coefficient. This is **not** actual GT primitive timing.

- Schematic pages 8/19/25 show QSFP1 four TX/RX pairs on GTH bank 128 and a
  156.25-MHz bank-128 reference clock. Vivado package-planning independently
  confirms all four `GTHE4_CHANNEL_X0Y4..X0Y7` sites and common
  `GTHE4_COMMON_X0Y1` for `xczu15eg-ffvb1156-2-i`. The older dual-SFP-only
  statement was incomplete; pin availability is no longer the blocker.
- Vivado GT Wizard four-lane probes: exact 14.0 Gb/s with the actual
  156.25-MHz reference is **rejected**; 14.0625/156.25 and 14.0/125
  generate. The latter requires an unverified 125-MHz SI5341 bank-128
  output configuration. Do not silently change the 14.0-Gb/s/218.75-MHz
  frozen clock to 14.0625 Gb/s/219.7265625 MHz.
- Next digital gate: review the eight XPM-reset CDC-1 and two GT CDC-11
  paths with reset protocol/RDC evidence, then supply real AXI/freerun
  clock sources and I/O min/max budgets for full parent interface STA.
  Next board gate: verify the SI5341 125-MHz setting, lock and reset after
  the power fault is resolved. Routed internal timing is available above;
  physical 14-Gb/s board output is not verified.

## Boundary work checkpoint (2026-10-03 15:39 +08:00)

- Legal AXI bubble/PA stall phasing hits both targeted empty/backpressured
  states. Recompiled generic and real-XPM VCS seven-case UVM suites PASS;
  fresh URG confirms the exact `u_interp_1` line-69 and `u_interp_2`
  line-71 condition bins. Generic eight-VDB merge including independent
  extreme seed: overall/condition/toggle 87.20/79.79/84.20%; XPM
  80.16/69.68/81.56% including vendor hierarchy. The distinct
  `u_interp_1` line-71 stage-1-empty bin is still open.
- Frozen DPD1 identity: arithmetic all-16-bit proof plus actual RTL XSim/VCS
  196,608 complex samples/output comparisons PASS, zero valid/invalid
  saturation, counter reached bit 17. Two-tap interpolation interval proof
  and reset/bubble block XSim PASS. Generic/XPM extreme 32/56 VCS PASS;
  long extreme 576/1,008 full-chain XSim PASS with all 16 lane counters
  checked. Fresh per-instance URG: generic 216 condition bins/69 unhit,
  280 toggle rows open; XPM 228/74 and 286 rows open. No blanket waiver.
- GT PRBS/known-word BERT and frozen 2-tap/DPD1 four-plane ideal serializer
  loopback PASS in XSim. Parent run-request/reset CDC/RDC, actual GTH,
  board/pin timing and measured RF output remain open. The board power fault
  precludes any physical-output claim.
- Next gate: decide/test the remaining reachable `u_interp_1` stage-1-empty
  state and full-chain reset-with-enable, then review each open branch/toggle
  item. Integrate a real parent source/reset tree, I/O timing budgets and
  GT refclk/pin mapping before rerunning CDC/RDC/STA; OOC alone is not signoff.

## Frozen thermo5 directed coverage and payload matrix before phase retargeting (2026-10-03)

The full-chain AXI valid-gap/PA-stall test now counts valid holds, empty
bubbles, and backpressure at both interpolators and DPD. The valid-hold bins
that were specifically targeted are hit in generic and XPM runs; two distinct
empty/backpressured bins remain open with zero observation counts. Generic
and real-XPM seven-case VCS regressions PASS: 32 input beats, 56 words, all
four MATLAB planes bit-true. Three independent MATLAB payload seeds
(101/202/303) pass 32/56 in both FIFO implementations. Seven-case URG:
generic 86.97% overall/78.72% condition; XPM 80.14%/69.83% (vendor
hierarchy included). Generic per-instance audit: 216 condition bins,
146 hit/70 open; 424 toggle signal-gap rows and 30 branch line-gap rows.
Open categories are listed per instance in the coverage CSV and verification
record. Long-stream counters, DPD saturation, TID input-range toggles,
reset modes, and CDC reset release remain open unless individually proved.
Next: continue those bins, then integrate parent `run_request` and both
resets for CDC/RDC and bring the GT boundary into system signoff. Board
output is not claimed verified.

## Integration timing/CDC and URG instance audit (2026-10-03)

Defined an explicit parent-level thermo5 125/218.75-MHz timing contract:
`run_request` must launch in the core domain; the two reset inputs require
coordinated assertion and domain-synchronous release; all I/O min/max budgets
must be supplied by the parent. No reset/control false path is added by the
new contract. The archived routed OOC still contains its old broad false path
and cannot sign off parent interfaces. Path inventory: 4 XPM clock-to-clock
synchronizer rows plus 46,423 input-port-clock rows (7,858 request, 38,446
core reset, 119 source reset). CDC/RDC remains open until integrated reroute
and reset review. URG inventory now identifies 88 uncovered condition bins
across 30 DUT instances, plus toggle/branch gaps, with individual families
documented; **not coverage closure**. Next: instantiate/synchronize parent
request/reset, apply real board budgets, rerun routed CDC/STA, and close the
remaining reachable full-chain bins or prove precise SKU exclusions.

## Frozen thermo5 XPM UVM and CDC audit (2026-10-03)

The same six-case licensed VCS UVM regression now passes with the actual
Vivado 2024.1 XPM FIFO simulation source and a separate XPM database; the
generic-FIFO regression was rerun and also passes. XPM URG merge passes:
functional groups 100%, overall 80.60% including vendor internals (not
comparable with generic 86.59%). Directed XSim XPM seed 10 also passes
32/56 four-plane bit-true with 14 PA stalls. No RTL arithmetic changed.
The routed frozen-SKU DCP still has WNS/WHS +0.316/+0.027 ns, but the new
Vivado `report_cdc` is **not clean**: true source/core crossings are the XPM
Gray-pointer/reset synchronizers, while unclocked OOC control/reset ports
produce many critical CDC findings. Static CDC/RDC signoff is open pending
an integration-level I/O/reset contract and path review; SpyGlass was not
run. URG red-line inventory is documented, not waived or closed. Next:
triage OOC CDC findings by real integration clocks/resets, then per-instance
condition/branch/toggle bins and a scoped lint/RDC run.

## UVM target-role directory migration (2026-10-01)

The two existing UVM targets now have separate `env/{axi_ip,thermo5}`,
`sequences/{axi_ip,thermo5}`, and `tests/{axi_ip,thermo5}` directories; 47
source files moved byte-for-byte without changing RTL, class behavior, or
MATLAB golden vectors. Reusable protocol agents stay in `agent/`. Both target
filelists resolve; licensed VCS thermo5 six-case regression and old AXI-IP
`dsm_bp_test` PASS. URG merge remains 86.59%; MATLAB P0 7/7 PASS. The stale
Python generator/regression paths were corrected; seven hash-identical
generated duplicates under `dv/uvm_verif/` were moved recoverably to `runs/`.
The DUT port map, RTL chain, and MATLAB oracle ownership are documented in
`docs/verification/thermo5-uvm-architecture.md`. Next: keep the two DUT
regressions independent, close named uncovered bins by test/check/coverage
mapping, and avoid calling XPM/GT/PA verified from generic-FIFO UVM.

## Reachable coverage follow-up (2026-10-01)

Added separate VCS/URG block tests for frozen 2-tap interpolation bubbles,
backpressure, and reset-with-enable, plus programmable one-tap memory-DPD
empty-pipeline backpressure and I/Q saturation. Both PASS with checked data
and counters; URG confirms the targeted line-70 and line-140 condition rows
and valid-output I/Q saturation rows. No RTL/MATLAB change and no merge into
the frozen six-case UVM score (still 86.59%). Fixed DPD1/identity and
low-power-off holes are justified one by one in
`docs/verification/thermo5-uvm-coverage.md`; no blanket waiver. Remaining:
triage other instance/bin holes and the DPD invalid-slot saturation row,
then programmable-DPD and low-power-on coverage targets if those modes are
promoted to supported SKUs.

## Thermo5 UVM responsibility refactor (2026-10-01)

The frozen generic-FIFO thermo5 SKU now uses a real active AXI source agent
(item/sequencer/driver/accepted-beat monitor), MATLAB-vector source sequence,
control BFM for reset/core-enable/PA-ready, and a dual-analysis-port
source/PA scoreboard with reset epochs. No DUT RTL or golden vectors changed.
Licensed VCS six-case regression, URG merge, and 10 seeds each of PA-stall
and FIFO-boundary stress pass. URG reports functional groups 100%, overall
86.59%, and CDC FSM 7/7 states plus 12/12 transitions. Full-chain directed
XSim with vendor XPM FIFO and PA stalls passes seeds 7/8/9; this is separate
from the generic-FIFO UVM coverage database. The old AXI-IP VCS compile and
`dsm_bp_test` smoke also pass. Detailed test/bin ownership and unhit RTL
triage are in `docs/verification/thermo5-uvm-coverage.md`. Remaining work:
line-level closure for legal condition/branch/toggle holes, then broader
payload seeds and FPGA/GT hardware verification when available.

## UVM layout checkpoint (2026-10-01)

The two UVM targets remain separate: `thermo5_sku_uvm_tb` compiles the frozen
two-clock thermo5/2-tap/DPD1 frontend, while `dsm_uvm_tb` compiles the older
AXI-IP top. Fifteen AXI-IP virtual-sequence files now live in
`dv/uvm/sequences/`; two previously stranded bit-true tests were restored to
`dv/uvm/tests/`. The legacy filelist adds the sequence include directory.
No DUT RTL, transaction behavior, or still-referenced UVM source was removed.
Licensed VCS: thermo5 six-case regression PASS; AXI-IP `make vcs` and
`dsm_bp_test` PASS with zero UVM errors/fatals. The later responsibility
refactor added a real AXI source agent; XPM FIFO and physical GT remain
outside this UVM signoff.

## Mission

Repository organization is now tracked by
`docs/exec-plans/active/physical-migration-map.json`. The AI-native navigation
layer is generated under `docs/ai-native/`; `rtl/`, `dv/verif/`, and `dv/uvm/`
are the canonical paths. The verification trees were physically migrated with
Git history preserved and root-relative consumers rewritten; targeted path and
filelist checks are the acceptance gate.

The first full TSMC28 thermo3 DC run (`syn/reports/asic_thermo3_tsmc28_20260923_213624`)
was terminated by hangup during `compile_ultra` mapping optimization. It produced
`library.rpt`, `check_design.rpt`, and `check_timing_pre.rpt`, but no final area,
setup/hold, power, DDC, or mapped-netlist reports. This is an incomplete run, not
an ASIC timing or synthesis PASS. The next attempt should use a persistent Rocky
terminal/session and a bounded DC compile strategy before retrying thermo5.

The persistent bounded thermo3 and thermo5 runs launched on 2026-09-24 remain
active in `runs/20260924_103939-dc-thermo3-tsmc28/` and
`runs/20260924_105002-dc-thermo5-tsmc28/` (Rocky processes `common_shell_exec`
PIDs 836 and 1038 at the last audit). Both entered standard-cell mapping, but
the log shows an unresolved `gt_tx_raw64_boundary` reference because the ASIC
source list does not yet include that RTL dependency. No final reports, DDC,
or mapped netlists exist; this run is invalid for signoff and must be restarted
after resolving the source list. Therefore ASIC synthesis/STA/power is still
pending, not PASS. The post-migration GT BERT XSim compile/elaboration
succeeds, but the Windows simulator returns `-1073741790` during execution,
so no new simulation PASS is claimed.

The corrected thermo3 restart at `runs/20260924_123132-dc-thermo3-tsmc28/`
did not enter synthesis: DC exited immediately with `DCSH-1`. A later audit
confirmed the local FlexNet server is now UP (`lmutil lmstat` reports `SSS` 1
issued/0 in use). A new explicitly licensed thermo3 bounded run is active at
`runs/20260924_1240-dc-thermo3-tsmc28/`; it has loaded all 17 designs including
the GT boundary and is currently in pre-compile constraint/check processing.
No final reports or netlist exist yet, so ASIC PASS is still not claimed.

The subsequent thermo3 run at `runs/20260924_1240-dc-thermo3-tsmc28/` completed
with all reports and both mapped netlist formats. It has zero timing violations
at 125/218.75 MHz and no unresolved design references; the remaining `unmapped
MV Cells` text is a zero-count multivoltage summary, not unmapped logic. This
is a standard-cell-only, TT, vectorless-power pre-layout result.

Deliver a reviewable FPGA/ASIC-oriented digital transmitter IP handoff.

- Device: `xczu15eg-ffvb1156-2-i` for FPGA evidence.
- Core cadence: `64 x 218.75 MHz = 14 GS/s` real-sample output cadence.
- Digital carrier mapping: one `Fs/4` mapping produces a 3.5 GHz IF.
- A `14 Gb/s` value refers to raw GT serial line rate, not a 14 GHz RF carrier.
- QAM acceptance uses one fixed OFDM/BPF/DDC/synchronization/demodulation path:
  EVM <= 3.5% and SNDR >= 29.12 dB.

## Active implementation

The thermo3 baseline and thermo5 extended frontend are both timing-closed
with a runtime identity memory-DPD wrapper. The wrapper is physically
implemented, with identity coefficients; it is not a DPD-free synthesis
shortcut.

```text
125 MHz AXI-S, 14 complex samples/beat
  -> asynchronous FIFO
  -> fixed 14:8 gearbox
  -> 218.75 MHz core, 8 complex samples/word
  -> Q2.14 frame gain
  -> x2 polyphase interpolator
  -> 16-lane 4-tap memory-DPD (identity coefficients)
  -> x2 polyphase interpolator
  -> 32-lane Cartesian thermometric TID
  -> two thermo3 raw planes, 64 raw bits/plane/core word
```

- Both clock domains sustain exactly 1.75 GS/s complex input throughput.
- Lane 0 is the earliest sample; interpolated lanes are new time samples,
  never zero-filled lanes.
- `frame_start` is legal only on a 56-sample superframe boundary.
- The FIFO must prefill before the recursive core is enabled.
- Underflow or a bubble in an active frame is an error.
- The pre- and post-DPD elastic slices preserve word atomicity and add only
  fixed latency; coefficients, history, quantization, ordering, and state
  update order are unchanged.

## Signed-off FPGA fabric evidence

Full routed OOC, not a Quick diagnostic:

| Item | Result |
|---|---|
| Top | `tid32_thermo3_axis_frontend_tx_ooc` |
| Flow | `opt_design -> place_design -> phys_opt_design -> route_design` |
| Core clock | 218.75 MHz (4.571 ns) |
| AXI clock | 125 MHz (8.000 ns) |
| Setup / hold | WNS `+0.290 ns`, WHS `+0.027 ns` |
| Aggregate slack | TNS/THS `0 / 0` |
| Tool result | 0 errors, 0 critical warnings |
| Core endpoints | 208,286 setup and hold endpoints, zero failing |
| AXI endpoints | 145 setup and hold endpoints, WNS/WHS `+4.966/+0.047 ns` |
| Utilization | 59,921 LUT, 83,797 FF, 6.5 BRAM, 2,030 DSP |

Artifact: `syn/out/tid32_thermo3_axis_frontend_20260921_104738/`.

The identically scoped thermo5 full routed OOC also passes at 218.75 MHz:
WNS/WHS `+0.308/+0.027 ns`, TNS/THS `0/0`, with 0 errors and 0 critical
warnings.  It uses 71,869 total LUTs (62,308 logic and 9,561 memory), 97,249
registers, 6.5 BRAM tiles, and 2,032 DSP48E2.  Artifact:
`syn/out/tid32_thermo5_axis_frontend_20260921_213551/`.

The frozen comparison is in `docs/THERMO3_THERMO5_ROUTED_PPA.md`.  Thermo5
adds 11,948 total LUTs, 13,452 registers, and 2 DSPs, while retaining slightly
more setup margin.  Both worst paths are ten-level memory-DPD DSP/carry paths.
The reported 103,766/121,078 high-fanout nets are the routed global core clock,
not failing valid/data nets.  Both variants have the same fixed core pipeline
depth and one-word-per-core-clock steady-state throughput.

The independent XPM CDC wrapper also has a routed ZU15EG result:
WNS/WHS `+1.807/+0.042 ns`, 896 LUT, 749 FF, 6.5 BRAM, and 0 DSP.
This proves neither the complete frontend nor a GT target.

## Functional evidence

- Thermo3 and thermo5 frontend MATLAB-to-XSim tests: PASS.
- Each test covers 64 input words and 2,048 final complex samples.
- Raw output mismatch: zero for every checked plane.
- Project P0 regression: 7/7 PASS, 65,536 samples/design, zero mismatch.
- IP smoke regression: 5/5 PASS.
- Generic Gray FIFO and FPGA XPM FIFO CDC tests: PASS for 112 contiguous
  samples, 14 core words, no order/frame/gain mismatch, bubble, or underflow.
- CDC executable checks cover asynchronous-assert/two-edge synchronous reset
  release, single-bit-or-zero local Gray-pointer updates, no accepted
  full/empty transaction, legal 14:8 residual populations, 56-sample frame
  boundaries, stable backpressured payload/metadata, a four-source-word FIFO
  prefill, and no core output before explicit enable.
- Thermo5 four-plane behavioral serializer loopback: PASS for 64 words and
  4,096 serial bits per path, with recovered words matching MATLAB golden
  words.  This is an ideal model and not GT or board evidence.
- Vendor-neutral raw-link bring-up/BERT endpoint XSim: PASS.  The endpoint
  implements known-word training, PRBS31 word generation/checking, link/reset
  state transitions, sticky error and error counters, clear/retrain recovery,
  single-cycle error injection, and protocol assertions.  It is connected at
  the same 64-bit user-word boundary used by `gt_tx_raw64_boundary`; it does
  not model GTH analog/CDR behavior.
- Training-to-run uses an explicit run-arm/drain cycle to absorb the one-word
  loopback latency before PRBS phase starts.  The launcher requires the PASS
  marker and rejects fatal/error diagnostics instead of trusting exit status.
- Vivado 2024.1 GT Wizard generation: PASS for ZU15EG GTH `X1Y12`, RAW
  14.0-Gb/s TX/RX, 125-MHz refclk, 64-bit user data, with synthesis and
  simulation targets generated outside the source tree.  Vendor GT behavioral
  integration and routed GT implementation remain pending; no board claim is
  made.  The BERT top now has a routed implementation entry point; the run
  completed with 0 DRC errors and positive constrained setup/hold slack, while
  vendor PRBS acquisition remains a behavioral-model limitation.
- Added a concrete GT/BERT integration top with RXSLIDE alignment, an
  asynchronous RX-word FIFO, vendor behavioral simulation script, and routed
  implementation script.  GT behavioral simulation reaches all GT ready/lock
  status outputs; PRBS acquisition still needs final closure for the model's
  variable RX latency and is not claimed PASS.

## RF-model evidence and limits

- Full frontend plus behavioural switching-DPA/BPF/DDC passes 256-QAM at
  17.08984375 MHz: identity EVM `2.3917%`, SNDR `32.4257 dB`.
- A 250 MHz thermo5 peak-normalized mild-profile simulation passed three
  isolated seeds; it is not a constant-RMS, physical-PA, or board result.
- The 4-tap memory-DPD candidate failed held-out deployment acceptance;
  active coefficients remain identity.
- DPA, BPF, ACLR, and PA results are parameterized digital simulations, not
  measured RF hardware characterization.

## Explicitly not signed off

- Board discovery attempt (2026-09-26): Vivado Hardware Manager reached
  `127.0.0.1:3121/xilinx_tcf/Xilinx/15051A`, proving the host-to-cable path.
  `open_hw_target` reported no JTAG devices, so no FPGA part, configuration,
  ILA, GT, or board-loopback evidence is available yet. This probe was
  read-only: it did not program, reset, or otherwise modify the target.
- No four-lane physical GT/serializer timing or board mapping exists.
- Existing dual-SFP GT evidence uses a deterministic smoke payload, not this
  QAM frontend, and has no loopback/BERT/recovered-word result.
- No physical PA, coupler feedback, RF channel, antenna, or measured ACLR
  claim exists.
- OOC warnings about `HD.CLK_SRC` and `HD.PARTPIN_LOCS` are non-critical for
  this result; real top-level/GT integration must provide actual constraints.

## Current execution order

1. Complete the activity-based low-power comparison. Thermo3/thermo5 LP full
   routed OOC now close at 218.75 MHz; the remaining experiment must use the
   same workload-derived SAIF, device, constraints, and full implementation
   flow for baseline and LP. Do not infer savings from vectorless estimates.
2. Run fixed-point algorithm/PPA sweeps for interpolation taps, thermometric
   step/drive, and frame scaling. Every point must preserve bit-true
   contracts and report EVM/SNDR together with resource/timing cost.
3. Connect the completed BERT endpoint to the generated ZU15EG GT Wizard user
   port, run vendor behavioral simulation, and perform GT-aware implementation
   with the actual refclk/package XDC.  Keep physical CDR/BER/eye results
   explicitly deferred until hardware is available.
4. Add a vendor-neutral PRBS31/known-word generator and checker, link/reset
   FSM, error counters, sticky status, assertions, and behavioral error
   injection.  Keep the ideal serializer result distinct from physical GT.
   (The endpoint is implemented; next step is integration with the selected
   GT Wizard user port.)
5. When a valid 28 nm `.db` standard-cell library is supplied, build a
   separate ASIC pre-layout synthesis/STA SKU. Do not infer ASIC results
   from FPGA OOC or require analog PA/serializer libraries for digital RTL
   synthesis.
   Environment audit: Rocky-8.10 WSL has Synopsys DC V-2023.12-SP1 at
   `/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell`. The standard-cell probe
   completed successfully against the TSMC28 RVT TT `.db`, reporting 839
   cells and 15 inverter-name matches. ASIC-specific thermo3/thermo5 wrappers,
   source list, dual-clock SDC, and DC flow are now present under `syn/asic`.
   The first real thermo3 run reached mapping optimization after fixing an
   existing 8-lane wrapper width mismatch; final reports are still pending.
   The referenced SRAM `.db` path under `/home/ray/ic/CIMForge/syn/out/`
   `pdk_cache/TS1N28HPCPL2SVTB4096X32M4MWBASO_tt0p9v25c.db` is absent, so
   macro-aware synthesis remains blocked until that library is restored.
6. Perform GT/board loopback or BERT only when actual port, reference-clock,
   reset, and loopback resources are available.

## Handoff checkpoint (2026-09-24)

- Verification trees are physically organized under `dv/verif/` and `dv/uvm/`;
  root `verif/` and `uvm_verif/` no longer exist. Filelists and consumers were
  updated and the migration map marks both moves complete.
- The two DC runs above are the next execution frontier. When either exits,
  require `area.rpt`, setup/hold timing, power, DDC, and mapped Verilog before
  parsing or claiming a result; keep standard-cell-only and vectorless-power
  limitations explicit.
- Runtime files (`realTime.*`, run PID files) are now ignored. They were
  already present in an earlier Git commit and could not be removed from the
  index in this restricted session because `.git/index` denied creation of
  `index.lock`; remove them with `git rm --cached` in a normal writable clone.

## Digital-IC portfolio narrative

- Multi-clock streaming IP: rate-matched AXI ingress, asynchronous FIFO,
  reset contract, and deterministic 14:8 gearbox.
- Timing closure: converted a routing/fanout-limited `-1.524 ns` frontend
  failure into a full-flow `+0.290/+0.027 ns` setup/hold pass at 218.75 MHz
  without lowering frequency or changing numerical behavior.
- Verification: MATLAB fixed-point oracle, bit-true XSim, assertions, P0,
  IP smoke, routed STA, and explicit evidence boundaries.
- PPA trade-offs: scalable thermo3/thermo5 output architecture, pipelining,
  local valid distribution, FIFO BRAM cost, DSP use, latency, and timing.
- Low power: a measurable FPGA activity/clock-enable study that maps cleanly
  to ASIC ICG/UPF intent later, rather than an unsupported UPF claim today.
  Stage-1 controller states are RESET/IDLE/PREFILL/RUN/DRAIN/ERROR. The
  controller requires four accepted AXI words (one 56-sample superframe) before
  enabling the core and drains in-flight words before returning to IDLE.

The pre-run-request Stage-1 low-power timing implementation closed. Two
independent managed Vivado OOC projects are under `fpga/thermo3_lp/` and
`fpga/thermo5_lp/`.
Vivado 2024.1 full synthesis, placement, physical optimization, and routing on
`xczu15eg-ffvb1156-2-i` produced the following results at 218.75 MHz:

| LP project | WNS | WHS | CLB LUT | CLB registers | BRAM | DSP |
|---|---:|---:|---:|---:|---:|---:|
| thermo3 | +0.147 ns | +0.027 ns | 60,094 | 84,693 | 6.5 | 2,032 |
| thermo5 | +0.103 ns | +0.026 ns | 71,713 | 97,796 | 6.5 | 2,032 |

Both routed runs have TNS/THS 0, zero implementation errors, zero critical
warnings, and complete routed checkpoints. The focused power-controller XSim
test also passes. Vectorless routed estimates are 6.040 W for thermo3 and
6.540 W for thermo5, both with Medium confidence; these pre-revision vectorless
figures are retained for historical PPA context. They are not evidence of
low-power savings; the matched-SAIF results below are the current power
evidence. ASIC ICG mapping remains pending.

The pre-revision audit classified this as an activity-gating prototype, not
complete low-power signoff: its OOC wrappers tied `core_enable` high, the
vectorless analysis never exercised IDLE/DRAIN, and `lp_ingress_enable` did not
gate AXI/FIFO acceptance. Those limitations motivated the revision below.

The next RTL revision now exposes `run_request` on all thermo OOC tops, gates
LP AXI acceptance with the source-domain ingress qualifier, lets the LP
controller own the CDC enable through DRAIN, and adds an explicit CDC
`core_drain` protocol so legal end-of-run FIFO empty does not become a sticky
underflow. A common activity testbench and reproducible scripts generate and
compare baseline/LP continuous, burst, and long-idle transactions, produce
mode-specific SAIF, rebuild each routed design once, and report matched-net
coverage plus dynamic-power reduction.

The activity contract now uses a 512-beat no-bubble continuous workload and
fixed core-clock observation windows for every baseline/LP pair. Burst and
long-idle runs carry the same useful words in both modes. Power analysis is
blocked unless accepted-word count, output-word count, output digest, and
observation-cycle count agree, both implementations close setup and hold, and
Vivado reports the configured minimum SAIF design-net matching. The current
run uses a 5% minimum because only directly matched RTL nets are counted;
Vivado propagates activity to the remaining implementation nets. This prevents
drain latency or an unmapped activity file from creating a false reduction
claim.

The following historical execution note is superseded by the completed
2026-09-26 run below. In the earlier restricted Windows session
`xvlog` exits before parsing RTL with `-1073741790` and an empty log; the
focused controller launcher now checks tool exit codes and correctly reports
this failure instead of accepting a stale PASS log. Rocky WSL/VCS fallback was
also unavailable because WSL access escalation failed in the host approval
service. Consequently the retained `+0.147/+0.027 ns` and `+0.103/+0.026 ns`
checkpoints were pre-revision evidence only. The required execution has now
completed; see `Matched-SAIF low-power closure (2026-09-26)` above.

A user-terminal rerun on 2026-09-26 progressed through `xvlog` and exposed a
separate launcher defect at elaboration: PowerShell redirected process output
to `xelab.log` while `xelab` simultaneously tried to create its default
`xelab.log`, producing `[Common 17-183] Failed to open handle xelab.log` for
both thermo3 and thermo5. The launcher now passes explicit `-log xelab.log`
and `-log xsim.log` options without shell redirection, eliminating the Windows
exclusive-file collision. A post-fix run is still required; the restricted
agent process again terminated `xvlog` before it emitted a log, and its
external-execution approval service did not provide a runnable session.

The prior quick-OOC failures and Vivado realtime-helper crashes are superseded
by these clean managed-project runs. OOC `HD.CLK_SRC` and `HD.PARTPIN_LOCS`
warnings remain expected integration limitations until a device-level parent
provides physical clock and partition-pin constraints.

## Matched-SAIF low-power closure (2026-09-26)

The revised run-request/ingress-gating RTL is now functionally and physically
closed for both thermo variants. Each flavour completed continuous, burst, and
long-idle baseline/LP activity simulation with identical accepted words,
output words, digest, and observation cycles. Six SAIF files per flavour were
generated and consumed by fresh routed DCPs.

Thermo3 evidence is in
`runs/lp_power_ab/20260926_121341_thermo3/power_comparison.csv`:
baseline/LP timing is `+0.308/+0.027 ns` and `+0.235/+0.027 ns` (WNS/WHS);
dynamic-power reduction is 1.14% continuous, 5.45% burst, and 4.01% idle.

Thermo5 evidence is in
`runs/lp_power_ab/20260926_152500_thermo5/power_comparison.csv`:
baseline/LP timing is `+0.089/+0.023 ns` and `+0.139/+0.017 ns` (WNS/WHS);
dynamic-power reduction is 1.76% continuous, 6.02% burst, and 4.63% idle.
All six thermo5 reports have 7% direct SAIF net matching with zero baseline/LP
coverage delta. Confidence is Medium: RTL-SAIF direct matching plus Vivado
activity propagation. These are routed FPGA estimates, not ASIC or silicon
power signoff.

The matched-SAIF experiment is complete for thermo3 and thermo5. Remaining
low-power work is optional refinement (broader workloads, SAIF coverage
improvement, and ASIC ICG/UPF mapping), not a missing FPGA timing result.

## SAIF mapping audit (2026-09-26)

The thermo3 routed-DCP/RTL-SAIF mapping was rechecked with the recorded
`tb_tid32_thermo3_baseline_lp_power/u_tb` strip path. Vivado again annotated
`19,984/293,705` design nets (7%). The SAIF contains the complete `u_dut`
hierarchy, so this is not a missing-DUT or strip-path defect; it is the
expected name/optimization gap between RTL simulation and the routed FPGA
netlist. Do not claim higher coverage by changing the strip string. A
material coverage increase requires functional/post-synthesis netlist
simulation (or an equivalent implementation-netlist activity source).

## Post-route activity and algorithm/PPA screen (2026-09-26)

- Added `syn/write_funcsim_netlist.tcl` and
  `dv/verif/scripts/run_xsim_lp_power_postroute_activity.ps1`.  A thermo3
  baseline routed checkpoint was successfully exported as a 55.6-MB Vivado
  functional netlist and compiled/elaborated with the common LP activity
  testbench.  The launcher now selects the escaped generated DUT hierarchy
  through `get_objects -r *u_dut*`, rather than an invalid slash path.
- Full post-route activity completion is **not yet available** on this host:
  elaborating the 2,030-DSP functional netlist consumes about 7.7 GB and did
  not finish within the bounded interactive run.  Therefore the current 7%
  direct RTL-SAIF match and the 1.14--6.02% dynamic reductions remain
  Medium-confidence FPGA estimates, not upgraded post-route-SAIF evidence.
  The reusable export/simulation flow is ready for a long-run workstation
  job; do not substitute a smaller RTL activity file for that job.
- Added and ran
  `matlab/tx_bandpass_if/run_tid32_thermo_algorithm_ppa_screen.m` with the
  fixed 218.75-MHz/14-GS/s raw-Fs/4/DDC receiver contract.  At 99.121 MHz,
  default thermo3 (offset 8192) and thermo5 (step 7168) pass all three seeds,
  with respectively 1.685--1.954% / 34.18--35.47 dB and
  1.591--1.810% / 34.85--35.97 dB EVM/SNDR.  At 249.512 MHz, thermo3 fails
  all three seeds (4.299--4.426%, 27.08--27.33 dB), while thermo5 passes all
  three (3.119--3.225%, 29.83--30.12 dB), with zero raw-stream mismatches.
  Results are retained under `matlab/out/tid32_thermo_algorithm_ppa_screen*/`.
- The screen joins only the two actually routed default PPA points:
  thermo3: 59,921 LUT / 83,797 FF / 2,030 DSP / +0.290/+0.027 ns;
  thermo5: 71,869 LUT / 97,249 FF / 2,032 DSP / +0.308/+0.027 ns.
  Non-default offset/step rows are deliberately marked `default_only`; an
  interpolation-tap or DPD-tap PPA claim requires parameterized RTL and a
  separate routed run.

## Parameterized interpolation/DPD PPA SKUs (2026-09-26, running)

- The synthesis boundary now exposes real structural parameters:
  `INTERP_TAPS={2,3,4}` and `DPD_MAX_TAPS={1,2,4}`.  Four-tap cubic
  interpolation and four memory taps remain the default, bit-compatible
  configuration.  New two-tap linear and three-tap causal-quadratic presets
  retain unity DC gain but require separate communication-quality evaluation.
- OOC tops may additionally set `DPD_ACTIVE_TAPS` as a compile-time constant.
  This is intentionally distinct from the deployed runtime `active_taps`
  port: only the compile-time mode enables synthesis to remove unselected
  memory-polynomial structures.  All summaries record the selected SKU.
- Default thermo3 and thermo5 frontend bit-true XSim both pass after the
  parameter plumbing.  The P0 XSim runner's stale pre-migration testbench
  paths were corrected; its seven-test full completion is pending an
  uninterrupted host run.
- The first actual timing SKU is running as a full 218.75-MHz routed OOC:
  `thermo5 / INTERP_TAPS=2 / DPD_MAX_TAPS=1 / DPD_ACTIVE_TAPS=1`.
  Do not infer its PPA or timing result until its `summary.csv` exists.
- Corrected the P0 MATLAB comparator's stale pre-migration paths to
  `dv/verif/{vectors,out_xsim_p0}` and reran
  `scripts/run_matlab_p0_bittrue_check.cmd`: all seven 65,536-sample designs
  pass with zero mismatches.
## LP timing/power revision (2026-09-24)

## Fair SKU matrix and TDD sparse-power workload (2026-09-27, historical run)

- Added a reproducible 18-SKU matrix: `thermo3|thermo5` × interpolation
  `2|3|4` taps × identity memory-DPD wrapper `1|2|4` taps.  Every algorithm
  point uses the same 250-MHz 256-QAM OFDM payload, synthetic-mild DPA/BPF/DDC
  profile, fair-RMS drive, and three isolated held-out seed sets.  Identity
  DPD has tap0=1 and delayed coefficients=0; it is a PPA/latency comparison,
  not an asserted RF-quality benefit.
- A first full-chain smoke point, thermo5/2-tap/1-tap, passed all three seeds:
  worst EVM 3.2533%, worst SNDR 29.7536 dB, filtered ACLR -30.5331 dBc, and
  zero raw-word mismatches.  Full algorithm matrix output is running at
  `runs/thermo_sku_matrix/algorithm_full_20260927_111823/`.
- The matching full-routed OOC matrix is running at
  `runs/thermo_sku_matrix/ooc_20260927_111823/`; each row is a separate
  218.75-MHz route with its own utilization and timing reports.  No pending
  row may be represented by a default-SKU result.
- Added a four-grant sparse TDD downlink workload (32 accepted AXI words in a
  common 4,608-cycle window).  RTL XSim passes for thermo3 and thermo5,
  baseline and LP: output count/digest match in each pair and LP has no
  underflow.  Routed-DCP SAIF power reporting is in progress; do not claim a
  new power percentage until both reports are emitted.

- Added registered local CE qualifiers at the frame-gain and thermo frontend
  boundaries. The AXI/CDC ready/valid path remains unchanged; baseline uses a
  generate branch with direct `core_enable`.
- Added `syn/run_lp_power_compare.ps1`. It requires an explicit SAIF file and
  runs baseline and LP with the same device and full implementation flow,
  emitting a comparison CSV and activity provenance. No power percentage is
  claimed until both runs complete.
## 18-SKU matrix closure and frozen verification target (2026-09-29)

- All 18 independent ZU15EG full OOC routes are complete and pass 218.75-MHz
  setup and hold. Evidence is under
  `runs/thermo_sku_matrix/ooc_20260927_111823/`.
- At the fixed 250-MHz, three-seed, fair-RMS numerical gate (EVM <= 3.5% and
  SNDR >= 29.12 dB), only thermo5 with two-tap interpolation qualifies. The
  identity memory-DPD depths have equivalent communication results; DPD1 is
  selected because it has the lowest implemented cost and the largest timing
  margin: worst EVM 3.2739%, worst SNDR 29.6988 dB, filtered ACLR -30.391 dBc,
  zero raw-word mismatches, WNS/WHS +0.316/+0.027 ns, 39,512 LUT, 50,181 FF,
  6.5 BRAM, and 496 DSP.
- `thermo5 / INTERP_TAPS=2 / DPD_MAX_TAPS=1 / DPD_ACTIVE_TAPS=1` is frozen as
  the UVM and static-analysis target. Next actions are a real UVM regression,
  formal lint/CDC/RDC, and mapped 28-nm DC reports. No SpyGlass or ASIC
  signoff is claimed until those reports exist.
- The two-clock thermo5 UVM smoke is integrated into the existing
  `dv/uvm/{agent,env,tests,tb,sim}/` tree and shared Makefile as a separate DUT target;
  the older `dsm_ip_axi_top` tests remain available.
  MATLAB generated 32 source beats / 56 core words with legal frame starts
  and four independent 64-bit plane references. The user restarted the local
  Synopsys license service on 2026-10-01; VCS reached HDL compilation and the
  six-case UVM regression now passes. Directed seed-2 random-stall XSim,
  frozen 2-tap/DPD1 core XSim, and MATLAB P0 7/7 also pass.
- Thermo5 UVM corner suite now includes reset/replay, FIFO-full/backpressure,
  FIFO-empty/underflow, illegal frame-start assertion, and sampled functional
  coverage with per-test event gates. VCS V-2023.12-SP1 completed the full
  `thermo5-vcs-regression`: normal 56-word bit-true with PA stalls; FIFO full
  and backpressure/recovery with 56 bit-true words; four-beat FIFO starvation
  with seven bit-true words followed by expected underflow; midstream reset
  after 24 source beats followed by a fresh 32-beat/56-word bit-true replay;
  five additional resets at CDC residuals 2/4/6/10/12 followed by bit-true
  replay; and the expected 56-sample frame-alignment assertion plus sticky error.
  Each UVM test has zero UVM error/fatal; the illegal-frame case is an
  intentional RTL assertion, not a clean positive test. URG merged all six
  test VDBs with the compiled design VDB: functional groups 100%, overall
  87.30%, DUT hierarchy 86.76%, and CDC FSM 100% (7/7 states, 12/12
  transitions). Remaining condition/branch/toggle holes require triage;
  neither all-config coverage nor XPM FIFO UVM signoff is
  claimed. A finite source may assert sticky underflow only after its final
  beat while pipeline output drains; normal tests reject earlier starvation.
- A directed full-chain XSim reproduced a temporal-pipeline data mismatch under
  PA-ready stalls. The TID pipeline now holds payload, valid, and recursive
  state together while its raw-word boundary is blocked; the CDC stability
  assertion checks the cycle following a stall. The 32-source-beat/56-output-
  word four-plane test now passes with continuous ready and randomized stalls.
  Three randomized-ready XSim seeds (1/2/3) pass with 8/35/20 stalled cycles;
  P0 XSim 7/7 and IP smoke 5/5 pass after the RTL change. A fresh full routed
  OOC routed timing under `runs/uvm_thermo5_i2_d1/ooc_stallfix_retry1/`
  reports WNS +0.346 ns and WHS +0.026 ns at 218.75 MHz, with 39,512 LUT,
  50,181 FF, 6.5 BRAM, and 496 DSP. The final Tcl exited nonzero only after
  writing the routed reports and summary because of a power-provenance string
  expression; that formatting line has been fixed but not rerun end-to-end.

## Vivado runtime audit (2026-09-24)

- A minimal Vivado 2024.1 batch smoke (`puts [version -short]; exit`) exits
  with Windows status `-1073741790` and an empty log. The LP RTL diagnostic
  fails identically before producing any Vivado output. This proves the current
  host Vivado runtime is crashing before project parsing/synthesis; no LP RTL
  timing conclusion can be drawn from these attempts.
