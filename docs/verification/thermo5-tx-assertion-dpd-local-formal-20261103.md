# Thermo5 TX Assertion and DPD Local Formal Follow-up

Date: 2026-11-03 (Asia/Singapore)
Verification source revision used by the recorded runs: `0279b8e4e64d3f7a1fe214b905c60d5018b5f726`
Frozen product RTL SHA: `1236d49c72360aa62e316aea147528d93a1b3705`

This update separates legal assertion evidence from intentionally malformed
frame input and records a local one-tap DPD Identity proof. It does not change
product RTL or close the overall coverage/formal signoff.

## Coverage provenance and current code report

The current DUT-only Raw/Adjusted URG run used the same 247 test VDB paths and
one product design VDB for both reports. The 247 test paths have 247 distinct
tree hashes: 243 legal positive cases, two expected-negative cases, and two
additional legal directed cases (the product-hierarchy 11-cycle gap test and
the 2,072-word outstanding-counter test). The tests are retained mixed-source
evidence, not a fresh 247-test run from one verification-source revision.
The earlier 16-point gap sweep with STATUS-predictor mismatches is not in this
247-VDB set.

Raw and Adjusted are equal because no waivers are approved and no Exclusions
are active. The code gate remains `RAW_100_OPEN`:

| Metric | Raw = Adjusted | Missing |
|---|---:|---:|
| Branch | 525/637 (82.4176%) | 112 |
| Condition | 658/849 (77.5029%) | 191 |
| Line | 3351/3796 (88.2771%) | 445 |
| Toggle | 84340/104480 (80.7236%) | 20140 |
| FSM states | 13/13 | 0 |
| FSM transitions | 17/22 | 5 |
| Legally applicable functional bins | 392/392 | 0 |

The ledger still contains 20,893 OPEN Raw records in 457 root-cause groups.
The 247-test union includes negative-test VDBs, so its aggregate assertion
summary is not used as the legal assertion result. Raw code coverage and
assertion outcome are reported separately.

## Legal assertion regression

The separate 243-positive VDB URG report has zero DUT assertion failures and
13 successful DUT properties. The two DUT properties without attempts are the
same Centered-Cubic frame-tail guard in the two interpolator stages:

| Property | Instance | RTL location | Legal-run result |
|---|---|---|---|
| `unnamed$$_1` (`assert(q1_tail)`) | `u_frontend.g_interp1_centered.u_interp_1` | `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310` | No attempt |
| `unnamed$$_1` (`assert(q1_tail)`) | `u_frontend.g_interp2_centered.u_interp_2` | `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310` | No attempt |

The positive-only assertion report is therefore a PASS with these two
negative-input-only guards still listed as no-attempt. It is not a claim that
legal traffic has reached the malformed frame condition.

## Expected-negative frame-tail assertion regression

The corrected VCS run used `thermo5_sku_axil_illegal_frame_test`, seed
`420102`, with the vector directory
`runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/vectors/seed_930000`.
The deliberately early TLAST causes the following three RTL assertions, each
once:

| RTL assertion | Instance | Observed |
|---|---|---:|
| 56-sample `frame_start` alignment | `u_cdc.unnamed$$_1`, `rtl/axis/dsm_axis14_to_core8_cdc.sv:262` | 1 expected failure |
| `assert(q1_tail)` | `u_frontend.g_interp1_centered.u_interp_1.unnamed$$_1`, `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310` | 1 expected failure |
| `assert(q1_tail)` | `u_frontend.g_interp2_centered.u_interp_2.unnamed$$_1`, `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310` | 1 expected failure |

The test also observes the public sticky protocol error, stops the stream,
applies public reset, and confirms the sticky error clears. UVM warnings,
errors, and fatals are all zero. The standalone checker
`tools/hw/check_thermo5_axil_illegal_frame.py` requires these exact three
assertion locations/instances, rejects any other RTL assertion Error line,
checks reset recovery, and requires zero UVM warnings/errors/fatals. The
`thermo5-axil-vcs-negative` Make target now runs this checker after simulation.
Four checker unit tests pass, including deletion of one expected stage event,
an injected unexpected RTL assertion, and a nonzero UVM error count.

After wiring the checker into the target, the actual Make target was run with
the fresh product compile and seed-specific vectors. It passed and printed
the three per-instance assertion counts plus reset-recovery result. Its new
VDB is retained as target-integration evidence but was not merged into URG;
the 247-test code report and one-VDB negative assertion report are unchanged.

One earlier invocation used the vectors parent instead of the seed-specific
directory. VCS warned that the `.mem` inputs were missing; it is marked
`INVALID_NOT_COUNTED` and is excluded from both assertion reports and coverage
claims. The corrected invocation and URG report are retained separately.

## DPD Identity local Formal

VC Formal V-2023.12-SP2 completed the `identity_nostall` job in 102.39 seconds:

- 5/5 assertions proven;
- 3/3 Covers reached, including valid output and positive/negative signed
  endpoints;
- 0 black boxes and 0 environment assumptions;
- setup audit: zero clock, glitch, loop, and multidriver violations.

The harness fixes the one-tap external coefficient image to Q14 unity
(`C1_RE=16384`, all other coefficients zero), ties `out_ready` high, and feeds
the current I/Q samples to the tap vectors. It proves the local arithmetic
payload, latency, ready behavior, and no-saturation counters for arbitrary
input values under that fixed datapath configuration.

This does **not** prove arbitrary output stalls, AXI shadow/commit/mailbox or
active-epoch behavior, nor the full product-chain identity property. The
previous full Identity proof remains INCONCLUSIVE/OPEN. The local proof does
not classify Raw URG bins and does not authorize waivers or Exclusions.

## Reproduction and evidence

```bash
python3.12 tools/hw/check_thermo5_axil_illegal_frame.py \
  runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/assertion_negative_exact_20261103/axil_illegal_frame_seed420102_corrected.log

python3.12 -m unittest tools.hw.tests.test_thermo5_axil_illegal_frame_checker -v

PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_convergence.py \
  --job identity_nostall \
  --out-dir runs/thermo5_tx_closure_current/dpd_identity_nostall_local_20261103
```

The full command lines, manifests and SHA-256 values are indexed in
[`thermo5-tx-assertion-dpd-local-formal-20261103.json`](data/thermo5-tx-assertion-dpd-local-formal-20261103.json).
The generated VCS/URG/VC Formal payloads remain under ignored `runs/`.

## Remaining closure

The two frame-tail assertions are now observed in a separate expected-negative
run, but remain without attempts in legal traffic. Keep their legal-run and
negative-run results separated. Outstanding counter guard Formal remains
INCONCLUSIVE; 112 Branches, 191 Conditions, 445 Lines, 20,140 Toggle directions
and five FSM transitions remain OPEN. The 371 waiver candidates remain
PENDING, with zero approved and zero active Exclusions. Full-chain DPD Identity
Formal, real XPM/GT Wizard, FPGA PPA/routed timing, and physical RF/QAM256
remain outside Linux closure.
