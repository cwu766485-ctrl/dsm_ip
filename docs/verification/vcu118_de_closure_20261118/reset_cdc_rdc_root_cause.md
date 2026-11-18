# Reset / CDC / RDC root cause — 2026-11-18

Run-start HEAD `267812fbbe9153f5cf3ce3eb7efafb80018aeb63`; Git worktree was clean. Existing successful and failed artifact SHA-256 inventory: `runs/de_closure_baseline_20261118_01/manifest.json`.

## Reset behavior and candidate

The previous specification required common reset, but this DE task additionally requires that an independent AXI-Lite reset cannot cause an old pending Core configuration to commit. Original configuration RTL fails that condition: `runs/cfg_independent_reset_epoch_01/witness.vcd` records old `0x1234` applying after AXI-Lite reset while Core remains alive. This is a real behavior under the newly requested independent-reset scenario.

Research candidate `research/vcu118_arch/thermo5_dpd_axi_lite_cfg_epoch_candidate.sv` asynchronously aborts the DPD configuration epoch when either reset asserts and synchronizes the epoch-reset release to Core. It gates pending data selection during reset. The candidate resets the active DPD configuration to default and also affects the configuration block's `run_sync` registers; these are behavior/latency changes requiring integration approval and verification. It does **not** repair or prove Core-only reset while AXI-Lite stays live, the separate runtime architecture-switch mailbox, GT/PA continuity, frame abort, or entire product reset tree. A Core-only reset leaves a source-side request active: `runs/de_core_reset_candidate_witness_01/` reproduces the candidate replaying pre-reset `0x1234` after Core resumes, at 102871 ps. This is a failing candidate Reset Epoch behavior and requires a bidirectional abort/replay solution. Do not call it a complete product fix.

`runs/de_independent_reset_candidate_01/` proves the previously failing directed witness no longer commits the old pending value, and a new `0x5678` configuration commits afterward. Candidate-specific formal `runs/de_independent_reset_candidate_formal_01/properties.txt`: 2 assertions proven non-vacuously, 2 covers, fixed-period formal clocks, reset setup check disabled. Assertions check reset-state clearing, not a complete no-stale transaction proof across all asynchronous phases. The isolated worktree `runs/de_epoch_candidate_sandbox/` substitutes this candidate into product AXI-Lite RTL and passed independent-Golden XSim `THERMO5_AXIL_CONFIG_BITTRUE_PASS` for 32 beats/56 words. That sandbox contains an intentional uncommitted candidate and is not the current branch's canonical product RTL.

## Structural classification

Raw Vivado routed `report_cdc` has 101 CDC-15 warnings: 99 DPD mailbox bits and 2 architecture mailbox bits. There are also 3 CDC-6 Gray-pointer and 2 CDC-26 LUTRAM collision warnings; 16 CDC-3 synchronized single-bit informational results. `cdc_structural_groups.csv` preserves all 122 rows by clock, rule and hierarchy. These classifications are not automatic waivers: handshake digital proof does not prove data skew, reset integration, metastability or FIFO collision safety.

SpyGlass Generic-FIFO/non-runtime frontend RDC report has 10,539 `Ar_resetcross01` errors; `rdc_structural_groups.csv` accounts for all 10,539 in 46 groups by reset domain, hierarchy and Q→D/EN type. The two biggest structural groups are Core-reset first/second cubic to unreset elastic/FIFO data (2,416 and 4,900 messages); interpretation of payload reset/valid gating remains OPEN. Five cross-domain source-reset→Core-reset reports correspond to the DPD mailbox. No group is waived; grouping does not prove benignness. Generic SpyGlass report and routed XPM Vivado report are different scopes, and cannot be numerically merged.

Reproduce clustering using `python3 research/vcu118_arch/cluster_de_cdc_rdc.py --rdc runs/cdc_rdc_generic_static_20261118_02/rdc/moresimple.rpt --cdc runs/ef1_vivado_cdc_audit_queue_01/reports/cdc_details.rpt --out runs/NEW_DIR`. Two earlier parser attempts produced incomplete output and are preserved; attempt 04 reconciles native counts with zero unparsed errors.

## Reproducing reset witnesses

From the repository root, use a new empty working directory; retain the generated
VCDs. Icarus Verilog 12.0 commands (substitute the absolute repository path):

```bash
iverilog -g2012 -D SYNTHESIS -s tb_cfg_independent_reset_candidate -o simv \
  /ABS/REPO/rtl/axis/dsm_reset_sync.sv \
  /ABS/REPO/research/vcu118_arch/thermo5_dpd_axi_lite_cfg_epoch_candidate.sv \
  /ABS/REPO/research/vcu118_arch/tb_cfg_independent_reset_candidate.sv
vvp simv
# In a separate new working directory:
iverilog -g2012 -D SYNTHESIS -s tb_cfg_core_reset_candidate_witness -o simv \
  /ABS/REPO/rtl/axis/dsm_reset_sync.sv \
  /ABS/REPO/research/vcu118_arch/thermo5_dpd_axi_lite_cfg_epoch_candidate.sv \
  /ABS/REPO/research/vcu118_arch/tb_cfg_core_reset_candidate_witness.sv
vvp simv
```

The first is a limited candidate success; the second is an expected witness
of candidate failure, not a passing qualification. No production CDC/RDC
exception or product RTL fix has been accepted.


## Bidirectional epoch candidates after AXI response contract

The user selected AXI-Lite to remain live during independent Core reset. An
already-presented stalled B response must remain stable; a previously accepted
configuration request that later aborts is reported by sticky status. Candidate
2 adds a source-domain epoch guard, delays Core epoch release until the source
has processed the reset, cancels DPD/mode requests, and preserves the AXI
transport response. Scoped directed tests passed AXI-only and Core-only DPD
reset, a split AW/W interrupted write returning SLVERR, stalled B response
stability with sticky abort status, and pending mode abort/restart. An early
stalled-B test attempt returned SLVERR because it submitted before epoch release;
its failure is preserved in `runs/de_candidate2_b_stalled_01/`; the corrected
post-release case is `runs/de_candidate2_b_stalled_02/`. Candidate 2 fails
`runs/de_candidate2_mode_readback_01/`: after a prior MASH commit and Core
reset, active Core mode becomes EF2 but AXI-Lite readback remains MASH.

Candidate 3 resets source-side mode readback on a Core reset and passes six
directed tests in `runs/de_candidate3_directed_01/`, including that readback
case. However `runs/de_candidate3_axil_mode_witness_01/` shows AXI-Lite-only
reset changes the selected Core mode from MASH to EF2 while Core reset remains
deasserted. This is a real candidate behavior, and its effect on live PA
traffic/mode-switch safety has not been proven. Therefore candidate 3 is not
qualified, and no product RTL or PPA signoff is claimed. A safe implementation
must preserve or coordinate the active physical PA contract and resynchronize
AXI-Lite mode readback without allowing mixed epochs.

`runs/de_candidate3_axil_mode_active_witness_01/` additionally drives the
configuration block's `core_tx_active=1` during independent AXI-Lite reset:
`dsm_arch` immediately changes from MASH to EF2 with Core reset high. This is
a direct configuration-block witness while its active indication is asserted;
it does not by itself show a serialized PA waveform. Reset/frame/PA policy
remains a system-level choice and no candidate is promoted.

## Runtime candidate static follow-up (in progress)

`runs/abort_candidate_static_01/` runs SpyGlass V-2023.12-SP1 on the isolated
coordinated-reset Runtime candidate with the Generic FIFO and independently
declared AXI-Lite, source and Core clocks and resets. The source hash manifest
identifies the dirty sandbox candidate. Setup exited zero; structural CDC/RDC
results are pending and must be read from native reports, not inferred from
the process status. Run command: `wsl.exe -d Rocky-8.10 -- bash -ilc
/mnt/e/workspace/chip/dsm_ip/runs/thermo5_vcu118_arch_research/runs/abort_candidate_static_01/run.sh`
(use a new output directory for a repeat). No waivers have been approved.
The run scope differs from the historical frontend-only Generic RDC evidence.

## Coordinated-reset Runtime structural results

SpyGlass V-2023.12-SP1 completed all three goals in `runs/abort_candidate_static_01/`. The Runtime/Generic FIFO RDC goal reports **45,778 Ar_resetcross01 errors, 0 waived**; all messages reconcile into 239 structural groups in `runtime_candidate_rdc_groups.csv` (no unparsed rows). Large groups include EF1 bridge to MASH stage1 enable (8,448), EF2 bridge to MASH stage1 enable (8,448), second interpolator to unreset FIFO payload (4,922), and configuration to MASH stage1 enable (4,224). These are tool structural groupings, not established independent defects or safe crossings. The analyzer attributes parts of combined reset expressions to individual reset inputs; inspect actual reset cones and valid/enable behavior before disposition.

The CDC goal reports three `Clock_sync06` errors on `pa_valid[3:0]`, `serializer_epoch_aresetn`, and `source_epoch_aresetn`: asynchronous reset inputs appear in the output fan-in. The immediate abort/mute path is intentional in the research wrapper, but glitch behavior, reset deassertion, system isolation and physical PA connection are not proved. These remain OPEN; do not waive them. This Runtime scope includes EF1, EF2, MASH and candidate supervisor, whereas the earlier 10,539-message Generic run was frontend-only; counts do not measure improvement. Vivado XPM CDC is a separate scope.

Reproduce grouping into a **new** directory: `python3 research/vcu118_arch/cluster_runtime_candidate_rdc.py --rdc runs/abort_candidate_static_01/rdc/moresimple.rpt --cdc runs/ef1_vivado_cdc_audit_queue_01/reports/cdc_details.rpt --out runs/NEW_RUNTIME_GROUPS`. The CDC argument is the historical Vivado report and must not be mistaken for this Runtime SpyGlass CDC report. See `runs/abort_candidate_static_01/source_sha256.txt` for dirty sandbox source identities. No waiver or RTL signoff is implied.
