# UVM Agents

`interfaces/` holds the virtual interfaces connected to the DUT:

- `dsm_axi_lite_if.sv`: AXI4-Lite control interface.
- `dsm_axis_if.sv`: TX and observation AXI4-Stream interface.
- `dsm_rf_if.sv`: RF output and debug observation interface.

Each protocol directory contains its transaction item, sequencer, driver,
monitor, agent, and protocol-specific sequences. AXI4-Lite and AXI4-Stream can
be active or passive. The current environment uses active AXI4-Lite, TX, and
observation agents; RF is passive.

Cross-protocol behavior belongs in `../sequences/` virtual sequences, not in an
individual agent.

The thermo5 subsystem has a separate active source agent: source item,
sequencer, driver, and accepted-beat monitor. The MATLAB-vector source
sequence lives in `../sequences/`; the driver owns pins but not vector files
or accepted counts. The four-plane PA-word monitor is passive. The older
AXI-IP environment's agents do not drive the thermo5 DUT.
