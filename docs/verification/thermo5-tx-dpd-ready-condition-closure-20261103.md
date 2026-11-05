# Thermo5 TX DPD Ready/Valid Condition Reachability — 2026-11-03

## Result

The exact Raw Condition bin `TXB-33613a1855fcc02e8ef4` (`ecc391f634f890dbadb6`)
at `rtl/dpd/dpd_vector16_memory_poly.sv:93` is **PROVEN_UNREACHABLE** under the
Thermo5 product configuration. The URG expression is
`in_ready || !out_valid`; its unhit operand tuple is `0/1`. The Formal Cover
for the tuple, `!in_ready && !out_valid`, is `uncoverable`.

The product instance is
`thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd`, with W=16,
LANES=16, MAX_TAPS=1, COEFF_W=16, and COEFF_FRAC=14. The focused harness
instantiates the same `dpd_vector16_memory_poly` implementation and parameters.
In its child lane, `in_ready = out_ready || !out_valid`; therefore the exact
tuple `in_ready=0, !out_valid=1` cannot occur. No environment assumptions were
added. This proof concerns the ready/valid relation only; it is not an
arithmetic or whole-transmitter equivalence proof.

The run proved `!out_valid -> in_ready` non-vacuously, reached legal input
accept, output transfer, output stall, and stall-release Covers, and marked the
exact tuple Cover uncoverable. Setup checks reported no violations and the
design had zero black boxes. The additional 512-bit output-payload hold
assertion was inconclusive at depth 15; it remains a separate OPEN proof item
and is not used to disposition the line-93 Condition bin.

## Coverage and waiver treatment

The latest Raw URG report still shows line 93 operands `0/1` as Not Covered.
This Formal result does not alter Raw or Adjusted URG scores, remove a bin, or
change a denominator. Raw Condition remains 658/849, Adjusted equals Raw, and
the overall gate remains `RAW_100_OPEN`. The bin is recorded as
`PROVEN_UNREACHABLE` for root-cause accounting only. It remains in Raw and no
waiver or `.el` exclusion is requested or activated.

Evidence is bound in
[`thermo5-tx-dpd-ready-condition-formal-20261103.json`](data/thermo5-tx-dpd-ready-condition-formal-20261103.json).
The ignored VC Formal directory is `runs/thermo5_dpd_vector_ready_formal_20261103/`.
Run the proof from the repository root with:

```bash
THERMO5_FORMAL_REPO="$PWD" \
THERMO5_FORMAL_OUT="$PWD/runs/thermo5_dpd_vector_ready_formal_20261103" \
PATH="/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH" \
/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV \
  -f "$PWD/dv/uvm/formal/run_thermo5_dpd_vector_ready_fpv.tcl"
```

The output parser and fail-closed target audit are:

```bash
python3.12 tools/hw/audit_thermo5_dpd_vector_ready_formal.py \
  --formal-dir runs/thermo5_dpd_vector_ready_formal_20261103 \
  --output runs/thermo5_dpd_vector_ready_formal_20261103/formal_audit.json
```

## Remaining closure work

This exact Condition root is resolved by reachability evidence, not by a
coverage hit. The other current Condition/Branch/Line/Toggle roots, both
outstanding-counter guard Branches, full-chain DPD Identity, the remaining
waiver reviews, and all physical/XPM/GT signoff remain separate OPEN work.
