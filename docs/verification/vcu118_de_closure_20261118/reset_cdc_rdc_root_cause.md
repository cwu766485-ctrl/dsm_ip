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

## Three output-clock-cone errors: structural analysis

In `research/vcu118_arch/tid32_thermo5_runtime_abort_candidate.sv`, all three external resets combine as `abort_arst_n`. `pa_valid` is asynchronously masked by that signal, while `source_epoch_aresetn` and `serializer_epoch_aresetn` combine it with local two-stage reset synchronizer outputs. SpyGlass reports the three primary outputs because unrelated reset sources appear in each output cone. The synchronizer stages implement asynchronous assertion and two local-edge deassertion, but the final combinational abort fan-in can propagate glitches and has no verified parent input pulse-width, isolation, physical PA-enable or recovery/removal contract. The output-error diagnosis is therefore **OPEN**, not an approved false positive or waiver. The minimum safe next action is to specify and verify reset-controller glitch/pulse behavior and destination release/PA mute in the parent system, then audit narrowly applicable timing treatment and rerun CDC/RDC and end-to-end reset tests. Do not change the asynchronous safety response without revalidating the user's active-frame abort contract.

## Reconciled Runtime RDC hierarchy triage

All 45,778 messages and 239 groups are accounted for by reproducible, mutually exclusive hierarchy buckets: MASH stage1-related 29,646/14 groups; interpolator2 FIFO-related 5,246/32; interpolator1 elastic-related 2,790/17; asynchronous FIFO-related 192/15; configuration other 1,840/80; backend other 2,673/53; other 3,391/28. These names indicate textual hierarchy membership only and are not proven root causes, safe dispositions or waivers. The input CSV retains source/destination reset, clock, rule and reason for each group. `python3 research/vcu118_arch/summarize_rdc_cones.py docs/verification/vcu118_de_closure_20261118/runtime_candidate_rdc_groups.csv runs/NEW_SUMMARY.json` reproduces this exact tally; it rejects unexpected group/message totals and refuses to overwrite its output.

## Reset-domain analysis refresh — resetdomains_02

The later SpyGlass V-2023.12-SP1 run in
`runs/abort_candidate_static_resetdomains_02/` reports 41,145
`Ar_resetcross01` messages in 202 hierarchy groups, all with tool reason
`Qualifier not found`; zero are waived. It is a Generic-FIFO Runtime candidate
run, not an XPM product signoff. Its disjoint hierarchy-name buckets are:

| Textual hierarchy bucket | Messages |
| --- | ---: |
| MASH state/enable reset fanout | 20,865 |
| Configuration/mode mailbox | 8,081 |
| Unreset FIFO/elastic payload boundary | 7,682 |
| DPD lane/state reset fanout | 3,442 |
| Other reset-domain paths | 1,075 |

The report also counts 31 structurally synchronized crossings, zero
unsynchronized scalar/vector crossings, zero `Clock_sync06` output-cone errors,
and zero setup-audit errors. This removes the earlier three PA-valid/epoch
output findings in this candidate configuration; parent reset glitch width,
physical PA mute and destination recovery remain unverified. CDC convergence
results still need functional review.

The RDC delta from the prior Generic Runtime report (45,778 messages / 239
groups) is −4,633 / −37. The analysis setup and reset-domain reconciliation
differ, so the delta is not evidence of RTL closure. The old 10,539-message
frontend-only report has a different top and remains incomparable. Every group
in the new `rdc_groups.csv` remains OPEN_REVIEW; no waiver or safe disposition
is approved. Reproduce the five text buckets by grouping the CSV message
counts after matching the source/destination hierarchy strings above; retain
the per-group CSV as the authoritative mapping.

## Candidate4 reset-boundary smoke — 2026-11-19 00:19 SGT

Icarus Verilog 12.0 PASSed a focused simulation of
`tid32_thermo5_runtime_abort_candidate_v4.sv` with the Generic FIFO parameter:
Core-only reset asynchronously aborts both stream/serializer epochs while
AXI-Lite AWREADY remains asserted, and both Core-only and AXI-Lite resets
release through the local synchronizers. This is a bounded reset-boundary
smoke, not a full active-traffic/frame-abort, pending-mailbox, AXI response,
CDC/RDC or GTY regression. Product reset signoff stays OPEN.

The first Icarus compile attempt is preserved in
`runs/de_v4_reset_contract_smoke_01/`; it stopped because Icarus does not
implement the existing `$stable()` SVA checks. The successful retry defines
`SYNTHESIS` to exclude those unsupported simulation assertions and is in
`runs/de_v4_reset_contract_smoke_02/`. Candidate source SHA-256 is
`db1f1783c0f238baf85944be5851fabf0dbf4bf88516504143b42487a4781ef5`, and
the testbench SHA-256 is
`28b8d0ec0006c6798fce69c8fb9901008be604e8b9e4da9522639b7f7e3a2bb5`.


## Independent-reset Formal v5 disposition — 2026-11-18 22:55 SGT

`runs/de_candidate3_independent_reset_formal_06/console_retry03.log` completed with 17/17 assertions proven, 20/20 non-vacuous goals and 6/6 covers. Seven lossless pending-bank atomicity slices all proved with `MAX_TAPS=4`, and a tap-change cover confirmed reachability. No assertion was weakened and no environment assumption was added. Exact clocks, assumptions, source SHA-256, limits and reproduction command are in `docs/verification/vcu118_de_closure_20261118/formal_disposition_20261118.md`.

This closes the scoped candidate mailbox digital proof only. It does not disposition the Runtime architecture mailbox, asynchronous reset output CDC, SpyGlass reset-domain groups, physical reset pulse/glitch behavior, routed timing or board PA mute. V4 had a vacuous final tap slice at `MAX_TAPS=1` and was stopped; both v4 and startup-failure evidence remain in their run directories.

## Routed synthesis timing root cause — 2026-11-18 23:37 SGT

The first current EF1 synthesis reports identify two different inter-clock
issues; they must not be collapsed into one generic CDC waiver. The
`−0.827 ns` path is recovery from `core_abort_sync/sync_q_reg[1]/C` to the
asynchronous `CLR` of `u_product/u_cdc/g_xpm_fifo.u_async_fifo/rd_reset_in_wr_reg[0]`
in the AXIS domain (0.720 ns data delay, −0.009 ns skew, 0.035 ns uncertainty,
6,994-load unplaced reset fanout). MASH A reports the same path at `−0.833 ns`.
The endpoint is the first local async-assert/sync-release reset guard stage;
the prepared exception is limited to CLR pins of the local reset guards, not
their D pins or either clock domain.

The independent worst mailbox path is `arch_mailbox_reg[0]/C` at `s_axil_aclk`
to `arch_pending_core_reg[0]/D` at `core_clk`: `−0.283 ns`, 0.276 ns data
delay, −0.008 ns skew, with 101 failing endpoints across coefficient and
runtime-mode bundles. Both bundles are held during their four-phase handshake.
Prepared constraints bound datapath delay and bus skew to one Core period; the
data buses are not false-pathed. Formal v5 proves the DPD pending bank on the
reset-epoch candidate; the separate mode mailbox lacks a completed formal
disposition. Formal v6 is prepared with source-hold, exact capture, pending
stability and apply-gating assertions plus architecture covers, but has not
run. Therefore the mailbox timing exception is not yet approved for use.

Full evidence and reproduction are in
`timing_root_cause_20261118.md`. Current EF1/MASH A/B implementations use Tcl
v3 and the original config RTL, so their eventual routed data is exploratory.
Corrected constraint/RTL candidates have SHA manifests in
`runs/de_resetfix_ppa_06/candidate3/`, but no routed result exists yet. The
current synthesis path findings do not close reset CDC/RDC, parent clock
timing, or product signoff.

## Runtime mode-mailbox Formal refresh — 2026-11-19 09:07 SGT

The independent-reset v7 harness passed all 25 assertions, all 28
non-vacuity goals, and all 11 covers. The v6-only non-convergence was caused
by a checker that sampled AXI-domain `arch_req_q` on `core_clk`; it treated a
legal post-AXI-reset write during Core reset recovery as stale. V7 samples the
Core-synchronized request `arch_req_c2` and requires request rise to follow an
accepted successful AXI-Lite architecture write. The source-side abort check
separately proves request/busy/ack clearing while the AXI reset epoch gate is
closed. No assumption was added and no assertion was weakened. The failed v6
run remains preserved. Full details, hashes and command are in
`formal_disposition_20261118.md`.

This closes the candidate3 block-level mailbox properties only. It does not
close the three historical output-cone Clock_sync06 findings, the 45,778
Generic Runtime RDC messages/239 groups, current-source SpyGlass, parent reset
glitch/pulse behavior, physical PA mute, or product-level CDC/RDC. No waivers
have been granted; those groups remain OPEN_REVIEW.

## Exact structural tally of the 45,778-message Runtime RDC run — 2026-11-19

Recomputed directly from `runtime_candidate_rdc_groups.csv` (239 rows): every
row is `Ar_resetcross01`, every tool reason is `Qualifier not found`, and every
disposition is `OPEN_REVIEW`. There are 137 Q→EN groups/36,439 messages and
102 Q→D groups/9,339 messages. Destination-reset/crossing buckets are:

| Destination reset | Crossing | Groups | Messages | Current evidence-based interpretation |
|---|---|---:|---:|---|
| `s_axis_aresetn` | Q→EN | 66 | 31,038 | Reset-domain enable gating; prove source-valid/enable isolation through reset release. |
| `NULL` | Q→D | 27 | 8,791 | Unreset payload/state capture; prove valid/occupancy prevents stale data use. |
| `NULL` | Q→EN | 55 | 5,346 | Unreset storage/control enable; inspect exact destination and reset-qualified write/read enable. |
| `s_axis_aresetn` | Q→D | 72 | 533 | Reset-domain state/data path; verify reset sequencing and whether captured value is consumed. |
| Other reset/set forms | Q→D or Q→EN | 19 | 70 | Low-count reset/set combinations; review each hierarchy row individually. |

The CSV also shows 232 groups in `core_clk`, four in `s_axil_aclk`, and three
in `s_axis_aclk`. This is a mechanism-level classification; it is not a claim
that all rows are safe or that they represent 239 independent RTL bugs. The
confirmed analyzer root cause is that SpyGlass could not prove the required
reset qualifier. A product root cause requires exact-source checks of FIFO
valid/occupancy, mailbox hold/commit, reset-release ordering, and data use.
No group was waived. The older 10,539-message run is frontend-only and used a
different top/scope; a numerical delta cannot show closure.


## Exact-source candidate4 SpyGlass rerun — 2026-11-19 11:16 SGT

Run: `runs/de_resetfix_spyglass_candidate4_04/`, SpyGlass V-2023.12-SP1,
`thermo5_ppa_top_v4`, candidate A midpoint cubic, reset/config candidate3,
frontend candidate3, Runtime abort wrapper v4, Generic FIFO (`FPGA_USE_XPM_FIFO=0`),
Core 218.75 MHz / AXIS 125 MHz / AXI-Lite 100 MHz. The Tcl and SGDC source
hashes are recorded in `source_sha256.txt`; no waivers were loaded.

- Setup: 0 errors, 23 warnings. CDC: 0 errors, 0 unsynchronized crossings,
  12 convergences, 0 waivers. The prior three output-cone `Clock_sync06`
  findings do not reproduce for these exact sources. This does not establish
  parent reset pulse/glitch width or physical PA mute.
- RDC: 17,895 `Ar_resetcross01` Errors, all `Qualifier not found`, 0 waived;
  plus 12 informational conventional multi-flop crossings. The native matrix
  and 17.9 MB report are preserved under `runs/de_resetfix_spyglass_candidate4_04/rdc/`.
- A reproducible-data triage grouped all 17,907 native rows into 86 normalized
  endpoint/reset signatures, preserved in
  `runs/de_resetfix_spyglass_candidate4_04/rdc_triage_02/structural_signatures.csv`.
  Textual buckets are MASH state/enable 5,754; Interpolator 2/FIFO payload
  5,105; DPD state/history 3,700; Interpolator 1 elastic payload 2,864;
  configuration/reset epoch 114; Generic asynchronous FIFO 179; and other
  frontend/control 191. All 86 signatures remain `OPEN_REVIEW`.
- The largest reset-pair bucket is `core_epoch_n -> NULL` (10,223), followed by
  `axil_epoch_n -> core_epoch_n` (2,460), `abort_arst_n -> axil_epoch_n`
  (2,194), `axil_epoch_n -> NULL` (1,665), and `abort_arst_n -> NULL`
  (1,205). `NULL` means SpyGlass did not identify a destination reset; it does
  not by itself prove stale data is consumed. FIFO payload and DPD history
  must be checked against reset-qualified valid/occupancy before any disposition.
- This candidate4 top/parameter/reset model is not numerically comparable to
  either the historical 45,778-message/239-group Runtime run or the earlier
  10,539-message frontend-only run. No RTL fix or waiver is inferred from the
  lower count.

Status: **CDC PASS for this exact static analysis scope; RDC FAIL / OPEN_REVIEW;
product reset/CDC signoff BLOCKED**. Reproduction:
`runs/de_resetfix_spyglass_candidate4_04/run.sh`; machine-readable tally:
`runs/de_resetfix_spyglass_candidate4_04/rdc_triage_02/summary.json`.

Reproduction uses:
python3 research/vcu118_arch/cluster_candidate4_rdc_csv.py --input runs/de_resetfix_spyglass_candidate4_04/rdc/abort_candidate4/thermo5_ppa_top_v4/rdc/rdc_verify_struct/spyglass_reports/clock-reset/Ar_resetcross01.csv --out runs/de_resetfix_spyglass_candidate4_04/rdc_triage_NEW

Parser SHA-256: 50354396cca54d753add8dfb7e78adf1e0f3f410e452be1627e92b09b2f74597.
