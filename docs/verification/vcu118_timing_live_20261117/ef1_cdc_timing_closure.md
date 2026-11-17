# EF1 CDC / timing closure

Status: **FAIL** overall OOC timing; **BLOCKED** on complete CDC/RDC and physical constraints. Source baseline `67d68abb402f9bb2c9a87a43a99f46955acfe9d9`; candidate RTL source `3f88efef965e2d5705adc57d06f530c265af2e82`. Vivado 2026.1 build 6511674, device xcvu9p-flga2104-2L-e. OOC is not physical Full Top.

The -0.363 ns worst setup path is `u_product/u_cfg/cfg_mailbox_q_reg[334]/C` to `u_product/u_cfg/cfg_pending_core_reg[334]/D`; launch `s_axil_aclk` 100 MHz, capture `core_clk` 218.75 MHz. These are independent clock inputs and Vivado reports `Unexpanded / No Common Clock / Timed (unsafe)`, not a demonstrated synchronous phase relationship. The reported chosen edge separation is 0.011 ns; cell delay 0.079 ns, net delay 0.276 ns, data delay 0.355 ns and clock skew -0.009 ns. Evidence: `../thermo5_vcu118_cubic_optimization/runs/optimized_ppa_ef1_01/ef1/setup_worst20.rpt`, same directory `hold_worst20.rpt` and `routed.dcp`. Core-only WNS +0.075 ns does not close overall WNS.

The RTL uses a four-phase bundled-data handshake: mailbox data is held while request is active, request crosses via two ASYNC_REG stages, destination captures into a pending bank and later acknowledges after a boundary. Scoped VC Formal with common reset proves source hold and destination capture equals sampled source; see `runs/mailbox_capture_formal_01/`. Sample-edge stability also proved: all 3 assertions and 3 covers passed non-vacuously, with zero black boxes. Reset is held released during proof. This is a digital model and does not prove metastability, independent resets, relative physical bus skew or a complete CDC/RDC contract.

A research-only 4 ns `set_max_delay` on mailbox source/destination register cells is prepared in `research/vcu118_arch/reimplement_ef1_cdc_bound.tcl` and `research/vcu118_arch/run_ppa_ef1_cdc_bound.tcl`. Two request synchronization stages plus a subsequent capture edge provide a multi-edge logical settling interval; 4 ns is below one nominal core period and is a conservative trial bound, not an unqualified board constraint. The corrected experiment omits `-datapath_only`, preserving the default hold check; no explicit false path or multicycle is added. Unlike the previous attempt, it includes clock skew and is not itself proof of correct asynchronous constraints. Attempt `runs/ef1_cdc_candidate_preempt_01/` used Q-pin startpoints and emitted `Constraints 18-515` path-segmentation Critical Warnings; it was stopped and is INVALID. Its wrapper exit code 0 is unreliable, as documented in `validation.json`. Attempt `runs/ef1_cdc_candidate_preempt_02/` avoided segmentation but used `-datapath_only`; AMD UG903 states this implicitly makes the same paths false for hold. Since physical/reset justification is incomplete, this attempt was stopped and marked INVALID. The experiment is **BLOCKED / running** in `runs/ef1_cdc_candidate_preempt_03/`, starting from the prior identical candidate synthesized DCP SHA-256 `4a8395da27c18f4405e9ef2891025ab3765ec82a092f3198fc44aebe3c12ceac`, until completed reports exist; source stability, endpoint selection, physical CDC review and unrelated crossing paths remain mandatory. The run uses `research/vcu118_arch/preempt_ef1_candidate.py`, which temporarily suspends the existing Runtime implementation and resumes it in a finally block; an independent watchdog also resumes Runtime if the controller exits unexpectedly. Each output directory is new. The resulting OOC implementation cannot by itself establish system CDC signoff.

Attempt 02 selected 99 source and 99 destination cells without path segmentation, but the report's `max_dpo=4` implicitly suppresses hold analysis on those paths. Do not use its hold result for signoff. Attempt 03 removes `-datapath_only`; confirm its exception coverage, hold checks and path selection in the fresh reports. This is not yet a routed timing result. Reproduce from the preserved synthesized DCP
using a fresh destination (run from an isolated Vivado working directory to
avoid overwriting its automatic log/journal):

```powershell
& 'D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat' -mode batch -source research/vcu118_arch/reimplement_ef1_cdc_bound.tcl -tclargs ef1 runs/NEW_EF1_CDC_BOUND a
```

The checkpoint restores a non-default `synth.maxThreads` property; the fresh
Vivado session reports that configuration mismatch when opening it. The netlist
is already synthesized, but the implementation and its warning require review.

AMD documentation: https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Consequences-of-Setting-Maximum-Delay-or-Minimum-Delay-Constraints-on-a-Path

Attempt 03's **pre-place** timing summary shows overall WNS -0.694 ns on a
recovery path from `core_aresetn` (modeled relative to `core_clk`) to the XPM
FIFO write-domain `rd_reset_in_wr_reg[0]/CLR` checked against `s_axis_aclk`.
This is a reset-domain path in `**async_default**`, not mailbox payload setup.
The reset relationship and release circuit need RDC and system-level review;
no false path or implicit hold waiver was accepted. See
`runs/ef1_cdc_candidate_preempt_03/implementation/synth_timing_summary.rpt`.
The implementation is still running, so this is not the final routed WNS.
