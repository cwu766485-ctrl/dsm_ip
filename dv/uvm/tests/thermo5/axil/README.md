# Thermo5 AXI-Lite Wrapper Tests

This directory contains tests for the optional
`tid32_thermo5_axi_lite_axis_frontend_tx` wrapper. The frozen parallel-config
thermo5 SKU is a separate DUT target and does not use these tests.

Common AXI-Lite helpers live in `thermo5_sku_axil_config_test.svh` under the
shared `thermo5_sku_axil_base_test`. The base owns reusable access tasks and
configuration hooks. `thermo5_sku_axil_register_access_test.svh` is a focused
test and does not launch AXI-Stream traffic. The integrated tests focus on
configuration commit, DPD frame-boundary application, reset, PA stall, and the
four-plane scoreboard. Coefficient-image variants override only the
image/programming hooks. Negative, mailbox-fault, and boundary-phase scenarios
each have their own test class.

AXI-Lite protocol items, driver, monitor, agent, and access sequence remain in
their canonical `agent/` and `sequences/` directories. The standalone
configuration-register block test is `dv/uvm/tb/thermo5_axil_cfg_coverage_tb.sv`;
the UVM tests here verify the wrapper-integrated control and data path.

Run a focused VCS scenario after compiling with `THERMO5_USE_AXIL=1` by setting
`THERMO5_TESTNAME` to one of the classes below (the convenience targets are in
`dv/uvm/sim/Makefile`):

| Scenario | UVM test |
| --- | --- |
| Register map, AW/W skew, WSTRB, DECERR and response backpressure (no stream) | `thermo5_sku_axil_register_access_test` |
| Default commit/reset/full bit-true stream integration | `thermo5_sku_axil_config_test` |
| Coefficient mailbox transport with inactive taps | `thermo5_sku_axil_coeff_transport_test` |
| Non-identity image transport and application (not nonlinear arithmetic bit-true) | `thermo5_sku_axil_nonlinear_dpd_test` |
| Legal maximum tap-count identity | `thermo5_sku_axil_tap4_identity_test` |
| Commit phase relative to DPD frame boundary | `thermo5_sku_axil_boundary_phase_test` |
| Mailbox payload fault and reset recovery | `thermo5_sku_axil_mailbox_fault_test` |
| Illegal AXI frame and sticky-error reset recovery | `thermo5_sku_axil_illegal_frame_test` |

Run the dedicated generic or XPM regression with the
`thermo5-axil-vcs-regression` target from `dv/uvm/sim/Makefile`. A focused
register-only run is available as `thermo5-axil-register-access-vcs-run`.
