# DSM V1.4 directed coverage follow-up

Baseline commit `cc97188` and the two SKU-local V1.4 cumulative databases.
Product configuration is EF1 or MASH 1-1, AXI-Lite, Centered Cubic, Generic FIFO,
and one DPD tap. Gate A (95% adjusted) and Gate B (100% adjusted plus sign-off
evidence) remain OPEN.

| Metric | EF1 adjusted (open) | MASH 1-1 adjusted (open) |
|---|---:|---:|
| Line | 97.52% (80) | 97.53% (76) |
| Branch | 95.68% (23) | 95.23% (25) |
| Condition | 93.91% (43) | 93.91% (43) |
| Toggle | 98.58% (1,376) | 98.17% (1,416) |
| Total open bins | 1,522 | 1,560 |

The SKU-local reports credit 436 and 420 new Toggle directions respectively,
and one new Condition tuple per SKU. The exact Condition universe and
rendered Line, Branch, and directional Toggle missing-set audit found no
regression. Gate A is eight Condition hits away at the unchanged 706-bin
adjusted denominator. The [current metrics](verification/data/dsm-v14-coverage/followup_code_coverage.csv),
[Condition delta](verification/data/dsm-v14-coverage/followup_condition_delta.json)
and [native evidence index](verification/data/dsm-v14-coverage/followup_evidence.json)
identify the credited result.

## Full-stream checked replay

Both SKU elaborations rebuilt with VCS V-2023.12-SP1 Full64.
For the COMMIT witness, use one 32-beat packet with DSP frame starts
`1,8,15`. Set the AXI-Lite clock phase to 2857 ps and issue the late COMMIT
four core cycles after the first observed DPD boundary. At the next boundary,
the real DUT observes `cfg_req_sync2=1, cfg_pending_valid=0,
dpd_config_boundary=1` at the L333 sample edge. COMMIT subsequently applies
and acknowledges, all 56 PA words match the independent four-plane oracle,
and the test checks STOP, drain and DONE W1C. URG credits the exact tuple
in both SKU-local reports.

Two 8,960-PA-word counter pilots per SKU checked all four planes against the
independent Python oracle. All 16 lanes counted 9,120 accepted DPD samples.
The identity case observed zero saturation. The saturation case had
4,480–8,960 qualifying increments per lane. Both counters cleared after the
public reset. The merge added 64 EF1 and 48 MASH sample-count directions
and 180 saturation-count directions per SKU. Native URG shows both
`sample_count[13]` directions in all 16 lanes of each SKU. Line and Branch
had no changes.

The Cubic diagnostic replay checked 36 legal two-packet PA-stall cases and
12 accepted boundary-gap cases. The remaining 24 boundary-gap diagnostics
failed the stream underflow check and cannot contribute to coverage.
The checked cases observed zero single-entry pop/push target events.
Adding the PA-stall passes to the SKU-local counter/COMMIT reports produced
zero new Line, Branch, Condition and Toggle hits. The next Cubic step is
to constrain the stage-2 tail and stage-1 frame end in a product-level
control witness.

## Formal and waiver review

The extended CDC harness left core ready, enable and drain unrestricted
and emitted continuous legal source beats in 32-beat quanta. VC Formal
V-2023.12-SP2 proved the L151 false-arm safety assertion before any lemma
promotion. The setup had zero black boxes. Pending-under-stall, pending
while disabled, and legal end during drain covered. The false-arm Cover
and read-side TLAST phase helper were inconclusive in that pass. The
proof scope uses continuous source valid after reset and a common reset
epoch. Product applicability with source gaps and reset sampling remains
open, so L151 receives no applied exclusion.

The original 106 pending rows still map one-for-one to currently open
instance/expression or rendered statement/arm keys. The
[static follow-up ledger](verification/data/dsm-v14-coverage/static_followup_candidates.csv)
adds 48 pending rows for fixed parameters and the second interpolator's
disabled internal tail generator. Each has the native report locator,
source hash and applicable elaboration condition. Approvals have not been recorded for these candidates. The original batch
is ready for review in the [independent waiver packet](verification/data/dsm-v14-coverage/waiver-review/README.md).
The longer configuration-block Formal attempt leaves COMMIT L333 tuple
`0,1,1` and its request/pending invariant inconclusive.

## Bounded-storage counter soak

The soak uses one Python oracle packet regardless of run length. It checks
each accepted post-DPD/Cubic backend input word against its packed I/Q
oracle, checks the first 55 words on all four PA planes, checks the total
PA word count and legal protocol during the stream, and checks exact
modulo-32-bit totals for both counters on all 16 lanes. A common public
reset clears the counters after the checked drain. Backend recurrence is
continuous, so the single-packet PA values are used for the initial
window only. No DUT state is deposited, forced or initialized beyond
public reset.

The independent generator computes per-lane saturation counts on one
frame including the interpolator tail. A sample lane advances 57 times
per packet. For the original extreme waveform, the slowest saturation
lane advanced 28 times per packet. Both SKUs passed the sample and
saturation bit-15 cases at 1,200 packets and 67,200 backend words each.
Their standalone native URG reports confirm both directions in every
lane for both counters. The negative-control oracle mutation was detected
at backend input word zero.

The later constant-rail saturation case raises the slowest lane to
56 qualifying increments per packet. The identity sample case uses zero
input. Four 160-packet benchmarks passed with independently checked lane
totals. Bit 31 now requires 37,675,152 sample packets or 38,347,923
saturation packets, approximately 2.11 and 2.15 billion backend words per
SKU. Extrapolating the 160-packet benchmarks gives about 70 and 78 CPU
days on EF1, and 11 and 17 CPU days on MASH, for sample and saturation
respectively. These are planning estimates, sensitive to sustained
throughput and host load.

## Reproduction

Build the two product elaborations using the parameter combinations in
the [Round 6 report](dsm_v13_round6_execution_report.md#reproduction).
The COMMIT/counter pilot runner takes the build directory and the prior
V1.4 frame replacement run directory.

```bash
python3 dv/uvm/sim/run_dsm_v14_commit_counter.py \
  --build runs/v14_build \
  --baseline runs/v14_frame_replacement_01 \
  --out runs/v14_commit_counter_refresh \
  --urg /opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
python3 dv/uvm/sim/run_dsm_v14_counter_soak.py \
  --sku ef1_axil --saturation --bit 15 \
  --simv runs/v14_build/ef1_axil/simv \
  --baseline-vdb runs/v14_commit_counter_refresh/v14_commit_counter_ef1_axil.vdb \
  --out runs/v14_ef1_saturation_bit15 \
  --urg /opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
THERMO5_FORMAL_REPO="$PWD" \
THERMO5_FORMAL_OUT="$PWD/runs/v14_cdc_stall" \
THERMO5_CDC_VARIABLE_CORE_CONTROL=1 \
vcf -batch -fmode FPV -f dv/uvm/formal/run_thermo5_cdc_end_remaining_fpv.tcl \
  -out_dir "$PWD/runs/v14_cdc_stall/session"
```

CPU estimates should be based on target-host throughput. Product-code
coverage remains split by SKU and independent from FSM, mandatory groups
and crosses, and critical assertions. The final gate also requires the
sign-off evidence for those obligations.
