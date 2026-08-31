# Update Log

## 2026-08-26 - BP EFDSM2 Claim-Boundary Correction

- Compared the binary BP single-loop and BP EFDSM2 modulators at the common
  behavioral switching-DPA, finite-Q analog RLC-BPF, and coherent-receiver
  endpoint over input backoffs 0.35, 0.45, and 0.55. Their EVM/SNDR results are
  effectively tied at each tested operating point.
- Reclassified the older `3.659670% -> 3.563808%` EVM and `28.731161 dB ->
  28.961713 dB` SNDR difference as a narrow ideal-filter Python digital-audit
  result. The numbers remain reproducible historical evidence, but are no
  longer used to claim a meaningful system-level EFDSM2 advantage.
- Retained the frozen one-bit BP EFDSM2 implementation for binary-DPA
  compatibility, existing RTL/Python bit-true evidence, and integration
  continuity. Future modulation improvement requires a higher-OSR study, a
  validated higher-order BP loop, or a multilevel-DPA route; it should not be
  claimed from the current second-order EFDSM2 parameter sweep.
- Updated `docs/ARCHITECTURE_DECISION.md`, `docs/RESUME.md`,
  `rtl/tx_bandpass_if/README.md`, and the architecture-summary generator to
  match this evidence boundary.

## 2026-08-25 - BP-EFDSM2 Behavioral DPA/DPD Endpoint

- Added an isolated MATLAB experiment for the frozen BP-EFDSM2 transmit route:
  Q1.15/Q2.14 DPD, x32 ideal band-limited interpolation, Fs/4 BP EFDSM2,
  behavioral switching DPA, output BPF, coherent DDC, and held-out DPD
  comparisons.
- The experiment reports no-DPD, memoryless DPD, and four-tap
  memory-polynomial DPD EVM/SNDR/ACLR plus declared-model Pout/Pdc/efficiency.
  It is explicitly bounded as behavioral evidence, not ADS or board RF data.
- Added input-RMS-matched DPD comparison and an ideal-switch versus full-DPA
  diagnostic runner. This prevents a Q2.14 `C1` gain increase from being
  misread as a pure DPD linearization gain and separates reconstruction loss
  from declared switching-DPA impairments.
- Aligned the endpoint receiver metric with the BP DSM audit: restrained
  BPF/LPF guard bands, CP removal, FFT, and per-subcarrier equalization.
  Earlier time-domain single-gain EVM was intentionally not comparable to the
  architecture-audit EVM and must not be retained as a BP DSM quality claim.
- Added a common behavioral-DPA comparison for BP single-loop, one-bit BP
  EFDSM2, and native four-level BP MASH11. Added an EFDSM2 parameter sweep for
  input backoff, B1/B2, and deterministic dither. MASH11 rows are explicitly
  multilevel-driver evidence and are not treated as current one-bit-DPA proof.
- Corrected the comparison endpoint: MASH11 native levels are normalized before
  the voltage driver, and ACLR is measured before the ideal output BPF to avoid
  a meaningless numerical floor from mathematically removed adjacent bands;
  post-BPF output power remains the Pout measurement.
- Replaced the default ideal output BPF in the BP-EFDSM2 behavioral endpoint
  with a causal finite-Q, finite-insertion-loss, center-offset-capable
  second-order analog RLC-equivalent model. The filtered waveform feeds the
  receiver and antenna-side ACLR; the pre-filter PA waveform remains a
  diagnostic ACLR point.
- Corrected MATLAB struct preallocation after adding PA-side ACLR to the
  endpoint metric and corrected the EFDSM2 sweep to rank its grouped mean
  results rather than raw per-seed rows. Added one entry script that runs the
  analog-BPF DPD comparison, modulator comparison, and EFDSM2 sweep in order.
- Corrected the modulator-study interpretation: MASH11 is now explicitly a
  four-level filter/receiver comparison and no longer reports binary-DPA Pdc
  or efficiency. The EFDSM2 sweep now holds a nominal backoff and averages
  three test seeds, so its selected point is not an accidental different-power
  operating point or single-seed result.

## 2026-08-25 - BP Route Documentation Alignment

- Corrected `rtl/tx_bandpass_if/README.md` to match the RTL integration:
  the frozen BP EFDSM2 route is selected by `DUC_MODE=3` inside
  `dsm_ip_top` and is exposed through `dsm_ip_axi_top`; it is not a separate,
  unconnected implementation.
- Clarified the selected candidate name as BP EFDSM2. The existing EVM/SNDR
  figures remain Python model-audit evidence, not DPA or board measurement.

## 2026-08-25 - Line-Coverage Triage Robustness

- Restricted the frozen-SKU URG exclusion-template generation to the `line`
  metric. The generated `.elfile` is deliberately line-only; this prevents a
  historical merged VDB without a DUT FSM shape from producing a partial URG
  report without `fullexclude.line`.
- Restricted the final reviewed report to the VDB's collected
  `line+cond+tgl+branch+assert` metrics, avoiding the same absent-FSM warning
  while retaining all available DUT coverage metrics.
- Updated the local coverage-flow instructions. A fresh Rocky URG run is
  still required to create new reviewed evidence.

## 2026-08-25 - Verification Matrix Clarification

- Added `docs/VERIFICATION_TEST_MATRIX.md` to separate MATLAB/Python
  fixed-point checking, UVM protocol testing, functional coverage, code
  coverage, and VC Formal FPV.
- Corrected the test naming boundary in documentation: `dsm_axi_protocol_test`
  is a protocol/observer smoke test, while the Memory-DPD bit-true timing test
  is the primary full-chain Python row-by-row RF comparison in the extended
  matrix.
- Retained the 15 historical UVM class names because they are keys in the
  recorded 300-run VCS CSV/VDB evidence. The matrix defines clear functional
  names and five verification families for future maintenance without breaking
  traceability.

## 2026-08-24 - Native Band-Pass DSM Audit Matrix

- Reworked `scripts/measure_p0_bp_dsm_comparison.py` to retain only native
  MASH output. The former hard-limit experiment is no longer emitted as a
  comparison candidate.
- Added explicit `NOT_IMPLEMENTED` rows for BPDSM2, BP EFDSM, BP MASH111, and
  BP MASH22. Low-pass models are not used as substitutes for missing band-pass
  state equations.
- Updated `docs/ARCHITECTURE_DECISION.md` and
  `matlab/tx_bandpass_if/README.md` to state this implementation boundary.
- Regenerated `p0_bp_dsm_comparison_20260805.csv` and the derived frozen-SKU
  architecture summary with Python 3.12. The architecture generator check and
  `git diff --check` both passed.

## 2026-08-23 - Architecture Selection Evidence

- Added `docs/ARCHITECTURE_DECISION.md` to record the frozen architecture
  decision, its measurement contract, source CSVs, and claim boundaries.
- Added the architecture record to `docs/README.md` so the decision evidence
  is part of the public handoff index.
- Added `scripts/build_architecture_decision.py`, a standard-library-only
  generator that rebuilds the checked architecture summary from committed
  evidence rather than hand-maintained arithmetic.
- Recorded the one-bit BP selection: BP EFDSM2 reduced modeled EVM from
  3.659670% to 3.563808% and improved SNDR from 28.731161 dB to 28.961713 dB
  versus the one-bit resonator baseline. The native BP MASH 1-1 path was
  rejected for the binary DPA route because its cancellation depends on a
  four-level output.
- Recorded the x16-to-x32 interpolation operating-point cost from the ZU15EG
  OOC matrix. This is a required-OSR resource trade-off, not a claim of a
  universal EVM or ACLR improvement.
- Added a controlled future experiment definition for a memory-DPD pipeline
  before/after comparison. No ASIC PPA or pipeline improvement number is
  claimed until paired bit-true and implementation reports exist.
- Ran the architecture-summary generator and its `--check` mode with the local
  Python 3.12 installation, then ran `git diff --check` successfully.

## 2026-08-23 - Public Repository Cleanup

- Removed local tool products, temporary databases, reports, caches, and
  generated waveform data from the working tree.
- Removed historical scope captures, board-replay outputs, duplicate RFSoC
  fragments, duplicate FPGA ROM images, and a generated MATLAB stage dump.
- Expanded `.gitignore` for technology collateral, board collateral, EDA
  caches, coverage databases, and implementation products.
- Removed local PDK path documentation, resume material, and redundant research
  notes from the public handoff.
- Rewrote the public documentation set in concise English and removed claims
  that exceeded the available evidence.
- Replaced stale coverage history with one current audit, portable commands,
  and an explicit open-item list.

## 2026-08-22 - ASIC Flow Bring-Up

- Added an ASIC pre-layout flow for the frozen SKU.
- Confirmed that local Design Compiler can start with an approved 28 nm
  standard-cell database, but the full flow still requires link-clean source
  and library configuration before it can be treated as a new PPA result.

## 2026-08-21 - Verification and Coverage Audit

- Recorded a 15-test, 20-seed frozen-SKU system-UVM regression with 300 passing
  runs and declared functional coverage at 100%.
- Added a source-linked coverage audit. Raw DUT code coverage remains below
  100%; only reviewed compile-time-disabled or defensive items may be waived.
- Added a random ready/valid test for the memory-polynomial DPD datapath.

## 2026-08-16 - FPGA Integration Baseline

- Created the ZU15EG integration, bare-metal, and ILA support structure.
- Preserved the distinction between OOC evidence and a complete routed/board
  closure for the current frozen SKU.

# 2026-08-23 - Resume Evidence Consolidation

- Added `docs/RESUME.md` with an evidence-backed English resume version for the frozen digital-transmitter Performance SKU.
- Reworked the recommended resume bullets around RTL architecture, PPA-driven SKU selection, routed FPGA evidence, and formal control-plane safety; kept coverage as supporting evidence rather than the primary claim.
- Reframed the primary architecture claim around the seven-DSM comparison and the one-bit DPA output constraint that selects BP EFDSM2; removed compile-time pruning from the main resume bullets and retained it only as interview detail.
- Used the archived 2026-07-26 routed implementation summary as the only quoted full-TX FPGA integration baseline: 100 MHz, WNS +2.314 ns, 16,296 LUTs, 20,763 FFs, 3 BRAMs, and 266 DSPs. It is explicitly marked as historical rather than the complete closure of the frozen BP EFDSM2 SKU.
- Added isolated DSM and DPD OOC comparison figures, compile-time feature-pruning savings, and the VC Formal FPV result with explicit scope boundaries.
- Explicitly distinguishes 100% declared functional coverage from incomplete raw DUT code coverage and avoids unmeasured RF/PA claims.

## 2026-08-27 - RTL Readability Refactor

- Refactored RTL entry-point readability without changing interfaces, fixed-point arithmetic, state-update order, latency, reset behavior, or AXI transaction semantics.
- Added named compile-time IDs for DSM, DUC, interpolation modes, and interpolation implementations in `rtl/ip/dsm_ip_core.sv` and `rtl/interp/dsm_interp_frontend.sv`.
- Added a top-down RTL reading order in `rtl/README.md`, clarified the integrated BP EFDSM2 route in `rtl/ip/dsm_ip_top.v`, and named the final DPD pipeline stage in `rtl/dpd/dpd_frontend.v`.
- Grouped and documented the AXI-Lite register map, transaction boundaries, counter ownership, sticky-error behavior, and read-response contract in `rtl/axi/dsm_ip_axi_top.v`.
- Check run: `git diff --check` passed. The required P0 and IP-smoke XSim scripts were invoked, but both stopped before compilation because the local Vivado launcher did not create `xvlog.log`; no RTL or testbench failure was observed and no simulation pass is claimed for this refactor.

## 2026-08-28 - AXI Readback Structural Refactor

- Added `rtl/axi/dsm_ip_axi_read_mux.v` and `rtl/axi/README.md`.
- Replaced the large combinational AXI-Lite readback `case` in
  `rtl/axi/dsm_ip_axi_top.v` with explicitly packed `axi_read_words` and a
  stateless readback selector. The wrapper still captures `RDATA` at the
  original AR acceptance point.
- Replaced raw packed-word indices in the readback map with the existing
  `ADDR_*` localparams and separated the map into core, DPD/monitor,
  memory-polynomial/observer, calibration, and extended-status sections.
  This is source-level naming and documentation only; the address map and
  each 32-bit readback value are unchanged.
- Added the new source to the P0, IP packaging, XSim, UVM, Formal, Vivado OOC,
  routed-FPGA, and ASIC synthesis filelists.
- Updated `rtl/README.md` to document the AXI module boundary and top-down
  reading order.
- Reason: reduce review cost for the 0x00 through 0x47 register read map
  without modifying external ports, register addresses, write-side priority,
  commit policy, datapath arithmetic, reset behavior, or latency.
- Static check: `git diff --check` passed (existing line-ending warnings were
  reported only for unrelated working-tree files).
- Required checks invoked: `run_xsim_p0_all.ps1` and
  `run_xsim_ip_smoke.ps1` both stopped before RTL compilation because the
  local Vivado launcher returned without creating `xvlog.log`. No XSim pass is
  claimed for this refactor.
- The current automation session has no enumerated WSL distribution, so the
  Linux/VCS regression could not be started here. Re-run the UVM compile and a
  representative control-plane test from the configured Linux EDA shell after
  syncing this change.
- Write-side register/commit extraction remains deferred because it requires a
  dedicated priority-equivalence verification plan.

## 2026-08-31 01:10:16 +08:00 - 文档收敛与时序证据边界

- 将分散的架构决策、验证矩阵、ASIC PPA 基线、CDC/STA、交接、发布与项目指南，收敛为持续维护的 `docs/SPEC.md`、`docs/VPLAN.md` 与 `docs/CRITICAL_PATH_REPORT.md`。
- 将有效验证矩阵、通过准则、覆盖率解释、CDC 边界、架构决策、集成边界与后续计划迁入主文档；模型、post-synthesis OOC、routed OOC 子集、历史集成与 ASIC pre-layout 证据现已明确区分。
- 新增 `docs/CRITICAL_PATH_REPORT.md`，记录已归档的 OOC 汇总，并明确原始 FPGA `report_timing` 的起点、终点与路径明细未归档，因此不声明精确的 FPGA 最坏路径端点。
- 删除被替代的文档入口：`VERIFICATION_TEST_MATRIX.md`、`ARCHITECTURE_DECISION.md`、`ASIC_PPA_BASELINE.md`、`CDC_STA_SIGNOFF.md`、`IP_HANDOFF.md`、`PPA_VERIFICATION_RELEASE.md` 与 `PROJECT_GUIDE.md`。
- 本项仅为文档收敛：未改动 RTL、MATLAB 模型、filelist、综合设置、仿真命令或既有结果；未重新运行综合、实现、VCS、XSim、Formal 或板级检查。
