# Live GTY regression report — 2026-11-18

Status **BLOCKED** for product signoff. Scoped live AXIS→product MASH→research prefill→dual GTY simulation passed for two finite frames and a reset/restart case. Vivado 2026.1, nominal 14.000 Gb/s per lane. See `docs/verification/vcu118_timing_live_20261117/live_axis_gty_integration.md` for source SHA, commands, detailed receiver results and preserved failed attempts.

| Scenario | Status | Evidence and scope |
|---|---|---|
| Unbuffered source bubbles | FAIL | `runs/live_axis_gty_02/`: underflow asserted despite matched payload |
| Single buffered long frame, STOP/drain | PASS | `runs/live_axis_gty_04/`: 5264 PA words; 336896 serial/RX bits per lane; no underflow |
| Reset during traffic and restart | PASS | `runs/live_reset_restart_01/`: common product/GT reset only |
| Two frames with STOP/restart | PASS | `runs/live_stop_restart_01/`: each 5264 words, matching serial/RX, zero simulated skew |
| Product-integrated prefill, continuous back-to-back long frames | NOT_RUN | single-bank research buffer introduces a between-frame gap and is not product RTL |
| Real epoch and independent reset | BLOCKED | epoch input is synthetic zero; product does not export it |
| Physical GT output / RF adjacent power | NOT_RUN | no board measurement |

On the actual simulated serial bits, the two frames respectively measure EVM 2.551442%/2.553836%, SNDR 31.864285/31.856141 dB, BER 15/37376 and 12/37376; combined digital Welch adjacent power -16.314892/-16.397680 dBc. These are digital results, not hardware ACLR. Overflow and underflow fault recovery are not comprehensively proven. Reproduce using `research/vcu118_arch/sim_live_axis_gty_axis_prefill.tcl`, `sim_live_stop_restart.tcl`, and `sim_live_reset_restart.tcl` with fresh output paths; verify all serial, RX and final status markers and absence of fatal messages.
