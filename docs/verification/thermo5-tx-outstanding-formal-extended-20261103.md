# Thermo5 TX Outstanding-Counter Formal Extension

Date: 2026-11-03 (Asia/Singapore)<br>
Formal source revision: `0279b8e4e64d3f7a1fe214b905c60d5018b5f726` (dirty verification worktree)<br>
Product RTL SHA: `1236d49c72360aa62e316aea147528d93a1b3705`

## Result

The product-bound VC Formal run was extended to a 22-minute global effort
limit, with a 20-minute per-property limit. It finished normally after
1,364.76 seconds. Both counter guard assertions remain **INCONCLUSIVE**; both
exact guard Covers also remain **INCONCLUSIVE**. This run closes neither Raw
Branch and does not justify a waiver.

| Target | Result | Depth |
|---|---|---:|
| `a_no_counter_saturation_guard` | INCONCLUSIVE, non-vacuous | 231 |
| `a_no_counter_underflow_guard` | INCONCLUSIVE, non-vacuous | 122 |
| `c_counter_saturation_guard` | INCONCLUSIVE | 196 |
| `c_counter_underflow_guard` | INCONCLUSIVE | 126 |
| `c_source_accept` / `c_core_accept` / `c_output_accept` | COVERED | 4 / 9 / 33 |

Formal setup found zero setup violations and zero black boxes. There are no
environment assumptions; the only reported constraint is the reset
initialization `rst_n==1`. The two assertions were non-vacuous and the activity
Covers witness source, core, and output handshakes. VC Formal reached its
specified maximum-effort limit without a proof, counterexample, or guard Cover
witness. The guard bins remain **OPEN**.

The target product RTL uses the saturating/underflow-guarded counter update at
`rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:202-204`:
accepted core words increment unless the count is `8'hff`; accepted output
words decrement unless the count is zero. Proving the arithmetic guard
prevents wrap is not equivalent to proving those guard predicates unreachable.

## Reproduction and evidence

```bash
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_axil_outstanding_fpv.py \
  --out-dir runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/formal_outstanding_extended_20261103 \
  --timeout 1500
```

VC Formal: `V-2023.12-SP2 for linux64 - Jun 03, 2024`. The run used the frozen
Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state, one-tap Identity,
AXI-Lite and Generic FIFO product configuration. The source driver emits legal
32-beat packets, PA readiness is arbitrary by plane, and the harness contains
zero environment assumptions.

The run directory is retained locally under ignored `runs/`. Its compact
machine-readable index is
[`thermo5-tx-outstanding-formal-extended-20261103.json`](data/thermo5-tx-outstanding-formal-extended-20261103.json).
That index binds the raw runner manifest, properties, setup, engines and
console-log hashes, together with all formal source hashes. No URG VDB was
modified or merged by this Formal run.

## Coverage and disposition

The latest same-list Raw/Adjusted URG metrics are unchanged: Branch 525/637,
Condition 658/849, Line 3351/3796, Toggle 84340/104480, FSM states 13/13,
transitions 17/22, and legal applicable functional bins 392/392. Raw equals
Adjusted with zero approved waivers and zero active Exclusions. The two
counter guard Branch bins remain OPEN, and the overall code gate remains
`RAW_100_OPEN`.

Next formal work should split the product proof around the bounded in-flight
capacity of the CDC, interpolator, and output pipeline, while preserving
public-interface backpressure behavior. Do not add a bound assumption or
reclassify the current Inconclusive results as unreachable without a
source-bound proof and non-vacuous witness.
