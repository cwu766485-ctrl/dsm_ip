# Live AXIS-to-GTY integration

Status: **PASS** for the bounded, single-frame digital live-chain test with the research AXIS frame-prefill candidate (attempt 04); **FAIL** for the original unbuffered bubble-stress test (attempts 01/02). Product integration, physical implementation and full reset/restart signoff remain **BLOCKED**. Source baseline `773983f29158edc8aff64aab5ce5fc7b54d15e6b` plus research testbench; Vivado 2026.1 build 6511674 and GT Wizard 14.000 Gb/s nominal raw mode.

`dv/verif/integration/vcu118_arch/tb_vcu118_live_axis_gty.sv` connects canonical runtime product RTL, AXIS input, AXI-Lite MASH selection, PA handshake and the research complete-frame buffer to two GTY TX/RX lanes. The GTY TXUSRCLK2 drives the core and buffer, avoiding an unmodeled clock boundary. It compares actual frontend/PA outputs and recovered GT serial bits against the preserved 5,264-word independent MASH golden. The test introduces source bubbles and STOP during an open frame; it checks frame markers, configuration ID, underflow and serial alignment. The buffer epoch input is synthetic zero because the product interface does not expose an epoch. A separate common-reset test covers reset while the first frame is in flight and a subsequent full-frame restart; independent resets and true hardware epoch remain open.

Live XSim attempt 01 checked 5,264 PA/prefill words but failed a combined status check before serial comparison (`runs/live_axis_gty_01/`). In attempt 02 the complete actual chain fed the GTY model, including source bubbles and STOP during frame. All 5,264 PA/prefill words matched the independent golden; both GTY serial TX and PMA loopback matched 336,896 bits per lane and observed skew was zero. The final status was `drain=1 underflow=1 protocol=0`, so the overall stress test **FAILS** (`runs/live_axis_gty_02/project/gty_sim.sim/sim_1/behav/xsim/simulate.log`). The serial-bit receiver gives EVM 2.551442%, SNDR 31.864285 dB, 15/37,376 uncoded errors (`runs/live_axis_gty_receiver_02/metrics.json`); the separate Welch PSD gives combined adjacent proxy -16.314892 dBc and lower/upper -19.254889/-19.396653 dBc (`runs/live_axis_gty_psd_02/`). This digital proxy is not RF ACLR.

The AXIS FIFO has 16 entries and starts after a two-beat prefill. Its nominal source capacity is 125 MHz × 14 = 1.75 Gsample/s, equal to the core consumption 218.75 MHz × 8 = 1.75 Gsample/s. Therefore sustained periodic input bubbles cannot be absorbed indefinitely by this finite FIFO; the observed flag cannot be dismissed merely because the post-MASH frame buffer reproduced the correct bitstream. The exact assertion cycle and whether any additional behavior contributes are still under investigation. A separate no-injected-bubble control (`sim_live_axis_gty_contiguous.tcl`, `runs/live_axis_gty_03/`) passed; it does not replace the failed stress case. Complete-frame output buffering alone does not remove the upstream underflow flag or prove an unlimited input-stall contract.

Attempt 03 with a contiguous source passed the live chain and STOP/drain with no underflow, but did not exercise the failing bubble pattern. Attempt 04 added the input frame-prefill candidate and re-ran that original bubble pattern: all 5,264 Golden PA/prefill words and 336,896 serial bits per lane passed; both lanes were aligned in simulation and PMA loopback passed. Final state was `drain=1 underflow=0 protocol=0`. Receiver on the actual serialized bits measured EVM 2.551442%, SNDR 31.864285 dB and 15/37,376 uncoded BER (`runs/live_axis_gty_receiver_04/metrics.json`). Welch combined adjacent proxy is -16.314892 dBc (`runs/live_axis_gty_psd_04/`); it is not hardware ACLR. The test also asserts STOP during the frame. Evidence is `runs/live_axis_gty_04/project/gty_sim.sim/sim_1/behav/xsim/simulate.log`.

A research-only single-bank input frame prefill candidate `research/vcu118_arch/thermo5_axis_frame_prefill.sv` collects up to 3,008 AXIS beats before replaying them to the product at the original AXIS clock. It aims to absorb this finite-frame bubble pattern before core consumption begins; it does not guarantee arbitrary-length frames, unbounded stalls or back-to-back throughput. Candidate `sim_live_axis_gty_axis_prefill.tcl` preserves the stressed source pattern and Golden and passed in `runs/live_axis_gty_04/` for this one finite frame. Independent unit tests passed source bubbles and output stall (`runs/axis_frame_prefill_unit_01/`), plus reset discarding a partial frame and oversized-frame fault (`runs/axis_frame_prefill_reset_01/`). Its storage is about 3,008 × (2 × 14 × 16 + 16 + 2) = 1,401,728 bits before implementation overhead; synthesis and PPA are NOT_RUN. It is not connected to the production top or the PPA cases.

The epoch input is synthetic zero because the product interface lacks an epoch output. Multi-frame STOP/restart without reset, independent resets and board-level alignment remain NOT_RUN. Execute with an unused output directory and explicit Vivado `bin` PATH. Require the final absence of fatal messages as well as the TX/RX bit-true markers; Vivado's `GTY_SIM_RUN_FINISHED` is not sufficient.

Prior separate PA replay evidence: `runs/gty_pa_replay_04/project/gty_sim.sim/sim_1/behav/xsim/simulate.log` and `runs/gty_serial_receiver_01/metrics.json`. Hardware RF and ACLR: **NOT_MEASURED**. Clock/reset/GTY board and PVT alignment remain open.

Reproduce the successful bounded stress test using a new output directory and Vivado 2026.1 on PATH:

```powershell
& 'D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat' -mode batch -source research/vcu118_arch/sim_live_axis_gty_axis_prefill.tcl -tclargs runs/live_axis_gty_NEW
```

Copy `serial_pa0.mem` and `serial_pa1.mem` from the XSim working directory to a fresh receiver directory as `phase1_arch2_pa0.mem` and `phase1_arch2_pa1.mem`; use the receiver and PSD commands in `docs/verification/vcu118_convergence_20261117/full_chain_gty_report.md`. Confirm the final drain status and absence of `Fatal:` as well as both serial markers.

`dv/verif/integration/vcu118_arch/tb_vcu118_live_reset_restart.sv` is a separate
research test that resets the real product and GTY while the first buffered
frame has delivered at least 100 PA words, then reconfigures MASH and checks a
complete fresh frame against the original Golden and both serial lanes. Its
script is `research/vcu118_arch/sim_live_reset_restart.tcl`. XSim attempt 01
passed: after reset during live traffic and GTY reinitialization, 5,264 Golden
PA words and 336,896 serial TX / PMA loopback bits per lane matched; drain=1,
underflow=0, protocol=0, observed lane skew 0 UI. The post-reset serial-bit
receiver again reports EVM 2.551442%, SNDR 31.864285 dB and BER 15/37,376.
Evidence: `runs/live_reset_restart_01/project/gty_sim.sim/sim_1/behav/xsim/simulate.log`
and `runs/live_reset_restart_receiver_01/metrics.json`. Scope: simultaneous
product/GTY reset, first frame interrupted after at least 100 PA words, one
following finite frame. Independent reset epochs and STOP/restart without reset
are not covered.
