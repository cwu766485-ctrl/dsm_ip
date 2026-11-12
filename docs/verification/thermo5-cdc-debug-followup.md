# Thermo5 CDC/RDC debug follow-up

## Scope and source

Product RTL checkpoint: `ec9127e28d50eee4a7425b5a24cce3127f01d017`.
This follow-up changes constraints, proof goals and diagnostics; it makes no
additional product RTL change. PR62 remains a draft and is not merged.
Owner reset contract: common assertion, locally synchronized release, no
runtime independent reset. No equivalence between the three release signals
is assumed in the conservative native SpyGlass run.

## Findings and actual corrections

1. **Missing clock edges: FIXED.** The original SGDC supplied periods but no
   edge lists. Full `cdc/cdc_verify` issued `Ac_clockperiod01` and could not
   establish the FIFO read-pointer Gray check. Added explicit rising/falling
   edges at 0/5 ns, 0/4 ns and 0/2.286 ns. Clocks remain asynchronous, with the
   same periods; no rule is disabled. The write-side `wr_full_next` Gray check
   now reports PASSED instead of Partially-Proved.
2. **Identity proof provenance: FIXED and independently audited.** Git checkout
   normalized seven historical CRLF CSV blobs under `*.csv text`, creating a
   dirty worktree before execution. Earlier separate-checkout runs also had
   HEAD drift. A new isolated shared clone has local `.git/info/attributes`
   `*.csv -text` before checkout; it preserves the original blob bytes without
   changing repository attributes or historical CSVs. Fixed detached SHA,
   clean start/end, Python 3.12, no source edits during proof. Audit status:
   `PASS_SCOPED_DPD_IDENTITY_OUTPUT_UNDER_STALL`, zero errors. All 41 internal
   lemmas were independently proven before promotion; all four final output/
   saturation goals proven, four positive covers. Scope is one-tap identity
   DPD under legal stable-source backpressure, not arbitrary coefficients,
   CDC, repeated reset, or the entire TX chain.
3. **Three fast status hold failures: ROOT CAUSE IDENTIFIED, OPEN.** Native
   counterexamples include a 4.5 ns low interval of `tx_active_status_c`
   (110250–114750 ps) and a 4.5 ns high interval of `draining_status_c`
   (87750–92250 ps), against 8/10 ns receiving periods in that run. All three
   reset ports remain released throughout these counterexamples. Therefore
   common-reset assumptions cannot dismiss these failures. Registering the
   source removes combinational glitches, but cannot guarantee pulse capture.
   AXI status bits are documented synchronized levels, not event counters;
   a missed transient is not by itself proof of an architectural defect.
   However `core_active_s2` also controls prefill clearing, so that control
   use requires a separate restart/epoch proof. No waiver is proposed.
   A reliable event/acknowledged-status design would require a separately
   verified CDC protocol and defined status latency; simply adding another
   synchronizer stage or imposing a minimum RUN hold assumption is inadequate.
4. **Mixed convergence: ROOT CAUSE IDENTIFIED, OPEN.** The failed
   `rd_empty_next` group contains five write-pointer bits plus independent
   `prefill_ready_s` and `run_s2` controls. A combined seven-bit Gray obligation
   is not a FIFO-pointer-only Gray obligation. The native trace starts with
   coincident RUN and pointer changes, with no reset assertion. This explains
   why pointer onehot proofs do not discharge this group. It does not prove
   reconvergence safe. FIFO ownership, prefill start, and delayed-control
   sequencing need a protocol/metastability-aware proof before disposition.
5. **Depth-16 repeated-reset epoch proof: OPEN.** Added capacity/frontier
   assertions as goals, never assumptions. With a three-minute bound, four
   existing assertions prove; initialization, actual capacity and observed
   frontier remain INCONCLUSIVE at depths 9/10/10. The transfer cover hits
   depth 9; reset/recovery cover remains INCONCLUSIVE at depth 10. This is
   not a counterexample and not a pass. No smaller FIFO substitutes for the
   product depth. No further unchanged retries are used to claim closure.

## Exact native result

SpyGlass V-2023.12-SP1, AXI-Lite top, MAX_TAPS=1, Generic FIFO, no waivers:

| Full CDC goal | Error | Warning | Info | Implicit proofs |
|---|---:|---:|---:|---|
| Before edge correction | 5 | 35 | 108 | 4 failed / 4 passed / 10 partial |
| After edge correction | 4 | 34 | 109 | 4 failed / 5 passed / 9 partial |

The four remaining errors are the three `Ac_cdc01a` hold failures and one
`Ac_conv02` mixed-control convergence. Zero unsynchronized crossings and
seven convergences are reported; neither implies signoff. Eight FIFO payload
checks and the mailbox acknowledgement hold check remain partially proven.
Mailbox payload hold and two FIFO metadata checks pass. The full CDC goal
is now part of the reproduction script, in addition to structural checks.
Structural zero errors must never substitute for this full-goal result.

RDC root groups retain all original records and OPEN status. The prior
10506 errors are not removed by the clock constraint fix or local identity
arithmetic proof. Unreset payload, write-enable reset crossings, and new-epoch
ownership require path-specific proofs. No RDC waiver is approved, and no
URG exclusion is changed.

## Reproduction and evidence

```bash
# In the ECO checkout; Python must be 3.12 (system python3 is older).
mkdir -p runs/cdc_debug/verify_edges
THERMO5_STATIC_ROOT=$PWD \
THERMO5_STATIC_OUT=$PWD/runs/cdc_debug/verify_edges \
THERMO5_STATIC_GOAL=cdc/cdc_verify \
 /opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin/sg_shell \
 -tcl dv/uvm/static/run_thermo5_axil_cdc.tcl \
 > runs/cdc_debug/verify_edges/console.log 2>&1
/tmp/nmaforge_arch_v2_py312/bin/python -m unittest discover \
 -s tools/hw/tests -p 'test_thermo5*py'
```

For exact identity proof provenance, create a new clone without checkout, write
`*.csv -text` to its local `.git/info/attributes`, then detach at the checkpoint
above. Verify empty `git status --short` before and after. Do not update HEAD
while the proof runs:

```bash
/tmp/nmaforge_arch_v2_py312/bin/python \
 dv/uvm/formal/run_thermo5_dpd_identity_stall_fpv.py \
 --out-dir runs/identity_clean312 --timeout 360 \
 --vcf /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

New VCD diagnostic `tools/hw/thermo5_cdc_counterexample.py` exports only selected
signal transitions, reset observations and bounded status pulses, preserving
native waveform hashes. It always emits OPEN, never a waiver/PASS. Missing or
unknown reset signals cannot establish reset inactivity. Three focused utility
tests check pulse measurement, unknown/runtime reset and missing-reset cases.
All 70 utility tests complete successfully (one skipped).

Evidence is under `data/thermo5-cdc-debug/`: full native report comparison,
normalized counterexamples, audited identity proof, strengthened async proof,
and SHA256 manifest. Raw waves/tool caches stay under ignored `runs/`.
Existing VCS product/independent Oracle/reset-skew results remain those recorded
in the rootfix report; no new product RTL changed in this follow-up. XSim/XPM
remain NOT_RUN/unavailable. No claim of full CDC/RDC signoff is made.

## Remaining closure work

- Prove restart/prefill control tolerates delayed/missed short activity status,
  or design and validate an acknowledged status crossing with explicit timing.
- Establish the mixed FIFO/RUN/prefill convergence protocol under allowed
  synchronizer skew; no global Gray waiver.
- Prove full-depth FIFO fresh-epoch payload ownership, plus payload datahold.
- Complete arbitrary supported-coefficient DPD epoch noninterference and
  path-specific Gain/Config/Top RDC dispositions.
- Review physical synchronizer placement/MTBF and real parent reset release.

Outcome: targeted constraint and evidence defects fixed; remaining native
failures debugged and preserved. **CDC/RDC SIGNOFF OPEN**.
