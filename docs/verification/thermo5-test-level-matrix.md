# Thermo5 Verification Test-Level Matrix

This matrix separates focused RTL blocks, the two thermo5 subsystems, and
end-to-end/system integration. A behavioral simulation PASS proves only the
listed digital contract; it does not by itself prove metastability safety,
physical GT operation, analog/RF quality, or board output.

## Verification hierarchy

In plain terms: a **block test** plugs stimulus into one RTL module and checks
that module's contract; a **subsystem test** checks several connected modules
working together; an **IP/system test** starts at the IP's external interfaces
and checks the complete path. A physical GT/board test is beyond those RTL
simulation scopes.

Therefore “GT digital-boundary block test” is not a subsystem level. It means
a small test of the one module that prepares four parallel 64-bit words for the
GT: it checks continuous consumption, idle output, and fault reporting. The
four-branch TID subsystem is tested separately. A behavioral serializer
loopback is a separate integration test, and it still does not instantiate the
physical GT.

```text
Block tests
  one cohesive RTL interface/function
       ↓
Subsystem tests
  (1) thermo5 frontend   (2) four-plane TID/Fs4 output backend
       ↓
IP/system integration
  complete AXI-Stream → four PA-code planes; optional AXI-Lite wrapper
       ↓
Physical boundary (not fully signed off)
  GT parent, serial RX/deskew, board and analog output
```

The block boundary is based on the DUT's public contract, not the number of
internal helper modules. In particular, `dsm_axis14_to_core8_cdc.sv` is one
AXI ingress block that internally combines the asynchronous FIFO and 14:8
gearbox.

## Block-level tests

| Block / RTL scope | Test and stimulus | Purpose | Expected/check result |
|---|---|---|---|
| AXI-Stream ingress + async FIFO + 14:8 gearbox (`dsm_axis14_to_core8_cdc.sv`; generic or XPM FIFO implementation) | `tb_dsm_axis14_to_core8_cdc.sv` / `_xpm.sv`; independent 125/218.75-MHz clocks, valid/frame metadata, reset, prefill and drain | Treat the externally visible CDC/repacking contract as one block; verify accepted beats cross in order and 14 source lanes become 8-lane core words | Exact I/Q and metadata ordering/count; no early underflow or protocol error. Generic and XPM are separate implementation runs. Simulation is not CDC/RDC signoff. |
| Frame-power controller and reset support (`dsm_frame_power_ctrl.sv`, `dsm_reset_sync.sv`, `dsm_xpm_async_fifo.sv`) | `tb_dsm_frame_power_ctrl.sv`, reset-release audit, `tb_dsm_xpm_async_fifo_reset.sv`; request/prefill/run/drain/idle and reset-release cases | Verify safe enable sequencing, local reset release and FIFO reset behavior | No start before prefill, no stop before drain, release after local clock edges, and no stale FIFO word. |
| Memory-polynomial DPD datapath (`dpd_memory_poly.v`, vector/elastic wrappers) | `tb_dpd_identity_exhaustive.sv`, `tb_dpd_memory_poly_bittrue.sv`, `tb_dpd_memory_poly_random_protocol.sv`; signed endpoints, MATLAB vectors and ready/valid stalls | Verify arithmetic, identity endpoints, transaction ordering and stall stability | Identity output and selected bit-true vectors match; no loss/duplication/reordering. Current thermo5 frozen SKU uses identity 1-tap; nonlinear control-image transport is not proof of nonlinear arithmetic correctness. |
| One x2 polyphase interpolator (`dsm_interp_x2_polyphase_vector.sv`) | `tb_interp_x2_vector_reachable.sv`; reachable values, valid bubbles and output backpressure | Verify FIR phase/order, fixed-point result, history and elastic protocol | Integer/MATLAB reference sequence matches, phase-0/phase-1 order is correct, and output is stable under stall. The RTL is a causal polyphase FIR: 2-tap `[1,1]/2`, 3-tap `[3,6,-1]/8`, or 4-tap `[5,15,-5,1]/16`; frozen SKU selects 2 taps. |
| One Cartesian TID32/Fs4 branch (`tid32_cartesian_fs4_gt_tx.sv`) | `tb_tid32_cartesian_fs4_gt_tx_bittrue.sv`; sequential 32-lane I/Q vectors | Verify a branch's recursive state, bit ordering and 64-bit packing | Ordered 64-bit words match the MATLAB bit-true model; transaction handshake preserves order. |
| Raw GT user-word boundary (`gt_tx_raw64_boundary.sv`, `gt_tx_user_bridge.sv`, and `thermo5_raw64_continuous_tx.sv`) | `tb_thermo5_raw64_continuous_tx.sv`; valid quartet, idle, link/run state, missing word, stop and plane disagreement | Verify digital user-word/continuous-transmit policy before the vendor GT primitive | Expected 256-bit bundle/idle word and sticky diagnostic behavior. It does not instantiate a GT primitive or test serial pins. |
| DPD AXI-Lite control/mailbox (`thermo5_dpd_axi_lite_cfg.sv`) | `dv/verif/block/axil/tb/thermo5_axil_cfg_coverage_tb.sv` for selected internal reset/request/pending overlaps; `thermo5_sku_axil_register_access_test` for external AXI-Lite pins without stream traffic | Verify the register/control-plane contract independently from DPD arithmetic | ID/read-only, STATUS/TAPS/coefficient registers, AW/W skew, WSTRB, error responses and response backpressure; internal mailbox corner tuples match the specified behavior. This is a control block, not the DPD arithmetic block. |

The AXI-Lite configuration block and the DPD datapath are distinct RTL blocks,
but they form one configured datapath when composed in the optional wrapper.
Register-only tests isolate bus/register behavior; integrated tests then check
configuration transfer and its effect at the datapath boundary.

## Subsystem tests

The subsystem taxonomy is intentionally limited to the two signal-processing
halves below. The full AXI ingress-to-output chain is reported separately as
IP-level integration, even though its testbench is kept beside the frontend
tests for source locality.

| Subsystem | DUT scope | Test and stimulus | Purpose / expected result |
|---|---|---|---|
| Thermo5 frontend | Frame gain, first x2 interpolation, DPD, second x2 interpolation and handoff into the four-plane output logic; the standalone core-word frontend test starts at 8 complex samples/word | `tb_tid32_thermo5_frontend_tx_bittrue.sv` is the 64-word oracle baseline; `tb_tid32_thermo5_frontend_tx_flow_control.sv` adds source bubbles, partial PA-ready windows, stall-stability checks and the same four-plane oracle | The dedicated flow-control test passed 64 words with 16 inserted bubble cycles and 28 observed stall cycles on 2026-10-18. Frozen configuration is 2-tap interpolation plus identity 1-tap DPD. Reset/replay remains an IP-level test. |
| Four-plane TID/Fs4 backend subsystem | Four offset Cartesian TID branches produce synchronized thermometric PA-code planes | `tb_tid32_thermo5_fs4_multipa_tx_bittrue.sv` is the 128-vector always-ready oracle baseline; `tb_tid32_thermo5_fs4_multipa_tx_backpressure.sv` adds source bubbles and per-plane ready stalls while retaining the oracle comparison | The dedicated backpressure test passed 128 vectors with 32 inserted bubble cycles and 86 observed stall cycles on 2026-10-18; all accepted quartets matched MATLAB and held stable while blocked. The adjacent raw64 bench is a separate block test. Neither test simulates physical GT. |

## IP and system integration tests

| Integration scope | Test and stimulus | What it establishes | What remains outside the result |
|---|---|---|---|
| Full thermo5 AXI-Stream chain, generic FIFO | `tb_thermo5_i2_d1_axis_bittrue.sv` and thermo5 UVM bit-true regression; 14-lane source beats, frame metadata, bubbles/stalls/reset, 56 output words or selected long stream | End-to-end ordering and MATLAB bit-true equality from AXI ingress through four output planes | Not physical CDC metastability analysis, GT serial validation or board/RF signoff. |
| Full thermo5 chain with XPM FIFO | Same external contract compiled with AMD/Xilinx XPM model sources | Checks that replacing the generic asynchronous FIFO preserves observed stream behavior | XPM functional simulation is not CDC/RDC signoff and does not model metastability. |
| Optional AXI-Lite thermo5 wrapper | Named UVM tests under `dv/uvm/tests/thermo5/axil/`; AXI-Lite agent plus AXI-Stream source, reset/control BFM, four-plane monitor and scoreboard | Legal commit, atomic mailbox transfer, frame-boundary apply, status/reset and bit-true output in identity-equivalent cases | Nonlinear image transfer is control-path evidence only; full nonlinear arithmetic oracle and system-level CDC/RDC remain open. |
| Behavioral serializer loopback | `tb_tid32_thermo5_frontend_serdes_loopback.sv`; 4 × 64-bit output words pass through a digital serializer/deserializer behavioral model | Reassembled user words preserve per-plane bit/word ordering across the modeled user/serial clock boundary | No generated GT Wizard, analog serial channel, CDR, physical RX or deskew is modeled. |
| GT parent/system integration | `tb_thermo5_qsfp_gt14_parent.sv` and parent implementation flow | Parent wiring, clock/reset integration and implementation diagnostics | RX user-clock recovery, four-lane RX word comparison, GT CDC-11, serial deskew, real I/O timing budgets and board output remain OPEN. |

## AXI-Lite UVM scenario separation

| UVM test | Isolated responsibility | Result interpretation |
|---|---|---|
| `thermo5_sku_axil_register_access_test` | Register map, AW/W independent timing, WSTRB, invalid accesses, response stalls and coefficient readback; no stream | AXI-Lite control-block protocol/register test |
| `thermo5_sku_axil_config_test` | Commit held to DPD boundary, busy rejection, PA stall, identity-equivalent stream, DONE/W1C and reset | Optional wrapper integration plus four-plane bit-true test |
| `thermo5_sku_axil_coeff_transport_test` | Legal coefficient image with inactive tap coefficients | Atomic mailbox payload transport and identity-stream check |
| `thermo5_sku_axil_tap4_identity_test` | Maximum tap-count selection with only tap 0 nonzero | Configuration boundary and identity bit-true check |
| `thermo5_sku_axil_nonlinear_dpd_test` | Non-identity image transferred/applied; 56 output handshakes and lane counters observed | Control-path evidence only; nonlinear arithmetic remains unverified against a matching oracle |
| `thermo5_sku_axil_boundary_phase_test` | Commit phase relative to a DPD frame boundary | Commit timing and identity bit-true behavior |
| `thermo5_sku_axil_mailbox_fault_test` | Deliberate pending-mailbox payload corruption followed by reset | Expected error detection/recovery for injected internal fault |
| `thermo5_sku_axil_illegal_frame_test` | Illegal AXI frame while run control is active, followed by reset | Expected protocol-error detection and recovery |

The generic AXI-Lite VCS regression and URG merge passed after the test split.
The register-only and default integrated tests were rerun on 2026-10-16; XPM
has not yet been rerun after this extraction. See the execution frontier for
the exact run, logs and remaining limitations.
