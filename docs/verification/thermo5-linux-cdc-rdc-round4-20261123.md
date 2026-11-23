# Thermo5 CDC/RDC closure, Round 4 checkpoint — 2026-11-23

## Status

**OPEN.** The source baseline is `b2c364f`. This checkpoint contains an
experimental port-domain SGDC and an opt-in runner argument; the original SGDC
remains the default, and neither the product RTL nor its configuration changed.
No CDC/RDC finding was waived or closed. Existing raw reports remain under
`runs/linux_cdc_rdc_probe/`, `runs/linux_cdc_rdc_round2/` and
`runs/linux_cdc_rdc_round3/` in the separate worktree.

## CDC boundary model

`compiletime_product_ports_candidate.sgdc` proposes explicit functional clock
ownership for the AXI-Lite, AXIS and PA interfaces. It uses the local SpyGlass
`input -name ... -clock` and `output -name ... -clock` syntax. These are assumed
interface relationships, not parent-system electrical timing budgets. No
XPM `sync_cell`, Gray, mailbox `quasi_static`, blackbox, suppression or waiver
was added: these would need an independently reviewed protocol and instance
proof and must not be used merely to reduce reported errors.

The attempted EF1 XPM CDC run could not obtain a SpyGlass license and exited 4.
It did not elaborate the candidate, validate its port associations or produce
an after report. The candidate has since been corrected to classify the
AXI-Lite-domain `dsm_switch_busy` output with AXI-Lite outputs; it is constant
when `ENABLE_RUNTIME_DSM=0`. **The candidate remains unvalidated and is not
signoff SGDC.** It is not automatically loaded. Test it only after restoring
license service, check every SGDC setup warning and input/output association,
then run EF1 and MASH CDC/RDC with independent output directories.

The `runtime_idle` reconvergence reported in the Generic FIFO configuration
feeds `dsm_switch_idle` in the configuration block. Source inspection shows
this input is consumed by the architecture-switch state machine inside
`if (ENABLE_RUNTIME_DSM)` in `thermo5_dpd_axi_lite_cfg.sv`; the compile-time
product sets this parameter to zero. The DPD coefficient request, pending bank,
frame-boundary apply and ACK have separate logic. This is structural evidence
that the screenshot's suggestion that `runtime_idle` directly controls DPD
commit is unsupported; it is not yet a tool-elaborated, signed-off disposition
of the convergence finding or a proof of its behavior in runtime-enabled SKUs.

The XPM FWFT count needs a scoped proof. The installed vendor source implements
`rd_data_count` as a registered pointer difference plus `extra_words_fwft`.
A universal claim that it can never exceed instantaneous occupancy is not
established by inspection of this pipeline. The design only uses the threshold
for prefill; its control is `core_prefill_ready = fifo_rd_count >= 2`, and
`core_datapath_enable` also includes sticky prefill and drain conditions. Prove
the correct safety condition at startup, explicitly accounting for the first
possible read, reset-busy, synchronized pointer delay and FWFT buffering; do
not replace the counter or assume it conservative without a witness/proof.

## RDC evidence boundary

The retained exact-path CSVs reconcile 4,417 EF1 and 5,125 MASH errors. All
record a destination with `Reset: NULL`; 32 in each report instead label the
source as `Set` rather than `Reset` (for example a DPD coefficient bit). Source
location totals include 3,640 DPD paths in each and 780 MASH-backend paths in
MASH. Counts alone do not establish whether a crossing is safe. Pipeline valid,
coefficient epochs, frame/elastic metadata, retained history, DSM state and
vendor FIFO state need their own data-provenance and reset/restart checks. The
prior DPD formal result proves a valid-shift relation only and has a reset
setup issue; it does not prove numeric payload provenance.

## Attempted validation and next actions

The product-style `tb_cfg_common_reset_abort` was staged under
`runs/linux_cdc_rdc_round4/cfg_abort/` with `ENABLE_RUNTIME_DSM` changed from 1
to 0 in the *testbench copy*; product RTL was untouched. VCS could not obtain a
license, so compilation/simulation did not pass. Both failed logs are local in
`runs/linux_cdc_rdc_round4/`. There are no new CDC/RDC, VCS or formal PASS
results in this checkpoint.

With the license restored, rerun the SGDC candidate and the staged configuration
abort test, assess setup diagnostics and preserve full reports. Reconcile each
CDC error with proof or a narrowly reviewed instance disposition; prove the
prefill contract; classify and prove/reset-correct each RDC data/state cone;
then rerun both EF1/MASH product regressions and review physical constraints.
Never infer closure from tool exit status alone, a local reset synchronizer
smoke test, or raw report counts.

```sh
export THERMO5_CTIME_ROOT="$PWD" THERMO5_CTIME_ARCH=0
export THERMO5_CTIME_GOAL=cdc/cdc_verify
export THERMO5_CTIME_SGDC="$PWD/research/vcu118_arch/compiletime_product_ports_candidate.sgdc"
export THERMO5_CTIME_OUT="$PWD/runs/NEW_UNIQUE_PORTS_CDC"
export VIVADO_ROOT=/mnt/d/AMDDesignTools/2026.1
/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin/sg_shell \
  -tcl research/vcu118_arch/run_compiletime_spyglass.tcl
```

Use `rdc/rdc_verify_struct` and separate output directory for RDC, architecture
2 for MASH. Candidate SGDC SHA-256:
`f3a154f03d665e5179e722c71674c258d28aa08fd73bb4ac242050fb9ebf4733`.
No DE freeze or Linux signoff is claimed.
