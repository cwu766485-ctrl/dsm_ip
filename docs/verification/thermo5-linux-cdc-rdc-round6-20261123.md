# Thermo5 Linux CDC/RDC Closure — Round 6

**Decision: OPEN.** Round 6 reproduced the EF1/MASH product findings without
waivers, verified the existing 56-word bit-true product tests, and added both a
product-width XPM wrapper reset/epoch phase sweep and an AXI-Lite product reset
sweep. It made a testbench hierarchy correction, but no product RTL or
constraint change. The evidence supports targeted simulation only; it does not
close CDC, RDC, product reset Formal, routed Gray-bus timing, or DE Freeze.

## Baseline and scope

- Branch: `work/thermo5-linux-cdc-rdc`
- Source HEAD: `2901ccd493f259fe2627f985703074d81b5d9ab4`
- Round 5 product RTL baseline: `b9cc9ac`; no `rtl/` or
  `research/vcu118_arch/` changes exist between that baseline and Round 6 HEAD.
- Product builds: compile-time EF1 (`DSM_ARCH=0`) and MASH 1-1
  (`DSM_ARCH=2`), `W=16`, `DPD_MAX_TAPS=1`, centered cubic, XPM FIFO,
  common reset epoch. XPM FIFO elaborates as 466 bits × 16 words,
  `CDC_SYNC_STAGES=2`, FWFT read mode, read latency 0, `USE_ADV_FEATURES=0400`.
- SGDC clocks are 10 ns AXI-Lite, 8 ns AXIS, and 4.571428571 ns core; domains
  remain asynchronous pending parent-system proof. `common_aresetn` is an
  asynchronous common assertion with local synchronized deassertion.
- Tools: VCS V-2023.12-SP1 Full64, SpyGlass V-2023.12-SP1, VC Formal
  V-2023.12-SP2, XPM source from Vivado 2026.1. Environment and exact hashes
  are recorded in the [evidence manifest](data/thermo5-linux-cdc-rdc-round6-20261123/evidence_manifest.json).

## Gate results

| Check | EF1 | MASH | Disposition |
| --- | --- | --- | --- |
| SpyGlass CDC, no waivers | 8 errors, 81 warnings | 8 errors, 83 warnings | OPEN; same 8 error classes and exact IDs as Round 5 |
| SpyGlass structural RDC, no waivers | 4,417 errors, 74 warnings; 93 source-line groups | 5,125 errors, 76 warnings; 94 source-line groups | OPEN; all errors are `Ar_resetcross01` |
| Compile-time XPM product, 56-word UVM bit-true test, seed 610216 | PASS; 0 UVM warnings/errors/fatals | PASS; 0 UVM warnings/errors/fatals | Directed regression only; not full reset/abort signoff |
| 466-bit XPM FIFO reset/epoch phase sweep | 16/16 trials PASS | Shared wrapper configuration; not architecture-specific | PASS for the test scope; not formal CDC closure |
| AXI-Lite product reset sweep, seed 610802 | PASS with two non-fatal compile notices; zero UVM warnings/errors/fatals | XPM, one-tap Identity, EF2, centered cubic; 4 partial-frame and 5 CDC-residual reset cases plus full 56-word replay | PASS for directed reset/replay scope; full reset Formal remains OPEN |
| DPD reset Formal | 2 assertions proven, 3 covers hit | Same DPD block harness | OPEN: one reset setup violation; local lane only |
| Routed XDC endpoint/skew audit | NOT RUN | NOT RUN | OPEN |

The MASH compile emitted one optional-port warning for
`thermo5_mash11_core.u_stage2`. The AXI-Lite reset-sweep compile emitted the
existing unconnected optional wrapper-port warning and VCD interface-dump
notice; its UVM run had zero warnings, errors, or fatals. The full VCS product
regression was not run in Round 6.

## CDC closure matrix and root cause

All 16 Round 6 native IDs match the Round 5 IDs exactly. Their full source and
destination paths, source hashes, configuration, report hashes, and required
closure evidence are in
[`cdc_closure_matrix.csv`](data/thermo5-linux-cdc-rdc-round6-20261123/cdc_closure_matrix.csv).
No finding was waived or suppressed.

| Rule / finding | Per architecture | Assessment | Status |
| --- | ---: | --- | --- |
| `Ac_cdc01a` Gray pointer `src_gray_ff` → first `dest_graysync_ff` stage | 2 | XPM source has registered Gray pointer and `ASYNC_REG` synchronizer stages. SpyGlass Data Hold remains unresolved until routed first-stage endpoint and bus-skew constraints are demonstrated. | OPEN |
| `Ac_cdc01a` XPM reset-level path | 1 | FIFO reset-level synchronizer reports Data Hold failure. Reset assertion/release contract and exact endpoint timing are not closed. | OPEN |
| `Ac_conv02` Gray-to-binary reconvergence | 3 | Binary decode follows synchronizer stages in the XPM source. This is structurally expected, but source inspection alone is not an independent safety proof and SpyGlass reports Gray check failure. | OPEN |
| `Ac_conv04` FWFT extended Gray pointer | 1 | Distinct extended-pointer path; FWFT prefill/count semantics and the exact routed constraint endpoints remain unverified. | OPEN |
| `Reset_sync02` AXIS-local reset → core reset guard stage | 1 | The source-domain synchronized reset drives an asynchronous reset pin on a core-clocked guard stage. This is intentional reset guarding, but the cross-domain reset release contract remains a real item to prove. | OPEN |

The implementation Tcl applies `set_max_delay -datapath_only` and
`set_bus_skew` from XPM Gray source-register clock pins to first destination
stage D pins, bounded by the source clock period. This round inspected the
constraint-generation code, but did not run a fresh routed implementation or
check the final routed endpoint list and measured skew. The Tcl also skips a
source group without a matching destination group, so its successful Tcl
completion alone would not prove that every expected group was constrained.
Do not classify the four XPM Gray findings as vendor-safe exceptions yet.

## RDC root-cause inventory

Round 6 parsed the fresh SpyGlass reports and retained all 9,542 native paths
with source/destination flop, reset, destination clock, source line, native ID,
and the complete `Qualifier not found` message in the compressed
[`rdc_exact_path_inventory.csv.gz`](data/thermo5-linux-cdc-rdc-round6-20261123/rdc_exact_path_inventory.csv.gz).
The source-line rollup is
[`rdc_root_cause_groups.csv`](data/thermo5-linux-cdc-rdc-round6-20261123/rdc_root_cause_groups.csv).
All source and destination flops in these reports are clocked by `core_clk`;
the finding is a reset/qualifier analysis, not a cross-clock data path. That
fact does not prove post-reset payload safety.

| Root-cause family | EF1 groups / paths | MASH groups / paths | Required closure evidence |
| --- | ---: | ---: | --- |
| DPD pipelined data, coefficients, and history | 60 / 3,640 | 60 / 3,640 | Prove current-epoch valid provenance through arithmetic and output consumers, including reset while valid data is in flight. |
| Frame-gain elastic stages | 17 / 183 | 17 / 183 | Prove payload/product registers cannot be consumed without reset-cleared valid/frame metadata, including stalls. |
| Frontend metadata FIFO | 3 / 318 | 3 / 318 | Prove reset count/pointer masking and exact accepted transaction ordering after restart. |
| Compile-time backend metadata FIFO | 1 / 72 | — | Prove reset occupancy/valid masks uninitialized metadata until rewritten. |
| MASH backend payload/metadata FIFO | — | 2 / 780 | Prove reset occupancy/valid masks uninitialized payload and metadata across abort, drain, restart. |
| XPM FIFO internal storage/control | 8 / 110 | 8 / 110 | Prove exact XPM reset/busy/empty/write-enable semantics for this elaborated configuration; no vendor waiver is approved. |
| XPM memory internal storage/output pipeline | 4 / 94 | 4 / 94 | Prove unreset memory/output data is masked until current-epoch valid data is available. |
| **Total** | **93 / 4,417** | **94 / 5,125** | **All groups OPEN.** |

The local DPD harness proves valid provenance for a single DPD lane, not
payload/configuration epoch correctness through the FIFO, frame metadata,
interpolator, DSM, and PA output. No RDC group is approved for waiver, and no
data-path reset ECO was made without evidence of a real leak.

## Reset simulation and Formal

The new standalone test
[`tb_thermo5_xpm_reset_epoch_random.sv`](../../dv/verif/axis/tb_thermo5_xpm_reset_epoch_random.sv)
uses the 466-bit, depth-16 XPM wrapper, asynchronous clock phases, source
bubbles, sink stalls, in-flight reset/abort, stale-word discard, and fresh
epoch ordering checks. It also checks that the source holds VALID/payload and
that the FIFO holds VALID/data while stalled. The reset scenario fills the
16-entry FIFO, attempts a seventeenth write, observes six source-side stall
cycles per reset epoch, then aborts that epoch; the read-side stall count is
recorded for every phase. During review, an initial draft
could withdraw source VALID under backpressure; those first 16 results are
retained locally but explicitly superseded and are not counted. After fixing
the driver and adding both hold checkers, the smoke run checked 261 delivered
words and 63 aborted words over 14 epochs. The corrected 16 phase cases all
passed. Per-trial output, abort, stall counts and raw-log hashes are in
[`xpm_reset_epoch_phase_summary.csv`](data/thermo5-linux-cdc-rdc-round6-20261123/xpm_reset_epoch_phase_summary.csv).
This is a wrapper-level dynamic test with a scoreboard; it is not a full
product reset proof or routed CDC result.

The AXI-Lite product reset test then exercised the actual EF2/Centered-Cubic,
one-tap Identity DPD product wrapper with XPM. It reset after four legal partial
DSP-frame prefixes, reset at CDC residuals 2, 4, 6, 10, and 12, and completed a
56-word post-reset bit-true replay followed by graceful drain. The Unified
Scoreboard reported 56 CDC and PA words, empty queues, 634 samples discarded
across reset epochs, and zero data, metadata, epoch, index, underflow, or
predictor mismatches. The AXI-Lite predictor recorded seven checked write
responses with zero mismatches. Seed 610802 completed with zero UVM warnings,
errors, or fatals. The compile and run logs and accepted-event trace are hashed
in [`axil_reset_sweep_manifest.json`](data/thermo5-linux-cdc-rdc-round6-20261123/axil_reset_sweep_manifest.json).

The first compile attempt exposed twelve stale testbench hierarchical
observation references: the AXI-Lite wrapper elaborates the legacy TID instance
under `g_no_pre_metadata`. The testbench paths were corrected to include that
generate scope, and the same product test was recompiled and passed. The failed
compile log is retained and hashed as a repaired testbench setup failure; it is
not counted as a regression result. This change only fixes verification
observability paths and does not change DUT RTL or test stimulus semantics.

The current `formal_dpd_reset_epoch` harness produced:

| Property | Engine result | Depth | Interpretation |
| --- | --- | ---: | --- |
| `a_epoch_valid` | PROVEN | — | DPD output-valid matches the local 11-stage ghost-valid pipeline. |
| `a_reset_clears` | PROVEN, non-vacuous | — | Local DPD output-valid is cleared by the modeled epoch reset. |
| `c_abort_inflight` | COVERED | 3 | Reset/abort reached with valid work in flight. |
| `c_restart_output` | COVERED | 13 | Post-reset accepted input later produces valid output. |
| `c_stall` | COVERED | 13 | Output valid persists under backpressure. |
| Formal setup check | **FAIL / OPEN** | — | `epoch_valid` and DUT `valid_pipe` resets can remain active after the formal reset save point. |

The proof engine returned local properties, but the setup checker states the
model is incorrect due to one reset violation. Therefore these results are
not a product-level Formal PASS. A separate attempt that constrained the
reset after startup made the reset assertion vacuous and restart/abort covers
unreachable; it is intentionally not counted. No assertions were weakened.

## Product AFIFO status

Round 6 EF1/MASH product builds use the XPM FIFO, so the self-developed
`dsm_async_fifo` was **not** part of these product regressions. Earlier
Round 3 evidence did exercise it: generic FIFO full/reset and skew-epoch
directed tests passed, and Generic EF1/MASH 56-word UVM tests passed. Its
SpyGlass findings and formal limitations remained OPEN in that round. This is
useful block-level evidence, not equivalent XPM-vs-AFIFO cycle behavior,
physical CDC, or product signoff. Do not switch the product to the AFIFO until
the same parameterized product tests, CDC/RDC, reset proof, and timing review
pass for it.

## Reproduction commands

The complete machine-readable source/tool/evidence manifest is
[`evidence_manifest.json`](data/thermo5-linux-cdc-rdc-round6-20261123/evidence_manifest.json);
the exact VCS source list and per-file hashes are in
[`compile_source_manifest.json`](data/thermo5-linux-cdc-rdc-round6-20261123/compile_source_manifest.json).
SpyGlass run directories, original reports, and VCS/VC Formal raw logs remain
under the ignored local `runs/linux_cdc_rdc_round6/` directory and are
identified by SHA-256 in the manifest.

```sh
export VCS_HOME=/path/to/vcs/V-2023.12-SP1
export VIVADO_ROOT=/path/to/Vivado/2026.1
dv/verif/scripts/run_thermo5_xpm_reset_epoch_random.sh

# SpyGlass: run once per architecture and goal with a unique output directory.
export THERMO5_CTIME_ROOT="$PWD" THERMO5_CTIME_ARCH=0
export THERMO5_CTIME_GOAL=cdc/cdc_verify
export THERMO5_CTIME_OUT="$PWD/runs/thermo5_round6_ef1_cdc"
/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin/sg_shell \
  -tcl research/vcu118_arch/run_compiletime_spyglass.tcl
# Repeat with ARCH=2; use rdc/rdc_verify_struct for structural RDC.

# AXI-Lite reset-sweep vector generation and compile/run:
python3.12 dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
  --output-dir runs/linux_cdc_rdc_round6/axil_reset_sweep_frontend_vectors \
  --words 56 --seed 610216 --profile random --interp-mode centered_cubic \
  --tidsm-order 2 --step 5120 --dpd-profile identity
# AXI-Lite product reset sweep, with a new unique output directory per run.
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH VCS_ARCH_OVERRIDE=linux \
make -C dv/uvm/sim thermo5-tx-product-axil-reset-sweep \
  THERMO5_FIFO_IMPL=xpm THERMO5_XPM_ROOT=/path/to/Vivado/2026.1 \
  THERMO5_OUT=$PWD/runs/linux_cdc_rdc_round6/<unique-output> \
  THERMO5_VECTORS=$PWD/runs/linux_cdc_rdc_round6/axil_reset_sweep_frontend_vectors \
  THERMO5_COVERAGE=0 UVM_VERBOSITY=UVM_LOW

# EF1/MASH compile-time test commands and raw logs are bound in the evidence
# manifest and the corresponding per-run source manifests.

export THERMO5_FORMAL_ROOT="$PWD"
export THERMO5_FORMAL_OUT="$PWD/runs/linux_cdc_rdc_round6/formal_dpd_epoch_recheck"
/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vc_static_shell \
  -f research/vcu118_arch/formal_dpd_reset_epoch.tcl
```

## Signoff decision and next actions

- CDC: **OPEN** — all 16 errors remain; no rules were waived or suppressed.
- RDC: **OPEN** — 9,542 native errors are mapped to 187 source-line groups;
  no group has an approved exception or end-to-end proof.
- Reset Formal: **OPEN** — local DPD properties returned results, but setup
  has one reset violation and full product Epoch/PA properties remain unproved.
- Product regression: EF1/MASH 56-word tests, the scoped 16-phase FIFO test,
  and the AXI-Lite reset sweep passed. The complete product reset/abort/STOP
  matrix and cross-configuration regression remain OPEN.
- Physical: **NOT RUN** — no fresh routed Gray endpoint/skew evidence, timing
  signoff, or parent-level clock/reset review was made.
- DE Freeze: **NOT READY**. No merge to `thermo5` is authorized by this report.

Next action is to resolve the reset Formal model and add full-chain
epoch/payload assertions with meaningful covers, then run reset during active
traffic through FIFO drain/restart under independent product scoreboard.
Separately audit XPM first-stage endpoint constraints against a routed netlist
and review every RDC root-cause family before any narrow exception. Preserve
the independent branch until those gates pass.
