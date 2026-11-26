# EF1 and MASH AXI-Lite code coverage closure

2026-11-26 SGT. Follow-up to `96092ef`. Sign-off for the two AXI-Lite
elaborations is **OPEN on Condition**. Line, Branch and Toggle meet the
95% adjusted threshold in both. EF2 is outside this sign-off scope.

| Configuration | Line raw / adjusted | Branch raw / adjusted | Condition raw / adjusted | Toggle raw / adjusted |
|---|---:|---:|---:|---:|
| EF1 AXI-Lite | 93.36 / 97.52% | 94.27 / 95.68% | 86.77 / 91.08% | 90.42 / 98.09% |
| MASH AXI-Lite | 93.18 / 97.53% | 94.87 / 95.23% | 86.77 / 91.08% | 88.25 / 97.58% |

All values are percentages. Each Condition target has **643 hits, 741 raw
bins, 35 waived bins and 63 open bins**. With the current adjusted
denominator of 706, each SKU needs 28 additional hits to reach 95%.
The original URG scores remain available in the raw reports.

## Root causes and RTL to inspect

| RTL and anchor | Missing behavior or reason |
|---|---|
| [DPD coefficient and accumulator pipeline](../rtl/dpd/dpd_memory_poly.v#L141) | Previous tests loaded one active coefficient image per run. For many bits this measured an identity-to-coefficient transition only. Complex C1/C3/C5 inputs and an independently checked drained reset now exercise both directions. The second accumulator pair stays zero at `MAX_TAPS=1`. |
| [DPD ready qualification](../rtl/dpd/dpd_memory_poly.v#L141) | Each SKU has 16 remaining instances of the `0,1` tuple for `out_ready \| !valid_pipe[10]`. It requires simultaneous downstream backpressure and an empty final DPD stage, rather than the usual full-stage stall. The 16-lane pipeline shares the ready path. This tuple remains OPEN pending a legal witness or an integration-level proof. |
| [Centered cubic queue and frame-tail control](../rtl/interp/dsm_interp_x2_centered_cubic_vector.sv#L66) | 23 Condition bins per SKU remain after the static deductions. The exact combinations involve queue count and retained head/tail metadata, `out_ready` during a tail, and reset at a stalled or nonempty stage. Instance 1 and instance 2 have different tail parameters and therefore different valid combinations. Several commits and source gap phases were exercised but did not hit these combinations. |
| [AXI-Lite RUN/drain control](../rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv) and [CDC empty/frame control](../rtl/axis/dsm_axis14_to_core8_cdc.sv#L113) | The AXI-Lite wrapper has 8 EF1 or 7 MASH open Condition bins. CDC has eight each, involving synchronized empty, buffered payload, remainder, drain and frame markers. These depend on temporal ordering and cannot be classified from register reset defaults. |
| [AXI-Lite config write and commit](../rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv#L93) | The write-fire tuple `0,1,1` is formally unreachable when BVALID is asserted. Two request/pending/boundary tuples at line 333 remain OPEN. |
| [Frame gain marker pipeline](../rtl/frontend/dsm_frame_gain_vector.sv#L110) | Four valid/frame marker tuples are structurally impossible because each stage registers marker and valid together. Three other Condition tuples per SKU remain OPEN. |
| [DPD counters](../rtl/dpd/dpd_memory_poly.v#L328) | Sample and saturation counts require long legal traffic through the active lane. A 40-packet, 2,240-output-word case checked all planes and counter reset. Higher counter bits stay OPEN where still unhit. |

The exact open tuples, including the minor front-end and MASH adapter
conditions, are in `round5_focus_condition_gaps.csv`. Each row records
SKU, hierarchical instance, RTL path and line, expression, operand values
and URG report hash. The toggle table retains URG's rendered bit ranges and
per-direction states. The instance counter table retains the full raw
numerators and denominators.

## Validation and waiver scope

- Rebuilt both selected DUT configurations and ran 16 checked complex
  arithmetic, gain, COMMIT/stall and drain/reset cases. All passed with
  independent four-plane vector comparisons and zero UVM errors/fatals.
  The reset checks the restored identity image and all 16 cleared sample
  counters after checking the previous stream. Two real-only legacy mode
  smoke cases passed on the rebuilt binaries.
- Eight additional legal AXI-Lite boundary-phase cases passed against
  the identity oracle. They did not add measured RTL code hits over the
  focused arithmetic merge. Final separate URG reports contain 30 EF1 and
  32 MASH VDBs, including each SKU's previously accepted baseline cases.
  URG per-instance denominators equal the prior cumulative counts and no
  instance hit count decreased. Exact hit-set equivalence remains OPEN.
- The first attempted long case was rejected by the inherited 56/112-word
  test guard. The directed complex mode now explicitly permits up to 40
  complete 56-word packets. The final 40-packet cases passed for both SKUs.
- VC Formal proved `a_second_pair_zero` and the staged invalid-slot zero
  invariant over the one-tap DPD with unconstrained data, coefficients and
  backpressure. Valid output, a stalled output and an accepted bubble were
  witnessed. The adjusted ledger deducts exactly 8,192 directional bits per
  SKU for the four zero-valued 64-bit pair-1 signals across 16 lanes.
  The independently proven invalid-output no-saturation assertion covers
  the 16 missing Condition `0,1` tuples at line 337.
- 14 Condition tuples per SKU are contradictions in centered-cubic
  instance parameter wiring or continuous equations. Four frame-gain flag
  tuples follow from the paired valid/flag updates, reset, clear and hold.
  One config write tuple per SKU uses the separate VC Formal line-93 proof
  with both a write and a write-response witness. The waiver ledger records
  each exact tuple and its evidence. These deductions are applied in the
  adjusted accounting only.

The root-cause CSVs, waiver ledger and test/formal manifests are in
[the focus evidence directory](verification/data/dsm-v13-round5-axil-focus/).
Simulation used the existing Product RTL. The previous 95% minimum still
requires at least 28 further Condition hits per SKU under the current
accounting. The first targets are the replicated DPD ready tuple and
the two interpolator instances' legal queue/tail transitions.
