# UVM Agents

`interfaces/` holds the virtual interfaces connected to the DUT:

- `dsm_axi_lite_if.sv`: AXI4-Lite control interface.
- `dsm_axis_if.sv`: TX and observation AXI4-Stream interface.
- `dsm_rf_if.sv`: RF output and debug observation interface.

Each protocol directory contains its transaction item, sequencer, driver,
monitor, agent, and protocol-specific sequences. AXI4-Lite and AXI4-Stream can
be active or passive. The current environment uses active AXI4-Lite, TX, and
observation agents; RF is passive.

Cross-protocol behavior belongs in `../env/` virtual sequences, not in an
individual agent.
