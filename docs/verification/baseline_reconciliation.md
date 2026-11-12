# Thermo5 ECO Baseline Reconciliation

Date: 2026-11-12 (Asia/Singapore). Executed against PR #62 draft HEAD
`ac08611af825586dc378041d2568eb7ee1ea563c`, parent
`c3a84fee43630d6155d2b2fe3ebd62d32c68cee0`. The checkout was clean before
execution. PR #62 is an ECO candidate, not an integrated product baseline.

## Source and configuration

PR #62 changes one product RTL file relative to its parent:
`rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv`. The SHA-256
changes from
`d2621fc061bf225bfa04f357a76410b3c9e589016ff70c7d1019dae8970b77a7` to
`e3948584cc905cacc4788e4f85c203e9bf225e17094599357851785d3cfb109a`.
The ECO registers source activity, draining, and ingress-closed status and
replaces the crossed two-bit prefill Gray value with a registered one-bit
predicate. Existing datapath arithmetic and public interfaces are unchanged;
remote status observation can be delayed by one source cycle.

The checked configuration is AXI-Lite, `MAX_TAPS=1`, Generic FIFO depth 16,
W16, centered-cubic x2+x2, EF2 ORDER=2 and STEP=5120. Reset evidence assumes
common assertion followed by local synchronized release. Independent runtime
domain reset is unsupported. PRs #55-#62 remain open; no integrated commit or
independent human approval was present in the reviewed chain.

## Fresh build and coverage

VCS V-2023.12-SP1 recompiled the product from this detached source checkpoint.
The product compile manifest parsed 98 local source files plus the product
filelist and DUT coverage hierarchy; all 100 controlled inputs matched the
clean checkpoint. The source and compile provenance, Design VDB tree hash,
seven legal Test VDB tree hashes, report hashes, and run summaries are in
`data/thermo5-pr62-signoff/run_manifest.json`. The VDBs remain in the ignored
`runs/pr62_signoff_hier/product/` directory on this host.

The compile manifest, Raw summary, per-instance denominators, exact line and
branch inventories, assertion summary, and before/after RTL patch are preserved
under `data/thermo5-pr62-signoff/`. The coverage parser exports exact line gaps
and branch arms; it does not currently export per-toggle bit/direction or
per-condition vector IDs for this smoke report. Those remain required for
Gate 1.

An initial diagnostic run without `-cm_hier` included UVM coverage and is not
used here. The replacement run used
`dv/uvm/sim/thermo5_product_dut_coverage.hier`, ran six legal product tests,
then the nine-epoch reset sweep, and produced a new legal-only Raw URG report
with zero exclusions:

| Metric | Covered / total | Missing |
|---|---:|---:|
| Branch | 436 / 639 (68.23%) | 203 |
| Condition | 585 / 849 (68.90%) | 264 |
| Line | 3,188 / 3,805 (83.78%) | 617 |
| Toggle | 90,592 / 104,480 (86.71%) | 13,888 |
| FSM states | 13 / 13 | 0 |
| FSM transitions | 22 / 22 | 0 |
| **Open code bins** | | **14,972** |

This is a seven-test ECO smoke baseline, not the 594-scenario full-product
baseline. Its denominator and uncovered set must not be compared directly with
the inherited Round 21 set or used for final closure. Old exclusion candidates
were not applied or mapped against this new VDB. No official Exclusion or
counter-scope exception was applied.

## 12,580 vs 12,577

The Round 21 incremental report has 12,580 Raw open bins; the earlier v5
594-test report has 12,577. Their Branch, Line, and Toggle hit counts agree,
but the Condition hit counts differ by three (664 versus 667). The Round 21
coverage artifacts bind to the pre-ECO RTL hash
`d2621fc061bf225bfa04f357a76410b3c9e589016ff70c7d1019dae8970b77a7`; this
reconciliation binds to PR #62's ECO RTL hash above. The reports also use
different documented VDB aggregation paths. No matching full 594-test VDB set
was rebuilt on PR #62, and no exact native Condition IDs for the three-hit
difference were available from a homogeneous comparison.

Therefore the observed difference is exactly three Condition hits at the
metric level, but its bin-level cause is **unreconciled**. It is not attributed
to a particular RTL expression, test, or denominator change. Gate 0 remains
open until the full legal suite is rebuilt at one immutable integrated source
commit, Raw URG is regenerated with the same hierarchy and source manifest,
and the native Condition inventory is diffed by exact bin ID.

## Result

Fresh VCS elaboration/compile, the AXI-Lite product target, reset sweep,
independent reset trace oracle, and legal-only smoke URG completed. This does
not satisfy Gate 0's full regression/VDB requirement or establish a unique
integrated baseline. Do not reuse old `.el` files or claim the old candidate
mapping is valid for this ECO.
