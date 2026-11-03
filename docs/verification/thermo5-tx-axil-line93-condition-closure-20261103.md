# Thermo5 TX AXI-Lite `write_fire` Condition — 2026-11-03

## Result

The exact Raw Condition bin `TXB-872eb98e51c3229e4c86`
(`13d6754bf69d80bac0ac`) at
`rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:93` is
**PROVEN_UNREACHABLE**. The latest 247-test Raw URG report shows the
`write_fire` operand tuple `0/1/1` as Not Covered. That tuple means
`s_axil_bvalid=1` while both `(aw_pending || aw_take)` and
`(w_pending || w_take)` are true.

The focused harness instantiates the production AXI-Lite configuration RTL
with product `MAX_TAPS=1`. Its assertion proves that whenever BVALID is active,
the two write-channel terms cannot both be true. The assertion is explicitly
non-vacuous: VC Formal reached the BVALID response Cover. It also reached the
normal `write_fire` Cover; the exact `0/1/1` Cover is uncoverable. The harness
uses no environment assumptions. VC Formal reported zero black boxes and no
selected setup violations.

## Coverage and waiver treatment

This result changes the root-cause disposition only. The exact Raw Condition
bin remains Not Covered and in the denominator. It does not generate a URG hit,
an exclusion, or a waiver approval. The latest same-list Raw/Adjusted report
still uses one design VDB and 247 test VDBs; Condition is 658/849, Raw equals
Adjusted, approved waivers=0, and active exclusions=0. The gate remains
`RAW_100_OPEN`.

The complete Formal property table, source hashes, Raw report/VDB hashes, and
reproduction command are in
[`machine-readable evidence`](data/thermo5-tx-axil-line93-condition-formal-20261103.json).
The ignored VC Formal run is under
`runs/thermo5_axil_cfg_line93_formal_20261103/`.

Reproduce from the repository root:

```bash
THERMO5_FORMAL_REPO="$PWD" \
THERMO5_FORMAL_OUT="$PWD/runs/thermo5_axil_cfg_line93_formal_20261103" \
PATH="/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH" \
/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV \
  -f "$PWD/dv/uvm/formal/run_thermo5_axil_cfg_line93_fpv.tcl"

python3.12 tools/hw/audit_thermo5_axil_cfg_line93_fpv.py \
  --formal-dir runs/thermo5_axil_cfg_line93_formal_20261103 \
  --raw-html runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/coverage_247_round6_dual_urg/raw_urg/mod17.html \
  --raw-report-manifest runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/coverage_247_round6_dual_urg/report_manifest.json \
  --raw-vdb-manifest runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/coverage_247_round6_dual_urg/vdb_manifest.json \
  --output runs/thermo5_axil_cfg_line93_formal_20261103/formal_audit.json
```

## Remaining work

This proof closes only the exact line-93 tuple root. The two outstanding
counter guard Branches, other Conditions and all remaining Line/Toggle roots,
full-chain DPD Identity Formal, and pending waiver reviews remain open. The
product RTL is unchanged.
