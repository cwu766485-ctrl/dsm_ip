# Thermo5 Block Verification

Block tests isolate arithmetic and local ready/valid/reset behavior before
subsystem integration. Each testbench is stored under its block's `tb/`
directory. The canonical thermo5 blocks in this branch are:

| Block | DUT scope | Testbench/runner |
|---|---|---|
| AXI/FIFO | 14:8 async FIFO/gearbox, reset, frame-power control | `axis/tb/`; `dv/verif/scripts/run_xsim_axis14_to_core8_cdc*.ps1`, `run_xsim_frame_power_ctrl.ps1`, `run_xsim_xpm_async_fifo_reset.ps1`, `axis/run_xsim_thermo5_reset_sync_release_audit.ps1` |
| DPD | identity and memory-polynomial datapath boundaries | `dpd/tb/`; `dpd/run_identity_exhaustive_vcs.sh`, `dpd/run_memory_poly_random_vcs.sh` |
| Interpolation | reachable x2 vector interpolation and backpressure | `interp/tb/`; `dv/verif/scripts/run_xsim_interp2_reachable.ps1` |
| TID32 | one Cartesian Fs/4 modulator and raw-word handshake | `tid32/tb/`; `dv/verif/scripts/run_xsim_tid32_cartesian_fs4_gt_tx.ps1` |
| GT user boundary | continuous raw-word source behavior | `gt/tb/`; `dv/verif/scripts/run_xsim_thermo5_raw64_continuous_tx.ps1` |
| AXI-Lite DPD configuration control | register/mailbox behavior, distinct from DPD arithmetic | `dv/uvm/tests/thermo5/axil/`; standalone internal corner harness under `dv/uvm/tb/` |

Generated simulator products are disposable and belong under ignored `runs/`,
not beside RTL or test sources. See `BLOCK_SIGNOFF.md` for scope boundaries
and `../RUN_REGRESSION.md` for command examples.
