# Full-AXI Finalist ASIC PPA Report

## Decision

**Advance I0+D1 LPDSM2 (`ALGORITHM=1`) to the next verification stage.**
It is the most robust full-top PPA choice, rather than the narrowly lowest
number in just one library: it is within 0.57% of the lowest 28 nm cell area
and 0.39% of the lowest 28 nm estimated total power; it is within 0.32% and
0.21%, respectively, of the lowest 40 nm values.  It also preserves the
one-bit RF-output contract and has the largest 100 MHz timing margin in the
previous routed-FPGA finalist comparison.  The earlier common-stimulus
behavioural matrix identifies it as the best one-bit quality point.

This is a recommendation for continued verification, not an ASIC signoff or a
claim that the other three algorithms are functionally inferior.  In the
full-AXI integration the common Memory-Poly DPD and interpolation logic
dominates the result, so the four DSM alternatives differ by less than 1% in
the measured pre-layout metrics.

## Scope and Frozen Configuration

This report records eight successful Design Compiler (DC) standard-cell,
pre-layout syntheses: four finalists at 28 nm and 40 nm.  Every run elaborates
the complete `rtl/axi/dsm_ip_axi_top.v`, including AXI-Lite, AXI-Stream skid
buffer, x32 interpolation, Memory-Poly DPD frontend, observer/status logic,
DSM, and fixed Fs/4 DUC.  This is not an isolated DSM-core measurement.

Common elaborated parameters:

| Function | Frozen setting |
|---|---|
| Interpolation | I0 x32, `INTERP_MODE=4`, `INTERP_IMPL=0` |
| DPD | Memory-Poly order 5, four taps, `ENABLE_DPD_MEMORY=1` |
| Pruned DPD branches | `ENABLE_DPD_POLY=0`, `ENABLE_DPD_LUT=0` |
| DUC | fixed Fs/4, `DUC_MODE=0` |
| Clock | `aclk`, 10.0 ns (100 MHz) |
| Clock uncertainty | setup 0.10 ns; hold 0.02 ns |
| I/O timing | 0.20 ns input and output delay |
| Reset | asynchronous `aresetn` false path |
| Compile | `compile_ultra`, then incremental hold repair; four DC cores |

| Case | Algorithm | DSM output | Intended role |
|---|---:|---:|---|
| I0+D0 EFDSM | 2 | 1 bit | Baseline |
| I0+D1 LPDSM2 | 1 | 1 bit | Balanced candidate |
| I0+D3 MASH11 | 4 | 3 bit | Native multilevel reference |
| I0+D5 multibit EFDSM | 9 | 4 bit | DAC/DPA-oriented candidate |

## Libraries and Method Boundary

| Node | DC target library | Operating condition reported by DC |
|---|---|---|
| 28 nm | `tcbn28hpcplusbwp7t40p140tt0p9v25c.db` | `tt0p9v25c`, 0.9 V |
| 40 nm | `tcbn40lpbwp12t40m1ptc.db` | `NCCOM`, 1.1 V |

The eight-run matrix completed with `EXIT=0`.  The immutable run evidence is
under `syn/reports/finalists_asic_dc_full_axi_20260730_0145/`; each case has
QoR, area, setup, hold, design-check, timing-check, constraints, reference,
power, synthesized Verilog, and DDC reports.

This is **standard-cell pre-layout synthesis PPA**.  It has no floorplan,
clock-tree synthesis, placed/routed parasitics, extracted RC, IO/SRAM/DFT
implementation, activity annotation, or multi-corner signoff.  The 28 nm RVT
and 40 nm LP libraries also differ in library family, voltage, and operating
condition; their absolute results are not a process-scaling experiment.  Rank
finalists only within a node, and use the cross-node agreement only as a
robustness check.

## Measured PPA

Cell area is reported in the library's cell-area unit (normally square
micrometres for these libraries).  Power is DC's low-effort, zero-delay
propagated estimate at 100 MHz; `Total` below is dynamic plus leakage.

### 28 nm RVT TT, 0.9 V, 25 C

| Finalist | Cell area | Dynamic (mW) | Leakage (mW) | Total (mW) | Critical path (ns) | Setup slack (ns) | Hold slack (ns) |
|---|---:|---:|---:|---:|---:|---:|---:|
| I0+D0 EFDSM | 127,311.51 | 8.1786 | 0.0755 | 8.2541 | 4.45 | +5.42 | +0.03 |
| I0+D1 LPDSM2 | 126,966.74 | 8.1805 | 0.0748 | 8.2553 | 4.45 | +5.42 | +0.03 |
| I0+D3 MASH11 | **126,247.23** | **8.1500** | **0.0733** | **8.2233** | 4.45 | +5.42 | +0.03 |
| I0+D5 multibit EFDSM | 127,028.48 | 8.1709 | 0.0749 | 8.2458 | 4.45 | **+5.43** | +0.03 |

Within this library MASH11 has the smallest cell area and estimated power.  Its
advantage over LPDSM2 is only 0.57% in area and 0.39% in total estimated
power; all four meet the 100 MHz setup target with effectively the same
critical path.

### 40 nm LP, NCCOM, 1.1 V

| Finalist | Cell area | Dynamic (mW) | Leakage (mW) | Total (mW) | Critical path (ns) | Setup slack (ns) | Hold slack (ns) |
|---|---:|---:|---:|---:|---:|---:|---:|
| I0+D0 EFDSM | 412,112.97 | 18.4486 | 0.0652 | 18.5138 | 6.76 | +2.93 | +0.06 |
| I0+D1 LPDSM2 | 409,516.60 | 18.3651 | 0.0644 | 18.4295 | 6.76 | +2.93 | +0.06 |
| I0+D3 MASH11 | 411,083.97 | 18.3806 | 0.0646 | 18.4452 | 6.76 | +2.93 | +0.06 |
| I0+D5 multibit EFDSM | **408,194.54** | **18.3279** | **0.0639** | **18.3918** | 6.76 | +2.93 | +0.06 |

Within this library multibit EFDSM is smallest in both area and the estimated
power.  LPDSM2 is 0.32% larger and 0.21% higher in estimated total power;
timing is identical at this report precision.

## Interpretation and Recommendation

The different per-node minima make a single algorithm selected solely from
absolute cell area or unannotated power non-robust.  The shared full-top
datapath is the dominant cost: for example, the 28 nm DPD frontend occupies
44.0% of the D0 total cell area, and its Memory-Poly block alone occupies
40.1%.  The reported critical path is likewise in shared logic, producing the
same path length across all four DSM choices at each node.

LPDSM2 is therefore the best next verification target:

- It is consistently near the PPA floor in both independent standard-cell
  libraries, with no material timing penalty.
- It retains the one-bit output required by the frozen switched-RF interface;
  MASH11 and multibit EFDSM intentionally change that interface contract.
- It has the best routed-FPGA timing margin among the four full-top finalists
  (+1.400 ns at 100 MHz) and the best one-bit point in the previous behavioural
  comparison.  Those evidence sources complement, but do not replace, this DC
  study.

Retain D0 as the compatibility baseline, D3 as the native-three-bit reference,
and D5 for DAC/DPA work.  D3/D5 should not be discarded: their pre-layout PPA
is competitive, but they require output-interface and reconstruction-path
verification appropriate to their multibit outputs.

## Report Quality and Remaining Work

All cases have `check_design` reports with no DC errors and have positive
reported setup and hold slacks.  However, the following prevent treating these
results as closure or signoff:

- `report_power` warns that primary inputs and sequential outputs lack
  activity annotation.  The dynamic-power values are useful only for this
  same-flow relative comparison; rerun with representative SAIF/VCD activity
  before making an application-power claim.
- `report_constraint -all_violators` reports library default minimum-capacitance
  entries and a default maximum-leakage-power constraint.  These are not setup
  or hold failures, but they must be resolved or waived by the physical-flow
  constraint owner.
- DC uses zero-wireload/segmented wire-load estimation.  There is no physical
  congestion, CTS, RC, IR/EM, DFT, IO, or multi-mode/multi-corner evidence.
- The 28 nm and 40 nm libraries are not matched PVT/library families, so their
  absolute area, power, and timing figures must not be used to claim a node
  scaling factor.

Next, run the existing LPDSM2 full AXI verification set with its frozen
configuration, generate representative stream/DPD activity for SAIF-annotated
power, and take LPDSM2 (plus the D0 baseline if interface comparison is
needed) into a matched-corner physical implementation flow.
