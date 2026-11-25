# DSM V1.3 Round 1 — Multi-SKU UVM and MASH 1-1 Results

Date: 2026-11-25
Branch: `work/dsm-v13-mash-uvm-round1`
Baseline: `c8fe4299e4d87ead3daca41800ce6c331e6c0ea6`

## Executive status

This round adds a reproducible multi-SKU UVM compile selector and performs
fresh EF1, EF2, MASH 1-1 block, and AXI-Lite configuration runs. Product RTL
was not modified. EF1/EF2 Product regressions and the imported legacy MASH
block regression passed. The independent Python reference suite passed 72/72.
The MASH interface is not yet a Thermo5 Product SKU: a product top, AXIS and
AXI-Lite contracts, FIFO behavior, lane/PA mapping, serializer behavior, and
end-to-end latency are undefined. That integration is **OPEN**.

| Gate | Result | Evidence / limit |
|---|---|---|
| Isolated DV worktree and source snapshot | PASS | Branch `work/dsm-v13-mash-uvm-round1`, baseline SHA above; CDC/RDC worktree untouched |
| EF1 Product directed UVM | PASS | Seven core test invocations, 56-word four-plane bit-true replays, reset/stall/FIFO tests; zero UVM warning/error/fatal |
| EF2 Product directed UVM | PASS | Same directed matrix and independent EF2 parameters; zero UVM warning/error/fatal |
| EF1 / EF2 AXI-Lite configuration | PASS | Separate builds; illegal tap rejected, frame-boundary mailbox and legal identity config checked, four-plane replay passed |
| MASH 1-1 block UVM | PASS | 3,551/3,551 expected outputs checked at seed 130011; 10-seed campaign also passed |
| Python reference suite | PASS | 72/72 tests |
| Product Top MASH integration | OPEN | Legacy block wrapper has no AXIS, AXI-Lite, FIFO, product metadata, PA planes, or serializer |
| Code coverage closure | OPEN | Hardware-only DUT subtree metrics and functional covergroups are split in `dsm_v13_hardware_coverage.md`; exact records are in the coverage CSVs |
| Formal / CDC/RDC / synthesis / PPA | NOT RUN | Out of this DV round; no replacement signoff claim |
| Standard RF metrics / hardware BER | NOT RUN | No calibrated channel mask/receiver or MASH product PA path |

## What changed

- Added a compile-time selected UVM top supporting EF1 (`DSM_ARCH=1`), EF2
  (`DSM_ARCH=2`), and a MASH 1-1 block experiment (`DSM_ARCH=3`). A single
  selected DUT is elaborated per simulation.
- Added independent floating and fixed-point MASH models, transaction/vector
  generation, UVM scoreboard adapter, reset/valid/hold assertions, directed
  coverage counters, and captured MASH output trace. MASH RTL was imported
  byte-for-byte from source revision
  `8d260dacbece071bc3f53546fd2b2ee3d08c64cb` into ignored run output; canonical
  Product RTL is unchanged.
- Added optional source AXIS and four-plane PA trace files to the existing
  Thermo5 monitors and a Python analyzer for captured Product outputs.
- Fixed two verification-oracle issues found during baseline runs: EF1 reset
  hierarchy assumptions and a full-frame oracle used by the short FIFO-empty
  test. Neither was a Product RTL bug.
- Added Make targets for per-SKU runs, MASH source preparation, MASH smoke
  seeds, and the combined multi-SKU regression.

## Fresh execution

The final selector regression ran under VCS V-2023.12-SP1_Full64 and URG
V-2023.12-SP1 on Rocky/WSL2 Linux (kernel `6.6.87.2-microsoft-standard-WSL2`),
Python 3.12.13, NumPy 2.5.5. The main log reports compile-time `DSM_ARCH`
assignments for 1, 2, and 3 and is SHA-256 indexed in the evidence manifest.
The original default `thermo5_sku_uvm_tb` top and `thermo5-vcs-regression`
target were additionally rebuilt and rerun for EF1 and EF2; both legacy
entrypoints passed after the selector changes.

Per Thermo5 Product architecture, the current core matrix ran bit-true,
bubble/backpressure, FIFO-full boundary, seven-word FIFO-empty, reset, five
residual reset sweep, and expected-negative frame protocol tests. The separate
AXI-Lite build ran the configuration test. Core tests produced 56 output words
with all four 64-bit PA planes compared. AXI-Lite tests checked the mailbox's
frame-boundary apply, rejection of illegal tap selection, legal identity
configuration, and bit-true outputs. All positive invocations completed with
zero UVM warning/error/fatal counts. The negative protocol scenario observed
its expected sticky error and reset recovery.

The MASH directed run checked 3,551 outputs against 3,551 independent expected
records. It exercised zero, positive and negative constants, maximum/minimum,
impulse, step, quantizer boundary, valid bubbles, reset/restart, random signed
samples, and long state evolution. The ten seeds 130011–130020 each executed
3,940 vector rows: 39,400 rows, 35,432 accepted transactions, 3,968 invalid
rows, and 40 reset markers total. Each seed passed with zero UVM warnings,
errors, or fatals. These streams are directed-plus-random block smoke runs,
not the requested 100-seed standard or 20-seed stress campaign.

Python `unittest` passed 72/72 in 28.9 seconds. An initial attempt to run it
from the repository root failed because the existing test suite imports modules
relative to `dv/uvm/refmodel/python`; the suite was rerun successfully from that
directory. The failed invocation is not counted as a test failure.

## Product capture and signal analysis

Fresh EF1 and EF2 Product-top captures each accepted 32 source AXIS beats,
produced 56 PA words, and matched every bit of all four 64-bit planes. They
reconstructed to 3,584 serialized PA samples / 1,792 complex output samples.
The coherent input used 448 complex samples, tone bin 7, amplitude 3277, frame
starts at core words 1/15/36 and gains 16384/14336/12288 in Q14. Source rate
was 125 MHz. Under the captured PA-ready stress, measured first-source to
first-PA latency was 145.746 ns for EF1 and 141.174 ns for EF2; captured PA-word
rates were 164.791 MHz and 148.515 MHz respectively. These are single-run
simulation observations, not guaranteed timing or throughput specifications.

The raw captured PA-plane sequence was analyzed and PSD data were saved. The
reported EF1/EF2 bit-true status is PASS. Calibrated EVM, SNR, SNDR, ACLR,
transmit power, channel-mask compliance, and BER are **NOT RUN** because no
calibrated RF sample rate, channel mask, receiver model, or hardware receive
chain was part of this test contract. MASH has only the legacy block combined
level output and no PA/serializer mapping; its numeric spectrum/EVM diagnostics
are exploratory block-level screens and are not RF performance results.

## MASH integration contract still open

The block experiment fixes `W=16`, `ACC_W=18`, `IN_SHIFT=0`, and saturation to
match the legacy P0 model invocation. The RTL default `ACC_W` is 28. The core
uses asymmetric signed rails `+32767/-32767`, two cascaded first-order error
states, delayed first-stage error feeding stage 2, and a delayed cancellation
combiner. It advances on every `in_valid`; there is no `ready`. The wrapper
provides two stage bits and a signed 3-bit combined level, not four product PA
planes.

Static comparison with MATLAB source found a possible one-accepted-sample
alignment difference: MATLAB stores the current combiner output in a model
register and returns that prior value, while the legacy wrapper registers the
current combinational combiner value alongside registered valid. MATLAB was
not executable here and no product SKU latency contract exists. The question
is **OPEN**; no Product RTL behavior was changed to force agreement.

The expanded interface, numeric, frame, lane, PA, AXI-Lite, FIFO, reset epoch,
latency, and verification requirements are recorded in
`docs/dsm_v13_sku_contract.md`.

## Disposition

No failed seed remains. No product behavior, latency, or reset state was
changed. EF1/EF2 directed UVM and the current MASH block-level UVM are PASS for
their stated boundaries. MASH Product SKU acceptance, Formal/CDC/RDC, requested
coverage closure thresholds, longer random budgets, standard RF performance,
and hardware BER remain OPEN or NOT RUN as listed in the machine evidence.

Raw logs remain in ignored `runs/dsm_v13_round1/round1_final/` and captured
signal traces and analysis remain in ignored `runs/dsm_v13_round1/perf_final/`.
Their SHA-256 digests, source digests, and tool versions are indexed in
`docs/verification/data/dsm-v13-round1/`.
The coverage report separates full compile URG dashboards (including
UVM/testbench objects) from hardware-only DUT instance-subtree code coverage;
see `docs/dsm_v13_hardware_coverage.md`.
