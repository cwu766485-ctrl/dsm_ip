# UVM Environment

`dsm_uvm_pkg.sv` assembles the verification package. The main components are:

- `dsm_uvm_reg_map.svh`: frozen AXI4-Lite byte-address register map.
- `dsm_uvm_config.svh`: SKU parameters and latency contract.
- `dsm_virtual_sequencer.svh`: handles for the active sequencers.
- `dsm_virtual_sequences.svh`: scenarios spanning control, TX, and observation.
- `dsm_uvm_scoreboard.svh`: transaction-order and RF-reference checks.
- `dsm_uvm_env.svh`: agent, monitor, scoreboard, and sequencer connections.

The memory-DPD pipeline has a fixed internal latency. The x32 interpolation
frontend is elastic, so end-to-end checks align transactions by valid/ready
order rather than a fixed cycle offset.
