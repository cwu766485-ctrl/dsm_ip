# Thermo5 TX Fixed-Parameter Branch Audit

Date: 2026-10-31
Product source SHA: `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`
Audit scope: AXI-Lite product, Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120, `DPD_MAX_TAPS=1`, Generic FIFO.

## Result

Seventeen exact Raw URG Branch records are classified
`PROVEN_UNREACHABLE` by the fixed product's elaborated parameter chain. This is
a static source/configuration audit, not a VC Formal proof. The conclusion
applies only to the recorded product configuration and source hashes. Every
record remains in the Raw coverage denominator. No waiver or `.el` exclusion
was added, and no Raw VDB or URG report was changed.

The audit binds to the tracked product compile manifest
`docs/verification/data/thermo5-tx-product-compile-manifest.json` and the
13-test positive product witness
`docs/verification/data/thermo5-tx-cdc-resetready-evidence.json`. The compile
manifest records Centered-Cubic, AXI-Lite control, EF2 ORDER=2, STEP=5120,
`DPD_MAX_TAPS=1`, the `thermo5_sku_uvm_tb` top, and 77 source/control hashes.
The ten source files that carry the audited parameter chain are separately
hashed in the Formal review JSON and match both the compile manifest and the
active product witness.

## Exact Raw bins

| Semantic Bin ID | Source position | Product parameter fact | Result |
|---|---|---|---|
| `TXB-91d5b4a40917c980da7a` | `rtl/frontend/dsm_frame_gain_vector.sv:97` | `HOLD_STATE_ON_DISABLE=0` is the frontend default passed into the frame-gain instance. | `PROVEN_UNREACHABLE` |
| `TXB-6dcbab82b9fdc86cecc5` | `rtl/gt/gt_tx_user_bridge.sv:20` | Both bridge widths are tied to the same `DATA_W`. | `PROVEN_UNREACHABLE` |
| `TXB-2df3affe59cb2ae409d4` | `rtl/gt/gt_tx_user_bridge.sv:20` | Both bridge widths are tied to the same `DATA_W`. | `PROVEN_UNREACHABLE` |
| `TXB-2d576118dd5c1a6784cd` | `rtl/gt/gt_tx_user_bridge.sv:20` | Both bridge widths are tied to the same `DATA_W`. | `PROVEN_UNREACHABLE` |
| `TXB-cd475fde35a66be60e79` | `rtl/gt/gt_tx_user_bridge.sv:20` | Both bridge widths are tied to the same `DATA_W`. | `PROVEN_UNREACHABLE` |
| `TXB-054d97a87a8d74c36c8b` | `rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:348` | `MAX_TAPS=DPD_MAX_TAPS=1`, within the allowed range `[1,4]`. | `PROVEN_UNREACHABLE` |
| `TXB-32b923f55e34401249a8` | `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:210` | `HOLD_STATE_ON_DISABLE=0` is passed through to centered stage 2. | `PROVEN_UNREACHABLE` |
| `TXB-e381d5af8a96457cab44` | `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:294` | Centered stage 2 has `LANES=16`, so `LANES < 2` is false. | `PROVEN_UNREACHABLE` |
| `TXB-063113e1e4634f39c014` | `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:295` | `COEFF_FRAC` uses the module's Q14 default (`14`). | `PROVEN_UNREACHABLE` |
| `TXB-e8358208ee175c15bb7d` | `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:210` | `HOLD_STATE_ON_DISABLE=0` is passed through to centered stage 1. | `PROVEN_UNREACHABLE` |
| `TXB-e27080825871240f6ec3` | `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:294` | Centered stage 1 has `LANES=8`, so `LANES < 2` is false. | `PROVEN_UNREACHABLE` |
| `TXB-0fe97016b03e97cafb72` | `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:295` | `COEFF_FRAC` uses the module's Q14 default (`14`). | `PROVEN_UNREACHABLE` |
| `TXB-84be21fab6f11958312f` | `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:96` | EF2 receives `W=16`, `CHANNELS=32`; the width/even-channel guard is satisfied. | `PROVEN_UNREACHABLE` |
| `TXB-fa074bca34512589b54d` | `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:96` | EF2 receives `W=16`, `CHANNELS=32`; the width/even-channel guard is satisfied. | `PROVEN_UNREACHABLE` |
| `TXB-9fd36ae54068498e255f` | `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:96` | EF2 receives `W=16`, `CHANNELS=32`; the width/even-channel guard is satisfied. | `PROVEN_UNREACHABLE` |
| `TXB-70fb16ddca930f3fdb87` | `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:96` | EF2 receives `W=16`, `CHANNELS=32`; the width/even-channel guard is satisfied. | `PROVEN_UNREACHABLE` |
| `TXB-32e3753ea6b78b647658` | `rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:274` | `DPD_MAX_TAPS=1`, within the allowed range `[1,4]`. | `PROVEN_UNREACHABLE` |

Each ledger row also validates its Raw semantic ID, configuration, metric,
source position, exact Branch expression, decision path, normalized instance,
product source SHA, and source-file SHA. The audit fails closed if any mapping
or source parameter pass-through changes.

## Evidence and reproducibility

- Formal/static review: `docs/verification/data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-formal-review.json`
- Raw-preserving ledger: `docs/verification/data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-gap-ledger.csv.gz`
- Grouped closure tasks: `docs/verification/data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-closure-tasks.csv`
- Root-cause manifest and closure summary: `docs/verification/data/thermo5-tx-current-source-gaps/`
- Run/check logs and gate output: `runs/thermo5_tx_fixed_parameter_branch_audit_20261031_pr22/` (ignored local evidence; SHA/size index is tracked)

The static closure changes the audit statuses of 17 unhit Raw records; it does
not create simulator hits. Raw coverage remains Branch 520/637, Condition
601/849, Line 3334/3796, Toggle 83575/104480. Legal Functional Coverage
remains 210/210. The complete ledger has 372 `PROVEN_UNREACHABLE` records and
21,360 `OPEN` records; 108 of 470 grouped tasks are fully dispositioned and
362 remain `OPEN`. The fail-closed gate remains `RAW_100_OPEN`, with zero
waivers and zero exclusions.

The exact-source VCS/URG product run was reused because no product RTL, testbench
compile input, coverage input, or Raw VDB changed. The 13-test positive product
witness remains PASS for its original recorded source/configuration. This
review does not close reachable code gaps or constitute full TX signoff.
