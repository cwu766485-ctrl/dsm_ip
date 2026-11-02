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

The thermo5 subsystem has four control boundaries:

- AXIS source agent: active source sequencer/driver and accepted-beat monitor.
- AXI-Lite agent: active register-transaction sequencer/driver/monitor when
  the AXI-Lite product wrapper is compiled.
- PA sink agent: configurable active/passive agent. Its active driver is the
  sole procedural owner of the four `PA_READY` bits; tests request readiness
  through `env.pa_sink.set_ready()`. Its PA monitor remains passive and is
  also exposed as `env.monitor` for existing scoreboards and coverage.
  When configured passive, the enclosing testbench must provide and initialize
  the external `PA_READY` driver.
- Control agent: owns the shared reset and the direct-core `core_enable`
  control used by the non-AXI wrapper. AXI-Lite RUN/STOP remains owned by the
  AXI-Lite agent.

The MATLAB-vector source sequence lives in `../sequences/`; the source driver
owns pins but not vector files or accepted counts. Cross-agent lifecycle
scenarios live in `../sequences/thermo5/`. The older AXI-IP environment's
agents do not drive the thermo5 DUT.
