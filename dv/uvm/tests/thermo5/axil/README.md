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

Graceful RUN stop has a separate `thermo5_sku_axil_graceful_stop_test`: it
prefills the 16-beat ingress FIFO, starts RUN, requests STOP mid-packet, then
checks all expected four-plane output words, inactive status after drain, and
no underflow/protocol error. The default 32-beat packet produces 56 words per
plane; running with `CORE_WORDS=112` exercises a 64-beat packet containing two
stop-safe quanta and compares all 112 words per plane against the MATLAB
oracle. The UVM source monitor checks that accepted `TLAST` remains stable
under backpressure and is observed exactly once for each valid packet.

`thermo5_sku_axil_stop_restart_test` adds the two-packet sequence required to
check a true restart without reset: STOP during packet 1, wait for all 56
four-plane words and drained-idle STATUS, confirm packet 2 stays blocked, then
reassert RUN and compare the complete 112-word stream. Run it with
`make -C dv/uvm/sim thermo5-axil-stop-restart-vcs-run` (the target generates
centered-cubic EF2 oracle vectors at order 2 / STEP 5120 by default; override
`THERMO5_STOP_RESTART_TIDSM_ORDER` and `THERMO5_STOP_RESTART_STEP` only for a
different candidate). The top-level
`thermo5-centered-cubic-ef2-vcs-regression` target includes this STOP/restart
case after the main candidate suite. The test was added on 2026-10-26; its first
runtime attempt did not start because the VCS vendor daemon was unavailable;
a three-minute license queue expired without a token, so it is not yet PASS
evidence. A 2026-10-27 retry generated the correct centered-cubic/order-2/
STEP=5120 vectors, but VCS again stopped before compilation with `Cannot find
license file`; runtime remains OPEN. The test samples a six-bin STOP/restart covergroup only after each
corresponding status, packet-boundary, blocked-source, and resumed-output
check has passed; it requires 100% event-bin coverage before reporting PASS.

Reproduce the two-quantum packet case with MATLAB vectors and the dedicated
Make target:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\uvm\sim\generate_thermo5_sku_vectors.ps1 -Words 112 -Seed 420112 -OutDir .\runs\thermo5_axil_tlast_112_vectors
```

```sh
make -C dv/uvm/sim thermo5-axil-long-frame-vcs-run \
  THERMO5_LONG_VECTORS="$PWD/runs/thermo5_axil_tlast_112_vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_axil_longframe_vcs"
```

The target compiles the AXI-Lite wrapper, runs the graceful-stop test with
`CORE_WORDS=112`, checks the 64 accepted source beats and 112 MATLAB-matched
four-plane output words, and requires zero UVM errors/fatals.

AXI-Lite protocol items, driver, monitor, agent, and access sequence remain in
their canonical `agent/` and `sequences/` directories. Standalone block
harnesses live at `dv/verif/block/axil/tb/`: one targets
request/pending/reset overlap tuples and one checks the illegal `MAX_TAPS`
parameter guard. The UVM tests here verify external bus protocol and, for the
integrated scenarios, control-to-datapath behavior.

CONTROL.RUN is a graceful stop request, not an immediate disable. The
AXI-Lite wrapper's `TLAST` packet length must be a positive multiple of 32
accepted source beats (32, 64, 96, ...). STOP finishes the active packet,
closes ingress, drains FIFO/gearbox/frontend/output, and keeps the GT-user
consumer active through the final four-plane word. An early `TLAST` sets the
sticky protocol diagnostic without resetting alignment or truncating the
stream. Poll STATUS.RUN_ACTIVE (bit 3) and STATUS.DRAINING (bit 4) until both
clear. Unexpected starvation before STOP remains a sticky underflow condition.

Run a focused VCS scenario after compiling with `THERMO5_USE_AXIL=1` by setting
`THERMO5_TESTNAME` to one of the classes below (the convenience targets are in
`dv/uvm/sim/Makefile`):

| Scenario | UVM test |
| --- | --- |
| Register map, AW/W skew, WSTRB, DECERR and response backpressure (no stream) | `thermo5_sku_axil_register_access_test` |
| Default commit/reset/full bit-true stream integration | `thermo5_sku_axil_config_test` |
| Mid-frame RUN clear, frame completion and graceful drain | `thermo5_sku_axil_graceful_stop_test` |
| STOP/drain, packet-boundary backpressure, no-reset RUN restart | `thermo5_sku_axil_stop_restart_test` |
| Coefficient mailbox transport with inactive taps | `thermo5_sku_axil_coeff_transport_test` |
| Non-identity image transport and application (not nonlinear arithmetic bit-true) | `thermo5_sku_axil_nonlinear_dpd_test` |
| Legal maximum tap-count identity | `thermo5_sku_axil_tap4_identity_test` |
| Commit phase relative to DPD frame boundary | `thermo5_sku_axil_boundary_phase_test` |
| Mailbox payload fault and reset recovery | `thermo5_sku_axil_mailbox_fault_test` |
| Illegal AXI frame and sticky-error reset recovery | `thermo5_sku_axil_illegal_frame_test` |

Run the dedicated generic or XPM regression with the
`thermo5-axil-vcs-regression` target from `dv/uvm/sim/Makefile`. A focused
register-only run is available as `thermo5-axil-register-access-vcs-run`.
