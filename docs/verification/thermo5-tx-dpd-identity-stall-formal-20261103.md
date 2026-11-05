# Thermo5 TX One-Tap Identity DPD Under-Stall Formal Evidence

Date: 2026-11-03 (Asia/Singapore)  
Status: `PASS_SCOPED_DPD_IDENTITY_OUTPUT_UNDER_STALL`  
Product RTL source SHA: `1236d49c72360aa62e316aea147528d93a1b3705`  
Formal run source commit: `e21c1ece205b633809e1dfd84d275936294b6378`

## Scope and contract

This proof instantiates production `dpd_memory_poly` with the Thermo5 one-tap
Identity image: `MAX_TAPS=1`, `USE_EXTERNAL_TAPS=1`, `active_taps=1`,
`c1_re=16384` (Q14 unity), and all other coefficient components zero. The same
input I/Q sample is supplied as the one-tap vector. Output backpressure is
unconstrained. The only environment assumption is the legal ready/valid source
rule: when `in_valid && !in_ready`, the source keeps `in_valid` and I/Q stable
for the following cycle. Reset is initialized by the VC Formal reset model
(`rst_n==1`).

The reference pipeline advances on the DUT's ready/valid pipeline enable. The
final properties require output I/Q to equal the corresponding source sample
at the 11-cycle pipeline latency, prove that a valid output never invokes
either saturation clamp, and prove `saturation_count` remains zero. Signed
minimum/maximum output, backpressure, and recovery are separately covered.

## Result

VC Formal V-2023.12-SP2 completed in 137.96 seconds of tool time (141.14
seconds measured by the runner). The base run proved all 41 internal
pipeline/Identity lemmas. Four final goals were INCONCLUSIVE in that run. The
Tcl flow checks every internal lemma is already proven before promoting exactly
those 41 assertions as compositional assumptions; it does not promote the four
final goals. In the composed run, all four final goals remain active assertions
and are PROVEN:

| Final property | Result |
|---|---|
| I output equals the 11-cycle reference when valid | PROVEN, non-vacuous |
| Q output equals the 11-cycle reference when valid | PROVEN, non-vacuous |
| No I/Q output saturation while valid | PROVEN |
| Saturation counter remains zero | PROVEN |

Both runs reach all four Covers: positive endpoint (depth 12), negative
endpoint (depth 12), output stall (depth 12), and stall recovery (depth 14).
The composed report contains exactly four active assertions and 43 constraints:
the 41 base-proven internal lemmas, the one source protocol assumption, and the
reset initialization constraint. The source assumption is non-vacuous. The
Formal setup report has zero clock, glitch, combinational-loop, and multi-driver
violations; the design has zero black boxes. The fail-closed auditor checks
these conditions, the exact property/Cover inventory, the clean source commit,
and all recorded hashes.

The full property matrix and artifact/source hashes are in the
[machine-readable evidence](data/thermo5-tx-dpd-identity-stall-formal-20261103.json).
Full logs and both property reports are retained in the ignored
`runs/thermo5_dpd_identity_stall_formal_20261103_rebased/` directory on the
execution machine.

## Product and signoff boundary

This closes the local one-tap Identity arithmetic, output alignment, and
saturation properties for the production DPD leaf under legal source
backpressure. It does **not** prove AXI shadow/COMMIT semantics, mailbox atomic
transfer, CDC, pending-to-active frame epoch timing, or composition with the
full TX chain. Those Gate 4.2 subproblems remain OPEN; outstanding-counter
guard convergence, remaining code coverage, waiver approval, and final Linux
TX signoff also remain OPEN.

Formal does not add simulator URG hits. No VCS regression or URG merge was
needed because this change only adds a Formal harness/flow and makes no RTL or
simulation-input change. Raw equals Adjusted and is unchanged: Branch 525/637,
Condition 658/849, Line 3351/3796, Toggle 84340/104480, FSM states 13/13,
transitions 17/22, and legal applicable Functional Coverage 392/392. There
are zero approved waivers and zero active exclusions; the code-coverage gate
remains `RAW_100_OPEN`.

## Reproduction

From the repository root with VC Formal V-2023.12-SP2 and a valid license:

```bash
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
python3.12 dv/uvm/formal/run_thermo5_dpd_identity_stall_fpv.py \
  --out-dir runs/thermo5_dpd_identity_stall_formal_replay \
  --evidence runs/thermo5_dpd_identity_stall_formal_replay/evidence.json \
  --vcf /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

The reference run used the same flow with output directory
`runs/thermo5_dpd_identity_stall_formal_20261103_rebased/` and tracked evidence
file `docs/verification/data/thermo5-tx-dpd-identity-stall-formal-20261103.json`.
The runner returns nonzero unless the base lemmas and all composed final goals
meet the exact expected results.
