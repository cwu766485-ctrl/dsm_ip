# DSM V1.3 Round 5 code coverage follow-up

2026-11-26 SGT. Baseline commit `65c04c6`.

The 95% target remains OPEN. EF1 AXI-Lite Line reached 97.52% adjusted
and MASH AXI-Lite Line reached 97.53% adjusted. Their Branch scores
reached 95.68% and 95.23% adjusted, respectively.

| Configuration | Line raw / adjusted | Branch raw / adjusted | Condition | Toggle raw / adjusted |
|---|---:|---:|---:|---:|
| EF1 Product | 88.38 / 92.63 | 75.92 / 77.34 | 80.03 | 85.11 / 88.12 |
| EF2 Product | 83.15 / 88.61 | 64.47 / 64.96 | 67.79 | 82.72 / 85.66 |
| MASH Product | 87.95 / 92.39 | 76.01 / 76.37 | 77.23 | 81.54 / 85.15 |
| EF1 AXI-Lite | 93.36 / 97.52 | 94.27 / 95.68 | 86.10 | 85.14 / 85.14 |
| EF2 AXI-Lite | 87.88 / 93.29 | 81.95 / 82.46 | 77.03 | 82.90 / 82.90 |
| MASH AXI-Lite | 93.18 / 97.53 | 94.87 / 95.23 | 86.10 | 81.84 / 81.84 |

All values are percent. Condition uses its raw URG value in both views. The isolated scalar MASH wrapper/core is outside this follow-up merge
and retains its prior raw values of 90.16 Line, 71.43 Branch, 100.00
Condition and 98.36 Toggle.

## Why coverage stalled

- The old AXI-Lite replay primarily exercised identity arithmetic. One-tap
  boost, signed C3/C5 and extreme IQ/gain vectors reach the real DPD
  saturators. Each AXI-Lite SKU gained 144 Line, 80 Branch and 43 Condition
  hits. Coefficient transport against an independent stream oracle turns the
  unused bits in the writable register storage without reconfiguring the
  active arithmetic tap.
- The bare Product testbench ties all DPD coefficient inputs and tap count
  to a single image. The AXI-Lite SKU has writable coefficient ports. This
  limits application of the Product tie-off waiver to the fixed UVM fixture.
- Replicated DPD lanes account for 68,128 remaining directional Toggle misses
  across the six elaborations after the scoped waivers. Active coefficient
  slices, counter high bits and arithmetic ranges require separate treatment.
  High counters can be reachable on longer legal streams and stay OPEN.
- EF2 has both a disabled lookahead path and active serial arithmetic.
  VC Formal proved that the default lookahead and invalid parameter guard
  cannot execute in the scoped W16, 32-channel instance. Conditions and
  branches on the active path require additional stimuli or exact proof.
  The centered-cubic interpolator has 213 remaining Condition misses and
  EF2 has 216 across these reports.

## Measurement and waiver evidence

21 focused VCS cases passed with the four-plane Python vector oracle and
zero UVM errors/fatals. Six independent URG merges used 117 cumulative test
VDBs. Relative to the prior cumulative run the aggregate gains were 432
Line, 240 Branch, 129 Condition and 15,563 directional Toggle hits.
The audit reconciles instance numerators and denominators with each
selected-DUT URG percentage and checks that every instance metric keeps its
denominator and at least its prior hit count. Native hit-set identity is
still OPEN. The initial one-frame bare Product trial failed the test's
three-frame expectation. The final trial preserves that expectation and
all figures use the passing 21-case matrix.

The separate adjusted ledger applies 11,142 bins. The exact instance, URG
report anchor, bit or source line, proof reason and evidence hash are in
`round5_code_waivers.csv`. This is an arithmetic adjustment from instance
counts. The original VDBs and URG reports retain raw counts.

- 10,098 directional Toggle bins are fixed input bits at the vector DPD
  and each DPD lane in the three bare Product UVM elaborations.
- 864 Line bins are tied to the one-tap/external tap elaboration. The
  second accumulator pair is never selected, the history reset loop is
  empty, and external tap input is selected on every update.
- 152 EF2 Line bins are in the disabled lookahead body. The formal property
  report and the parent RTL instance establish the parameter contract.
  No branch or condition entries were inferred from the line list.
- 28 Branch bins are invalid parameter error arms for the equal-width GT
  bridge, EF1 bank geometry, and the fixed MASH adapter configuration.
- The identity clamp formal run hit input and output witnesses. Its four
  no-clamp assertions and four clamp covers were inconclusive. All of
  those candidate bins remain OPEN in this ledger.

The next targets are the remaining EF2 serial arithmetic and centered-cubic
cases, and the DPD Toggle ranges and counters. Reopen affected waivers when
their instance hierarchy, source, tap configuration or fixture wiring changes.

Local evidence uses `runs/dsm_v13_round5_arithmetic_v4`,
`runs/dsm_v13_round5_arithmetic_urg_v4`, `runs/r5_audit_v5` and
`runs/r5_ef2_params_fpv`. The executable entry points are
`run_dsm_v13_round5_arithmetic.py`, `merge_dsm_v13_round5_history.py` and
`audit_dsm_v13_round5_instances.py` under `dv/uvm/sim`.
