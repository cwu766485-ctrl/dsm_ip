# Thermo5 TX Outstanding-Counter Long-Stream Stress

Date: 2026-11-03 (Asia/Singapore)<br>
Product RTL SHA: `1236d49c72360aa62e316aea147528d93a1b3705`<br>
Local verification revision before this evidence update: `0279b8e4e64d3f7a1fe214b905c60d5018b5f726`

## Scope

This is a legal, public-interface stress test for the outstanding-word counter
in `tid32_thermo5_axi_lite_axis_frontend_tx.sv`. It uses the frozen product
configuration: Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state,
one-tap Identity reset image, AXI-Lite, Generic FIFO, and four 64-bit PA planes.
No internal state was forced and no product RTL or algorithm changed.

## Test and result

The UVM test sent 2,072 accepted source words in 37 legal 32-beat packets. It
applied source backpressure and independent PA backpressure, drained the final
packet, checked every output against the independent four-plane bit-true
checker, and checked the observed outstanding-count recurrence against an
independently maintained expected count.

VCS V-2023.12-SP1_Full64, seed `930901`, reported:

- 2,072 core accepts and 2,072 output accepts; 2,072/2,072 PA words matched.
- Maximum observed outstanding count: 28.
- Saturation-guard and underflow-guard events: zero.
- Source stall cycles: 6,962; PA stall cycles: 12,129.
- Zero underflow, predictor mismatch, protocol error, UVM warning, error, or
  fatal.

The two target Raw Branch bins remain **OPEN**:

| Bin ID | RTL location | Meaning |
|---|---|---|
| `TXB-e99262dd92665c3b9ea8` | `rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:203` | Outstanding-counter saturation guard |
| `TXB-c16debdf7d9cbab220ac` | `rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:204` | Outstanding-counter underflow guard |

The long stream is useful stress evidence, but it is not a reachability proof.
The existing product-bound VC Formal attempt is non-vacuous, uses no
assumptions or black boxes, and remains **INCONCLUSIVE** for both assertions and
both exact guard covers. No waiver or Exclusion is justified by either result.

## Coverage refresh

Raw and Adjusted URG were regenerated from the same exact list of 246 test VDBs
plus one design VDB. The 245 earlier test VDBs were retained and this run was
added as test VDB 246; the set is mixed-provenance evidence, not 246 fresh runs
from one verification-source revision. Product RTL SHA is unchanged. Since
there are zero approved waivers and zero active `.el` Exclusions, Raw and
Adjusted summaries are identical.

| Metric | Raw | Adjusted | Missing |
|---|---:|---:|---:|
| Branch | 525/637 (82.4176%) | 525/637 (82.4176%) | 112 |
| Condition | 658/849 (77.5029%) | 658/849 (77.5029%) | 191 |
| Line | 3351/3796 (88.2771%) | 3351/3796 (88.2771%) | 445 |
| Toggle | 84340/104480 (80.7236%) | 84340/104480 (80.7236%) | 20140 |
| FSM states | 13/13 (100%) | 13/13 (100%) | 0 |
| FSM transitions | 17/22 (77.2727%) | 17/22 (77.2727%) | 5 |

Compared with the 245-test checkpoint, this VDB added 160 Toggle hits. The
newly covered transitions were DPD `sample_count` high-bit transitions across
the 16 one-tap lanes. Branch, Condition, Line, FSM, and legal applicable
functional coverage were unchanged. Functional coverage remains 392/392
reviewed applicable bins. The fail-closed gate remains `RAW_100_OPEN`.

The current exact open-bin ledger has 20,893 rows across 457 root-cause task
groups: 112 Branch, 191 Condition, 445 Line, 20,140 Toggle, and five FSM
transition records. All code-gap records remain OPEN. The 371 waiver
candidates remain PENDING, with zero approved waivers and zero active
Exclusions.

## Reproduction

```bash
make -C dv/uvm/sim thermo5-vcs-run-only PYTHON=python3.12 \
  THERMO5_OUT="$PWD/runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/outstanding_long" \
  THERMO5_VECTORS="$PWD/runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/outstanding_long/vectors" \
  THERMO5_USE_AXIL=1 THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 \
  THERMO5_STEP=5120 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_TESTNAME=thermo5_sku_axil_outstanding_bounds_test UVM_SEED=930901 \
  THERMO5_EXTRA_ARGS='+CORE_WORDS=2072 +PACKET_BEATS=32'
```

The same-source VCS compile used the product DUT coverage hierarchy
`dv/uvm/sim/thermo5_product_dut_coverage.hier` and
`-cm line+cond+fsm+tgl+branch+assert`. The exact compile log, simulation log,
VDB, Raw/Adjusted URG report manifests, and source/coverage hashes are retained
under the ignored local directory
`runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/`. Hashes are in
[`the machine-readable evidence`](data/thermo5-tx-outstanding-counter-stress-20261103.json).

## Checks and remaining work

- Python reference-model suite: 59/59 PASS.
- Hardware utility suite: 38/38 PASS.
- Python compile checks: PASS.
- `git diff --check`: PASS.
- Focused VCS test: PASS as described above.
- Raw/Adjusted URG refresh and fail-closed coverage gate: PASS; closure status
  remains `RAW_100_OPEN`.
- Counter Formal: INCONCLUSIVE; both target Branch bins remain OPEN.
- DPD Identity Formal, two frame-tail assertions without legal attempts, five
  CDC FSM transitions, the remaining applicable code bins, and waiver review
  remain unresolved.
- Real XPM, GT Wizard, FPGA PPA/routed timing, and physical RF/QAM256 validation
  are outside this Linux signoff and remain outstanding.
