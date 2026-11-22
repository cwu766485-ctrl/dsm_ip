# Thermo5 Compile-Time EF1/MASH Timing and CDC Closure Snapshot

Date: 2026-11-22

Branch: `work/thermo5-compiletime-timing`

Source HEAD: `16e0605dede359b83ee371319eba4e88d5d9bca0`

## Result summary

| Gate | Status | Evidence / limitation |
|---|---|---|
| EF1 compile-time OOC routed setup/hold | PASS | WNS +0.025 ns, WHS +0.026 ns, TNS/THS 0. |
| MASH 1-1 compile-time OOC routed setup/hold | PASS | WNS +0.108 ns, WHS +0.015 ns, TNS/THS 0. |
| Requested +0.15 ns setup reserve | OPEN | Neither current candidate reaches +0.15 ns. |
| CDC structural review by Vivado | PASS with warnings | Current reports classify every crossing Safe; mailbox and Gray-pointer findings remain warnings with explicit data bounds. |
| SpyGlass RDC disposition | BLOCKED_LICENSE | Current exact-source run aborted before analysis because the `checker 2023.12` feature was unavailable. No waiver was added. |
| Parent/board timing and CDC | NOT_RUN | OOC ports lack parent clock-source and pin-placement constraints. |
| Full-top Formal, UVM, long-stream and RF signoff | NOT_RUN | The directed tests below are limited smoke regressions. |

These results close the current OOC 218.75 MHz setup/hold gate for the two static configurations. They do not establish a DE Release Candidate or board-level VCU118 signoff.

## Why the earlier timing looked much worse

The earlier large negative slack was a different RTL/elaboration and constraint snapshot. Its critical path crossed the unpipelined centered-cubic interpolation and FIFO input cone. A path took about 7.3 ns against a 4.571 ns Core period, with 24 logic levels and seven CARRY8 cells. The wide replicated lane buses caused the same cone to appear at thousands of endpoints, so the very negative TNS was a repeated path family rather than thousands of unrelated defects.

The two-stage centered-cubic pipeline ECO, already present in this branch from commit `aad03a2` (source change `cc2c3ed`), broke that long combinational cone while preserving its arithmetic and metadata contract. The old same-path comparison was approximately 7.29 ns to 3.94 ns, with +0.249 ns in its own placement/elaboration. That historical number is not directly comparable to this compile-time Product Top. In the current routed builds the cubic cone is no longer critical: the limiting path moved into the DPD DSP cascade and carry chain.

The earlier table with EF1 −0.532 ns and MASH −0.547 ns refers to a different OOC candidate/run scope; it is not the current route summarized below. Preserve those results with their original run, and use the current common-reset compile-time routes for this candidate.

## Current routed timing and resources

Tool: Vivado 2026.1 (win64), build 6511674, device `xcvu9p-flga2104-2L-e`. The timing model uses `core_clk=4.571428571 ns`, `s_axis_aclk=8 ns`, `s_axil_aclk=10 ns`, and provisional 0.2 ns input/output boundary budgets. The three clocks are modeled asynchronous; there is no common phase relationship in the modeled interaction window.

| Static configuration / routed implementation | LUT | FF | DSP48E2 | BRAM tiles | CARRY8 | Setup WNS / TNS (ns) | Hold WHS / THS (ns) | Vectorless power |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| EF1, default placement/route | 50,182 | 53,469 | 496 | 6.5 | 4,777 | +0.025 / 0 | +0.026 / 0 | 4.986 W, Medium |
| MASH 1-1, default placement/route | 37,482 | 49,287 | 496 | 6.5 | 3,391 | +0.108 / 0 | +0.015 / 0 | 4.447 W, Medium |

The EF1 worst Core path is `g_lane[6].u_dpd/r4_full_s2[0]` DSP48E2 clock to `g_lane[6].u_dpd/p_49_out__0` DSP48E2 `B[17]`. Data delay is 4.231 ns (2.625 ns cell, 1.606 ns route), 12 logic levels including four CARRY8, with −0.017 ns clock skew. The MASH worst path is the equivalent DPD cascade in lane 11 to `B[15]`: 4.162 ns (2.705 ns cell, 1.457 ns route), 12 levels/four CARRY8 and −0.017 ns skew.

Both are real same-Core-clock paths. No CDC exception is used to hide either path. The remaining difference in WNS is 83 ps; both have small positive margin and meet the zero-slack gate, while both miss the preferred +0.15 ns engineering reserve.

### Physical-only timing trials

All trials started from preserved DCPs and changed implementation strategy only; RTL, XDC, part, and clock periods were unchanged.

| Candidate | Method | Routed WNS/WHS (ns) | Outcome |
|---|---|---:|---|
| EF1 default | Existing full route | +0.025 / +0.026 | Baseline retained |
| EF1 placed checkpoint | `phys_opt_design -directive AggressiveExplore` then route | +0.025 / +0.026 | No change |
| EF1 placed checkpoint | `route_design -directive Explore` | +0.025 / +0.026 | No change |
| EF1 synthesized checkpoint | `place_design -directive Explore`, physical optimization, route Explore | +0.025 / +0.026 | No change |
| MASH placed checkpoint | `route_design -directive Explore` | +0.108 / +0.015 | No change |

The alternative directives completed routing and produced routed DCPs. Since none improved timing, the default implementation remains the reference. A further meaningful gain likely needs an RTL timing change in the DPD DSP/carry arithmetic; it must preserve bit-true behavior and latency/II and should be attempted only with a focused regression.

## CDC/reset disposition

The compile-time Product Top uses one common asynchronous-assert reset input and a local synchronized deassertion in AXI-Lite, AXI-Stream, and Core. The compile-time XPM FIFO is configured for the common reset epoch. In-flight configuration and stream state are aborted at that epoch boundary. Runtime Top and its legacy independent-reset behavior are not changed by this snapshot.

Vivado `report_cdc` for EF1 reports 125 Safe, 0 Unsafe, 0 Unknown endpoints; MASH reports 131 Safe, 0 Unsafe, 0 Unknown. Findings still appear as CDC warnings because the clocks are asynchronous:

- AXI-Lite to Core bundled configuration mailbox: 101 endpoints, bounded by datapath-only max-delay and bus-skew; request/acknowledge holds the source bundle stable until acknowledgment.
- AXI-Stream to Core asynchronous FIFO/pointers: 13 endpoints, bounded and classified Safe.
- Core to AXI-Lite synchronizers: four endpoints, targeted first-stage false paths only.
- Core to AXI-Stream FIFO reset/pointer structures: six endpoints, bounded; common reset epoch and local reset release synchronizers are part of the contract.
- The remaining AXI-Lite to AXI-Stream item is a status synchronization path.

The only false paths are scoped to reset synchronizer asynchronous CLR pins and validated first-stage D pins of single-bit synchronizers. Mailbox data and Gray-pointer buses are not false-pathed. There is no blanket asynchronous clock-group exception. The exact endpoint list and constraints are in the routed CDC, exception, clock-interaction, and bus-skew reports linked below.

Current compile-time reset output findings from an earlier independent-reset candidate do not apply to this common-reset source. The old 17,895-row / 86-group SpyGlass RDC report came from a different Runtime/Generic-FIFO/independent-reset hierarchy and cannot disposition this source. The current exact-source SpyGlass attempt is BLOCKED_LICENSE; therefore current SpyGlass RDC closure remains OPEN. No mass waivers were created.

## Functional evidence and limits

The current-source XSim XPM-backed EF1 and MASH smoke tests pass at seed 610216 and compare 56 PA words per selected architecture against the frozen bit-true reference. Evidence is preserved under:

- `runs/de_timing_20261122/compiletime_arch0_common_epoch03/`
- `runs/de_timing_20261122/compiletime_arch2_common_epoch03/`

These are limited directed runs. They do not cover long randomized backpressure, a complete UVM regression, full-top Formal, sustained live GTY output, or physical RF EVM/ACLR. Digital OOC timing and these smoke results must not be reported as board-level signoff.

## Evidence locations and hashes

| Artifact | SHA-256 |
|---|---|
| EF1 default routed DCP, `runs/de_timing_20261122/ef1_common_epoch03/routed.dcp` | `8d2463d9524fc40adf328d65599fb747e0a6db23c4818c0e8eea33936b010b84` |
| EF1 route Explore DCP, `runs/de_timing_20261122/ef1_common_epoch03_route_explore/routed.dcp` | `4733c3322fcb0ff220fe1943e7637fe71354c9c9c6498cdb5b84ab9b46ee12b8` |
| EF1 placement + route Explore DCP, `runs/de_timing_20261122/ef1_common_epoch03_place_explore/routed.dcp` | `b71912440fe78d87fd4f3a197ab94a8d76d8d1ede17bfee270aa8de85bfd2452` |
| MASH default routed DCP, `runs/de_timing_20261122/mash_common_epoch03/routed.dcp` | `58be55b528ad9bcda4830a8c0f043a4ea4f4aa14c651f4b9a879672f1d65e827` |
| MASH route Explore DCP, `runs/de_timing_20261122/mash_common_epoch03_route_explore/routed.dcp` | `6be6ed8cce05486f7cf3ffac5da71f5f69e7a7c898fb7bfb3ca840b54b25bf18` |

Primary timing artifacts are the corresponding `routed_timing_summary.rpt`, `core_setup_worst20.rpt`, `hold_worst20.rpt`, `routed_cdc.rpt`, `routed_cdc_details.rpt`, `routed_exceptions.rpt`, `routed_clock_interaction.rpt`, `routed_bus_skew.rpt`, and `routed_utilization.rpt` in each run directory. The full SpyGlass license failure log is at `runs/de_timing_20261122/spyglass_ef1_cdc/console.log`.

Relevant source hashes at report time:

```text
6fe3de2dc518d7c923aa52935190c06b8829bfc0fb8a9500de1256c54fc3c433  rtl/interp/dsm_interp_x2_centered_cubic_vector.sv
610b3c9fa4f3820c985342ac77fdf6fecab0962809ea43311f7e6d9765997f3f  rtl/tx_bandpass_if/tid32_thermo5_compiletime_tx.sv
f68c45609613773b62fe83d55680ecc18141b465b499c0546a5977d770b4f71f  rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv
6c264382fd971eecd7b8aaec912cb9758d65c3c869c5920efddcdf36d37badf6  rtl/axis/dsm_xpm_async_fifo.sv
dc6a1943eb338e0bafaf23a97f752e886406ddb533ab251760f999983a6d85b4  rtl/axis/dsm_axis14_to_core8_cdc.sv
2b55592d4c7f6d74a1d1aaf3f30db4ae685d1634a854b96d69bcba46d99dba5d  research/vcu118_arch/run_compiletime_ppa.tcl
3108ee723cc0549428573234399ffec3d4e5588d03b0ae2ef8a5933b17df05ee  research/vcu118_arch/compiletime_timing_budget.xdc
84bfa1507572d5ee0c0f83f12021e4e76bbf02a39886587b534573ac8b399c2d  research/vcu118_arch/compiletime_product.sgdc
1dd57b4583c48e2eaca07cb184851b8831328b2daa9d5f9ff04fc4c45bcd0e44  research/vcu118_arch/place_explore_from_synth.tcl
```

## Reproduction

Run from the repository root with Vivado 2026.1. Use a new, nonexistent output directory for every command; the Tcl scripts reject overwrites.

```text
vivado -mode batch -source research/vcu118_arch/run_compiletime_ppa.tcl -tclargs 0 <new-ef1-out> 1
vivado -mode batch -source research/vcu118_arch/run_compiletime_ppa.tcl -tclargs 2 <new-mash-out> 1
vivado -mode batch -source research/vcu118_arch/place_explore_from_synth.tcl -tclargs <ef1-synthesized.dcp> <new-ef1-explore-out>
vivado -mode batch -source research/vcu118_arch/route_explore_from_placed.tcl -tclargs <mash-placed.dcp> <new-mash-route-explore-out>
```

Do not reuse an existing output directory. For the already completed trials, use the preserved DCPs and reports above rather than rerunning them.
