# Thermo5 TX Generic-FIFO `core_data_empty` Condition Formal Review

Date: 2026-11-03 (Asia/Singapore)

Disposition: `PROVEN_UNREACHABLE` for the Generic-FIFO product configuration.
The Raw URG bin remains present and unhit. No waiver is approved and no `.el`
exclusion is active. Product RTL and coverage denominators are unchanged.

## Exact Raw record

| Field | Value |
| --- | --- |
| Semantic Bin ID | `TXB-3b8b5df27b5b204fbb04` |
| Raw record ID | `43024ee4b07d2164b0a2` |
| DUT instance | `thermo5_sku_uvm_tb.dut.u_cdc` |
| Source | `rtl/axis/dsm_axis14_to_core8_cdc.sv:113` |
| Metric / bin | Condition / `0/1/1/1/1` |
| Configuration | 14:8 CDC, W=16, Generic FIFO (`USE_XPM_FIFO=0`), default FIFO depth/configuration |

The expression is `fifo_rd_empty && !fifo_rd_valid && (rem_count_q == 0) && !out_valid_q && !end_pending_q`.
The target operand tuple requires `fifo_rd_empty=0` and `fifo_rd_valid=0` at once. In the production Generic FIFO, `rd_valid = !rd_empty`; the CDC wires these outputs directly to `fifo_rd_valid` and `fifo_rd_empty`. Thus this tuple is impossible for this elaborated product configuration. This conclusion does not apply to XPM or another FIFO implementation.

The historical Raw ledger was built with product commit `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`. Its SHA-256 for this CDC RTL file is `f7a31ecb55cc5dff5280d8f48e28f2cad5b74d7b1b2b552bbefdabf83fc93f56`, identical at both the historical commit and frozen product RTL commit `1236d49c72360aa62e316aea147528d93a1b3705`. Raw VCS/URG was not refreshed in this Formal-only change, so no new Raw hit or coverage delta is claimed.

## Formal result

A new harness instantiates the production CDC and Generic FIFO RTL with a registered AXIS source. It does not force internal state. VC Formal uses independent source/core clocks at the exact scaled product ratio (14:8 period units), with only reset initialization (`rst_n==1`) constrained. The proof reached legal source acceptance, nonempty FIFO data and `core_data_empty` witnesses. It proved all three assertions, including two marked non-vacuous, and found the exact target Cover `uncoverable`.

- VC Formal V-2023.12-SP2: PASS, 26.26 seconds.
- Assertions: 3/3 proven; 2/3 non-vacuous.
- Covers: 3/4 reached; exact Raw tuple Cover is uncoverable.
- Selected setup violations: 0; black boxes: 0.
- No VCS/URG rerun; the RTL and VDB inputs did not change.

Reproduce from the repository root:

```sh
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs cdc_data_empty \
  --out-dir runs/thermo5_tx_closure_current/cdc_data_empty_formal_20261103_clean
```

The runner records the clean source commit, all formal input hashes, tool banner,
assertion/Cover inventory, setup report, and console log in its generated
`formal_summary.json`. Artifact SHA-256 values are in the adjacent evidence
JSON. Generated logs remain under ignored `runs/`.

## Coverage and waiver status

The retained same-list Raw/Adjusted snapshot is unchanged: Branch 525/637,
Condition 658/849, Line 3351/3796, Toggle 84340/104480, FSM states 13/13 and
transitions 17/22, legal Functional 392/392. There are zero approved waivers
and zero active exclusions; the gate remains `RAW_100_OPEN`.

This Formal result records an exact reachability disposition only. It does not
remove the Raw record, alter the denominator, approve a waiver, or create an URG
hit. Independent waiver review remains required.
