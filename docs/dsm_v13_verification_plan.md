# DSM V1.3 Multi-SKU Verification Plan

## Execution model

Use `make -C dv/uvm/sim dsm-v13-multi-sku-regression DSM_V13_OUT=<unique-run-dir>`
for the reproducible directed matrix. Select exactly one architecture at
elaboration with `dsm_v13_multi_sku_uvm_tb.DSM_ARCH`: 1=EF1, 2=EF2, 3=MASH
1-1. Legacy EF1/EF2 tops and targets remain available. The MASH source import
target checks out and hashes the exact source revision into the ignored run
directory; it does not modify canonical Product RTL.

The original default `thermo5_sku_uvm_tb` top and `thermo5-vcs-regression`
entrypoint were freshly rebuilt and passed for EF1 and EF2. MASH currently has
a separate block-level agent/checker because its wrapper does not implement
Thermo5 interfaces. The shared compile-time selector/regression infrastructure
is integrated, while a single reusable class-based UVM environment spanning
MASH and Thermo5 remains **OPEN** until an approved Product interface exists.

## Required test matrix

| Test area | EF1 / EF2 current Product Top | MASH 1-1 current block boundary |
|---|---|---|
| Smoke / zero / positive and negative constants | Existing bit-true vectors | Directed vectors and independent fixed model |
| Maximum/minimum, impulse, step, quantizer boundary | Covered in existing vector/test infrastructure where specified | Explicitly generated and checked |
| Continuous streaming / bubbles | Existing product sequences | 10 independently seeded directed-plus-random streams |
| FIFO full/empty/wrap/backpressure | Directed FIFO full and seven-word empty tests; product UVM observes four PA words | Not applicable: no FIFO in imported wrapper |
| PA stall / partial PA stall | Existing bubble/backpressure tests and bit-true replay | Not applicable: no PA ready interface |
| Reset idle/streaming/stall/partial frame/epoch | Reset and five-position residual reset sweep; 56-word replay | Directed reset/restart and state-reset model checks; no product epoch metadata |
| AXI-Lite configuration | Separate EF1 and EF2 AXI-Lite positive tests | Not applicable: no AXI-Lite wrapper exists |
| Internal state/cancellation | Thermo5 selected architecture state and existing checks | Stage output, signed combiner, bubbles, reset, valid alignment assertions/checker |
| PA weighting/serializer order | All four 64-bit PA planes checked by independent expected vectors | Open: no MASH PA/serializer contract |

## Constrained random budget and measured use

The requested smoke suggestion was 10 seeds x 1,000 beats. The implemented
campaign uses seeds 130011 through 130020, each with 3,940 clock/vector rows
including directed cases plus 1,024 random samples, random valid gaps, reset,
and 2,048 rows of long state evolution. Across these seeds, 39,400 rows
contained 35,432 accepted MASH transactions, 3,968 invalid rows, and 40 reset
markers. This is a block smoke campaign, not the requested 100-seed standard
or 20-seed stress budget. EF1/EF2 used fixed directed seeds for the current
reproducible run; no product-level constrained random budget is claimed.

## Assertions and non-vacuity

The MASH interface includes reset-valid clearing, output-valid alignment to
the previous input valid, output payload hold following an invalid sample, a
reset-to-valid cover, and valid/bubble/valid cover. URG reports three
successful MASH assertions and both cover properties matched with zero
assertion failures. Two additional uncovered/no-attempt URG entries are UVM
register-package assertions, not MASH assertions. UVM scoreboard coverage
records checked transaction count, bubbles, reset cycles, and combined-level
histogram. No assertion result substitutes for Formal or CDC/RDC.

## Failure reproduction

Each vector generator records seed, parameters, stimulus/output SHA-256, and
row counts in `manifest.json`. To reproduce a MASH seed after building:

```sh
make -C dv/uvm/sim dsm-v13-mash11-vcs DSM_V13_OUT=runs/repro/mash11
runs/repro/mash11/mash11/simv \
  +UVM_TESTNAME=mash11_vector_test \
  +MASH_VECTORS=runs/dsm_v13_round1/round1_final/mash11/vectors_seed130011 \
  +ntb_random_seed=130011 -l runs/repro/mash11/seed130011.log
```

There were no remaining failing seeds. Early failures and fixes are described
in the baseline audit; they are excluded from passing counts.

## Completion gates

Do not sign off MASH Product integration until the MASH Product interface,
latency, PA/lane mapping, AXI-Lite configuration and runtime reset contract are
approved and tested at Product Top. Coverage targets remain per SKU and
unmerged. Code/functional coverage holes remain open unless an exact
reachability proof or approved disposition is recorded. Formal, CDC/RDC,
physical timing/PPA, standard ACLR, calibrated RF power and hardware BER are
separate gates.
