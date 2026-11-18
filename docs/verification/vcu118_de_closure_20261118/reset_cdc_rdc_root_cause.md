# Reset / CDC / RDC root cause — 2026-11-18

Run-start HEAD `267812fbbe9153f5cf3ce3eb7efafb80018aeb63`; Git worktree was clean. Existing successful and failed artifact SHA-256 inventory: `runs/de_closure_baseline_20261118_01/manifest.json`.

## Reset behavior and candidate

The previous specification required common reset, but this DE task additionally requires that an independent AXI-Lite reset cannot cause an old pending Core configuration to commit. Original configuration RTL fails that condition: `runs/cfg_independent_reset_epoch_01/witness.vcd` records old `0x1234` applying after AXI-Lite reset while Core remains alive. This is a real behavior under the newly requested independent-reset scenario.

Research candidate `research/vcu118_arch/thermo5_dpd_axi_lite_cfg_epoch_candidate.sv` asynchronously aborts the DPD configuration epoch when either reset asserts and synchronizes the epoch-reset release to Core. It gates pending data selection during reset. The candidate resets the active DPD configuration to default and also affects the configuration block's `run_sync` registers; these are behavior/latency changes requiring integration approval and verification. It does **not** repair or prove the separate runtime architecture-switch mailbox, GT/PA continuity, frame abort, or entire product reset tree. Do not call it a complete product fix.

`runs/de_independent_reset_candidate_01/` proves the previously failing directed witness no longer commits the old pending value, and a new `0x5678` configuration commits afterward. Candidate-specific formal `runs/de_independent_reset_candidate_formal_01/properties.txt`: 2 assertions proven non-vacuously, 2 covers, fixed-period formal clocks, reset setup check disabled. Assertions check reset-state clearing, not a complete no-stale transaction proof across all asynchronous phases. The isolated worktree `runs/de_epoch_candidate_sandbox/` substitutes this candidate into product AXI-Lite RTL and passed independent-Golden XSim `THERMO5_AXIL_CONFIG_BITTRUE_PASS` for 32 beats/56 words. That sandbox contains an intentional uncommitted candidate and is not the current branch's canonical product RTL.

## Structural classification

Raw Vivado routed `report_cdc` has 101 CDC-15 warnings: 99 DPD mailbox bits and 2 architecture mailbox bits. There are also 3 CDC-6 Gray-pointer and 2 CDC-26 LUTRAM collision warnings; 16 CDC-3 synchronized single-bit informational results. `cdc_structural_groups.csv` preserves all 122 rows by clock, rule and hierarchy. These classifications are not automatic waivers: handshake digital proof does not prove data skew, reset integration, metastability or FIFO collision safety.

SpyGlass Generic-FIFO/non-runtime frontend RDC report has 10,539 `Ar_resetcross01` errors; `rdc_structural_groups.csv` accounts for all 10,539 in 46 groups by reset domain, hierarchy and Q→D/EN type. The two biggest structural groups are Core-reset first/second cubic to unreset elastic/FIFO data (2,416 and 4,900 messages); interpretation of payload reset/valid gating remains OPEN. Five cross-domain source-reset→Core-reset reports correspond to the DPD mailbox. No group is waived; grouping does not prove benignness. Generic SpyGlass report and routed XPM Vivado report are different scopes, and cannot be numerically merged.

Reproduce clustering using `python3 research/vcu118_arch/cluster_de_cdc_rdc.py --rdc runs/cdc_rdc_generic_static_20261118_02/rdc/moresimple.rpt --cdc runs/ef1_vivado_cdc_audit_queue_01/reports/cdc_details.rpt --out runs/NEW_DIR`. Two earlier parser attempts produced incomplete output and are preserved; attempt 04 reconciles native counts with zero unparsed errors.
