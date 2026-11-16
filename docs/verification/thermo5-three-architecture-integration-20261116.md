# Thermo5 Three-Architecture Integration

Branch: `work/vcu118-integration`  
Base/product evidence SHA: `97733eb27674b7737ea21a2252fca45ecac13a26`

## Frozen Baselines

The existing EF1 Pipeline routed DCPs and the independent Weighted MASH routed
DCP are unchanged. Their hashes remain:

- EF1 Explore: `1f5cd3c950c8da8b1a2781b7d788fd0c09f307549836aedb0098e6a645a9088f`
- EF1 RuntimeOptimized: `e694a728b7523a50d65683314d957316ef716dd6f63c2cffb0457cad42fe8173`
- Weighted MASH OOC: `c05907c1e4b6937077087da85d7a2acad64d492df1898e19679fd7a598a2c4f0`

## Block Diagram and Contracts

```text
AXI-Stream source
  -> source CDC / 14:8 gearbox
  -> frame gain -> Cubic 1 -> DPD -> Cubic 2
  -> 32-lane Pre-DSM boundary FIFO
       |-> EF1 backend -> four equal-weight PA planes
       |-> EF2 backend -> four equal-weight PA planes
       `-> MASH adapter -> two 1:2 weighted PA planes
```

The existing `u_interp2_to_tid_fifo` is a two-entry registered FIFO with
`META_W=1`, driven by constant zero metadata. Therefore it carries only the
32-lane I/Q payload; Frame Start/End, Tail, Config ID and Reset Epoch do not
cross this boundary. This integration branch does not reconstruct them from
timing. A production shared boundary must widen the metadata contract before
MASH integration.

The architecture and PA contracts are declared in
`research/thermo5_integration/rtl/thermo5_arch_contract.sv` and mirrored for
UVM configuration in `dv/uvm/env/thermo5/thermo5_arch_contract.svh`:

| Architecture | PA contract | Current status |
|---|---|---|
| `DSM_ARCH_EF1` | four equal-weight planes | existing product baseline |
| `DSM_ARCH_EF2` | four equal-weight planes | research/product verification path |
| `DSM_ARCH_MASH11` | two weighted 1:2 planes | independent integration candidate |

The PA contract is compile-time configuration, not a run-time DSM switch.

## MASH Adapter Result

`thermo5_weighted_mash_backend_adapter.sv` adds a bounded credit-based output
store and carries Config ID, Epoch, Frame Start/End and Tail alongside the two
MASH PA words. It reserves `FIFO_DEPTH + CORE_LATENCY + 2` transaction credits
because the historical core has no output-ready port. The module stops new
input acceptance before the bounded store can overflow and raises
`overflow_error` if its assumptions are violated.

The module-level test was run with Icarus Verilog 12.0:

```bash
cd research/thermo5_integration/verif/tb
iverilog -g2012 -s tb_weighted_mash_backend_adapter -o adapter2.vvp \
  ../../../thermo5_weighted_mash/rtl/gt/gt_tx_user_bridge.sv \
  ../../../thermo5_weighted_mash/rtl/gt/gt_tx_raw64_boundary.sv \
  ../../../thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv \
  ../../../thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_mash11_fs4_multipa_tx.sv \
  ../../rtl/thermo5_arch_contract.sv \
  ../../rtl/thermo5_weighted_mash_backend_adapter.sv \
  tb_weighted_mash_backend_adapter.sv
vvp adapter2.vvp
```

Observed marker: `THERMO5_MASH_ADAPTER_PASS accepted=128 produced=128 II=1
bounded_fifo=16`. This proves the bounded adapter transaction behavior only;
it is not a full AXI-Stream product integration or arbitrary-long-stall proof.

## UVM Reuse

`thermo5_sku_config` now carries `dsm_arch`, `pa_contract`, MASH core latency,
FIFO depth and bounded-backpressure intent. A MASH transaction type is defined
separately from the existing four-plane `thermo5_pa_word`; the existing
four-plane monitor and scoreboard are unchanged. A dedicated MASH monitor,
backend oracle and full-chain top are still required before claiming a unified
UVM PASS. The independent MATLAB/Icarus MASH oracle remains the source of
expected PA bits; no DUT observation is used to create expected data.

## Gate Status

- Gate 0: PASS for audit/freeze; existing DCP/log/vector evidence preserved.
- Gate 1: PARTIAL. Shared payload boundary identified; metadata loss prevents
  product integration until an explicit widened contract is implemented.
- Gate 2: PASS as a compile-time contract declaration; no product top switch was
  added.
- Gate 3: PASS for bounded module adapter; arbitrary long backpressure and
  STOP/Restart remain OPEN.
- Gate 4: PARTIAL. Reusable configuration and MASH transaction type added;
  dedicated monitor/oracle/full UVM integration remain OPEN.
- Gates 5-6: OPEN. No full-chain MASH top or full-top VCU118 PPA was run.

No existing EF1 RTL, four-plane PA contract, or frozen PPA artifact was changed.
