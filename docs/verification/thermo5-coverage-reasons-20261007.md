# Exact coverage closure reasons (2026-10-07)

Evidence: actual licensed CI37462007850, commit
`a9b0bc6f67f575e9bb98085b1e064f9eddc886f2`. Raw URG remains generic87.48%,
XPM80.26%; no new simulation or exclusions in this audit. Generic/XPM scopes
differ. Generated reasons: `runs/thermo5_coverage_reasons_20261007/`.

## Candidate disposition accounting

This is an independently calculated analytical/configuration/scoped
disposition metric, not an URG exclusion report or completed signoff.
Every denominator comes from the saved matching-build after report;
every missing line/condition/branch/toggle record reconciles exactly.
The source hashes match the CI ledger and latest four-job formal manifest.

| Generic metric | Raw hit/total | Candidate disposition | OPEN | Candidate adjusted |
| --- | ---: | ---: | ---: | ---: |
| Line |2512/2890|378|0|100%|
| Condition |276/346|70|0|100%|
| Branch |265/363|98|0|100%|
| Toggle directions |82648/97032|13840|544|99.3461%|

The generic full code-coverage100% goal is **not achieved**. A proof ledger
is not a simulation hit. URG Total Bits sums the0->1 and1->0 totals;
directional missing records reconcile to the same denominator. The prior
ledger note saying the denominator did not count directions was incorrect;
the generator is corrected, original CI artifacts retained.

## Reasons, with precise scope

| Missing group | Why legal frozen stimulation cannot hit it | Evidence / limit |
| --- | --- | --- |
| Constant coefficient/active_taps/low-power ports | TB fixes taps1, c1_re16384 and others0. ENABLE_LOW_POWER_CTRL0 fixes its state/control and core_drain0. | TB/wrapper constants. Coefficient ports are configuration evidence, not arithmetic evidence. |
| DPD pair1/history/internal-input paths | MAX_TAPS1 makes pair1 loop arm impossible and delayed-history loops empty. USE_EXTERNAL_TAPS1 selects the external path. Vector tap0 always<=lane. | Actual RTL loop bounds and selections. |
| Interpolation3/4-tap and long history paths | INTERP_TAPS2; HISTORY1<LANES8/16. | Actual elaboration parameters. |
| Parameter errors / hold-state alternative | CHANNELS32/VALID_BANKS8 and64/64 bridge are legal. HOLD_STATE_ON_DISABLE0 makes its opposite predicate false. | Actual guards and parameter propagation. |
| Identity DPD saturation / saturation_count | gain_re16384, gain_im0; term=(x*16384)>>>14=x or0; pair1=0. Signed16 range is retained, so sat never asserts. | Analytical pipeline argument, exhaustive scalar-domain RTL corroboration. Optional full sequential arithmetic FPV is inconclusive; never label it PASS. |
| Interpolation saturation |8192*x+8192*y, Q14 rounded average stays within signed16 range.|Interval argument; not full sequential FPV.|
| Generic residual/default/high residual bits | Residual only0/2/4/6/8/10/12; bits223:192 zero; frame marker implies valid. | Seven production-RTL assertions/nine covers in exact7:4 scoped model. XPM transfer remains OPEN. |
| Reset collision operand1/0 | Falling-edge runtime assertion settles sync_q0 before the sampled active edge. | Three nonvacuous assertions/four normal covers, collision uncoverable. Same-active-edge races/metastability excluded from this proof scope. |
| sample_count31:15 | **Reachable**, not unreachable: bitn rises after2^n accepted DPD vector words. | Current stream16387 words;35 production-width transition assertions prove count behavior, not URG hits. |
| XPM vendor paths/FSM | Individual configuration/reset/feature reachability not reviewed. |5990 records remain OPEN, including two aggregate FSM records representing three missing transitions. Vendor ownership alone never justifies removal. |

CSV files contain each exact bin ID, instance, metric, original URG statement,
condition/predicate/signal and its reason. Project dispositions include source
references/hashes; vendor and proof-transfer OPEN rows retain saved-ledger
provenance without invented vendor source hashes. The detailed XPM bin reason remains a missing
proof/stimulus requirement; it is not an impossibility claim. XPM also keeps
134 generic-proof-transfer records and544 reachable counter directions OPEN.

## Reaching the remaining counter transitions

`reachable_counter_plan.csv` lists every bit15..31 for both FIFOs. Preserve
the32-bit production counter and original datapath. Extend legal AXIS input
and independent four-plane checking; check all16 counters against accepted
DPD words, then use public reset for falling transitions. Do not deposit
internal state, shrink the counter, alter coefficients or rewrite the VDB.

Measured16387-word simulation wall time is10.729s generic and10.842s XPM.
Linear extrapolation to bit31 first rise is16.27/16.44 days per FIFO, before
oracle generation/storage costs. This estimate is not an executed test or
proof that runtime must be exactly that long. Natural bit31 fall requires
2^32 words; reset can give a fall after the2^31 rise. Formal and accelerated
compositional checking may establish verification closure, but cannot be
reported as a URG toggle hit.

## Reproduce the audit

```powershell
python tools/hw/thermo5_coverage_reason_report.py runs/thermo5_real_ci_37462007850 runs/thermo5_coverage_reasons_20261007
```

The script fails on stale source/proof hashes, non-PASS CI/formal evidence,
unknown reasons or denominator mismatches. Raw databases are untouched.

## Uncovered source locations

These are missing behaviors in the frozen SKU, not whole untested modules.
The CSVs retain instance-specific line, condition, branch and toggle bins.

| Canonical source | Unhit code / signals | Reason and evidence status |
| --- | --- | --- |
| `rtl/dpd/dpd_memory_poly.v:334` | `sample_count[31:15]` rising/falling transitions in all16 lanes | Reachable; current16387-word stream does not reach bit15's32768-word first rise.544 directional records OPEN. |
| `rtl/dpd/dpd_memory_poly.v:190` | Pair1 accumulation190/191, history209/210 and331/332, internal taps237-242 | MAX_TAPS1 / USE_EXTERNAL_TAPS1 bypass these paths. Configuration disposition. |
| `rtl/dpd/dpd_vector16_memory_poly.sv:56` | Previous-vector history reads56/57 and long-history shifts75/76 | Single tap uses the current lane; history length1 is below lane count16. Configuration disposition. |
| `rtl/dpd/dpd_poly.v:416` | Positive clamp416/417 and negative clamp419/420 | Identity DPD preserves signed16 range. Analytical argument plus scalar exhaustive test; full sequential arithmetic FPV remains inconclusive. |
| `rtl/dpd/dpd_memory_poly.v:337` | Increment of `saturation_count` | Same identity bound; saturation never asserts in this SKU. |
| `rtl/interp/dsm_interp_x2_polyphase_vector.sv:91` | Positive/negative clamp91/92 | Two-tap rounded average remains signed16. Analytical bound. |
| `rtl/interp/dsm_interp_x2_polyphase_vector.sv:178` | Three/four-tap arithmetic178-191, long-history214/215, alternate hold-state branch | INTERP_TAPS2, HISTORY1, HOLD_STATE_ON_DISABLE0. Configuration disposition. |
| `rtl/axis/dsm_axis14_to_core8_cdc.sv:197` | Default residual error197/198, `rem_count_q[0]`, residual data223:192, line117 operand bin | Generic scoped proof: only even residuals0..12, high data zero, frame implies valid. Transfer to XPM remains OPEN. |
| `rtl/axis/dsm_reset_sync.sv:27` | Condition operand1/0 in `!arst_n || !sync_q[0]` | Uncoverable in the proved falling-edge reset model; arbitrary off-model reset timing is not signed off. |
| `rtl/gt/gt_tx_user_bridge.sv:21`, `rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv:62`, interpolation77 | Illegal-parameter `$error` arms | Legal frozen elaboration cannot trigger them. |
| Frozen coefficient/active-tap/low-power ports | Constant directional toggle bins | Fixed1-tap identity coefficients and disabled low-power feature. Configuration disposition. |
| XPM FIFO/CDC vendor source | Optional/reset/FSM paths and internal toggles; examples: CDC1080 invalid DEST_SYNC_FF `$error`,1132.10 reset assignment, memory310 width-mismatch `$error` |5990 records lack individual closure; vendor ownership is not proof. Locations come from saved URG statements; do not assign canonical RTL file names to vendor code. |

The two aggregate XPM FSM gaps are `curr_fwft_state` (8/9 transitions)
and `gen_rst_ic.curr_wrst_state` (6/8). Detailed saved URG tables identify
their exact missing transitions in `xpm_fsm_gaps.csv`, with report hashes:

- `stage1_valid->invalid`, xpm_fifo_base line1277.
- `WRST_EXIT->WRST_IN`, xpm_fifo_rst line1767.
- `WRST_OUT->WRST_IN`, xpm_fifo_rst line1759.

The extraction reconciles3 exact missing transitions to the2 original
aggregate records. Legal triggers and reachability proofs remain OPEN.

## Formality follow-up

Actual restored-feature retry launched2026-10-07 11:22 SGT in
`runs/thermo5_fm_restored_20261007_retry1/`. Formality V-2023.12-SP3 read
the original SVF and cell library and entered verify:170869 matched compare
points,0 unmatched compare points;26148 SVF commands accepted/0 rejected.
Verification is still RUNNING. The prior access rejection and old feature failure are
historical, not the result of this retry.

The equivalence runner now accepts `--mapped-run` and a fresh `--out-dir`.
It validates prior actual DC PASS, original RTL/SDC/library hashes and
mapped netlist/SVF hashes. It does not overwrite the previous DC/FM evidence.
Use the existing permitted DB setting in the licensed Rocky environment:

```bash
python3.12 syn/asic/run_thermo5_frozen.py --equivalence-only \
  --mapped-run runs/thermo5_asic_retest_20261006_2016 \
  --out-dir runs/thermo5_fm_restored_20261007
```

Python compilation/help and local coverage auditing pass. Actual Formality
is running. Mandatory FPGA OOC after synthesis-flow edits completed12/14PASS
at `syn/reports/ooc_xc7z020clg400_1_20261007_112340/`; mb_ef2=-0.093ns
and mb_mash22=-0.688ns remain FAIL_TIMING.
Canonical RTL, MATLAB and numerical behavior are unchanged.
