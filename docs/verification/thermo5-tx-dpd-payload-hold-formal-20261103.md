# Thermo5 TX DPD Vector Payload Hold Formal Evidence

Date: 2026-11-03 (Asia/Singapore)
Status: `PASS_SCOPED_DPD_VECTOR_STALL_HOLD`
Product RTL source SHA: `1236d49c72360aa62e316aea147528d93a1b3705`
Formal-input commit: `5b40881256444bcc6f88d0959a8af7336a776ca7`

## Scope

The proof elaborates `dpd_vector16_memory_poly` with `W=16`, `LANES=16`,
`COEFF_W=16`, `COEFF_FRAC=14`, and `MAX_TAPS=1`, matching the product
vector shape and maximum tap parameter. Runtime `active_taps`, coefficient
inputs, metadata, sample payload, `in_valid`, and `out_ready` are unconstrained.
The only Formal constraint is reset initialization (`rst_n==1`); the harness
contains no environment assumptions.

The original aggregate payload stability property did not converge as one
512-bit proof cone: a prior attempt was INCONCLUSIVE at depth 15, and a later
aggregate run reached depth 294 but remained INCONCLUSIVE. This harness splits
that same output-hold claim into 16 lane properties. Each property checks the
16-bit I and 16-bit Q sample for one lane. Together the 16 lane checks cover
all 512 payload bits. An additional metadata property and 16 lane-valid
lockstep properties ensure the full vector's control alignment.

## Result

VC Formal V-2023.12-SP2 completed in 102.63 seconds. All 33 assertions are
proven; all 17 output-payload/metadata assertions are reported non-vacuous.
All three Covers are reached: input acceptance at depth 1, output stall at
depth 12, and stall release at depth 13. There are zero black-box instances,
zero environment assumptions, one reset initialization constraint, and zero
selected setup violations. The source-bound fail-closed auditor reports
`PASS_SCOPED_DPD_VECTOR_STALL_HOLD`.

The 16 lane payload properties are exactly the bit partition of the 512-bit
I/Q output bus. Together with metadata stability and lane-valid lockstep, this
proves the DPD vector leaf's ready/valid payload-hold protocol under arbitrary
stalling. It does **not** prove the DPD arithmetic computes the Identity
function, the AXI-Lite COMMIT/CDC/active-epoch sequence, or full-chain TX
equivalence. The broader DPD Identity goal remains OPEN/INCONCLUSIVE.

## Coverage and signoff impact

No product RTL, algorithm, test VDB, or Raw URG report changed. Raw and
Adjusted remain Branch 525/637, Condition 658/849, Line 3351/3796, Toggle
84340/104480, FSM states 13/13 and transitions 17/22, and legal applicable
Functional Coverage 392/392. Approved waivers and active exclusions remain
zero. The gate remains `RAW_100_OPEN`; the Formal proof does not create an URG
hit or remove a Raw bin.

## Reproduction

From the repository root, with VC Formal V-2023.12-SP2 installed and licensed:

```sh
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
python3.12 dv/uvm/formal/run_thermo5_dpd_payload_hold_fpv.py \
  --out-dir runs/thermo5_dpd_payload_hold_formal_20261103_replay \
  --vcf /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

The checked run used the same command shape with output directory
`runs/thermo5_dpd_payload_hold_formal_20261103`; exit code was 0 and the
fail-closed audit had no errors. Exact `properties.txt`, `setup.txt`,
`engines.txt`, `vcf.log`, command and artifact SHA-256 values are retained
under ignored `runs/thermo5_dpd_payload_hold_formal_20261103/` and indexed in
[`machine-readable evidence`](data/thermo5-tx-dpd-payload-hold-formal-20261103.json).

The lane-split harness is a verification decomposition only; it does not alter
the RTL. VCS and URG were not rerun because neither simulation sources nor
VDB inputs changed. Full-chain DPD Identity, outstanding-counter guards,
remaining Raw code bins, pending waiver review, vendor XPM/GT Wizard, FPGA
PPA, and physical RF/QAM256 validation remain open.
