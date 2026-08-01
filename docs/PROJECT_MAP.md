# Project Map

This repository is a reusable DSM IP handoff tree.

| Path | Purpose |
|---|---|
| `README.md` | Top-level architecture, interface, verification, and build notes |
| `AGENTS.md` | Project instructions for AI-assisted maintenance |
| `.github` | GitHub issue templates, pull request template, and lightweight hygiene workflow |
| `.gitattributes` | Text/binary attributes and generated-file hints |
| `.gitignore` | Local tool cache and generated-file ignore rules |
| `CONTRIBUTING.md` | Contribution and required-check guidance |
| `SECURITY.md` | Secret-handling and disclosure guidance |
| `data` | Preserved board-validation capture data and reference files |
| `docs` | Architecture, status, integration, and evidence notes |
| `fpga` | FPGA/RFSoC source fragments, COE files, and local-only board collateral notes |
| `ip` | Vivado IP-XACT packaging scripts and generated IP repository |
| `ip/package_dpd_observer_bridge.ps1` | Companion IP packaging flow for the dual-clock DPD feedback bridge |
| `matlab` | MATLAB models, bit-true comparison, QAM-OFDM generation, and board-validation scripts |
| `rtl` | DSM RTL paths: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111, MASH22 |
| `rtl/dsm` | DSM algorithm cores |
| `rtl/duc` | Fs/4 merge and NCO upconversion blocks |
| `rtl/mem` | ROM reader |
| `rtl/ip` | Reusable streaming DSM datapath |
| `rtl/axi` | AXI-Lite/AXI-Stream SoC/RFSoC wrapper |
| `rtl/dpd` | Fixed-point polynomial, LUT, memory-polynomial, and feedback-bridge DPD RTL |
| `rtl/top` | ROM-backed P0 simulation and synthesis tops |
| `verif` | XSim testbenches for retained RTL paths |
| `syn` | 100 MHz OOC proxy synthesis |
| `matlab/bittrue` | MATLAB fixed-point models and RTL dump comparison |
| `matlab/board_validation` | Board capture recovery and comparison scripts |
| `data/board_validation` | Preserved board validation data |
| `fpga/hardware` | Local-only RFSoC 4x2 board collateral ignored for public release |
| `fpga/zu15eg` | ZU15EG PS-DMA-DSM-ILA bring-up notes and helper scripts |
| `docs/evidence` | Compact 100 MHz pass evidence |
| `docs/GITHUB_RELEASE_CHECKLIST.md` | Checklist for public GitHub release review |
| `docs/IP_HANDOFF.md` | Reusable DSM IP handoff and integration notes |
| `docs/METRIC_DEFINITIONS.md` | Native and RF-recovered metric definitions |
| `docs/AI_COMMUNICATION_IP_ROADMAP.md` | XCZU15EG-oriented AI-assisted communication IP roadmap |
| `docs/DPD_PPA_REPORT.md` | ZU15EG DPD OOC resource, timing, and power-estimate evidence |
| `docs/FULL_TX_IMPLEMENTATION.md` | ZU15EG full TX clock/reset contract and routed build evidence |
| `docs/PORTFOLIO_SKU.md` | Recommended interview demonstration SKU and preliminary 28 nm estimate |
| `syn/run_ooc_dpd_feature_matrix.ps1` | ZU15EG compile-time DPD product-SKU OOC PPA matrix |

The seven P0 comparison paths are retained. Other exploratory EFDSM4/MASH
bundles and broad research workspaces remain outside this handoff tree.

## RTL Files

| File | Purpose |
|---|---|
| `rtl/dsm/singlebit/dsm_core.sv` | First-order LPDSM core |
| `rtl/dsm/singlebit/dsm_core_dsm2.sv` | Second-order LPDSM core |
| `rtl/dsm/singlebit/dsm_core_ef1.sv` | First-order EFDSM core |
| `rtl/dsm/singlebit/dsm_core_ef2.sv` | Second-order EFDSM core |
| `rtl/dsm/singlebit/dsm_core_mash11.sv` | MASH 1-1 core |
| `rtl/dsm/singlebit/dsm_core_mash111.sv` | MASH 1-1-1 core |
| `rtl/dsm/singlebit/dsm_core_mash22.sv` | MASH 2-2 core |
| `rtl/dsm/multibit/dsm_core_multibit_*.sv` | Per-algorithm multibit DSM wrappers |
| `rtl/duc/duc_fs4_merge.sv` | Fixed Fs/4 merge for 1-bit I/Q outputs |
| `rtl/duc/duc_fs4_merge_signed.sv` | Fixed Fs/4 merge for signed multibit I/Q outputs |
| `rtl/duc/duc_nco_mix_signed.v` | Optional NCO mixer for non-Fs/4 experiments |
| `rtl/ip/dsm_ip_core.sv` | DSM + DUC datapath core |
| `rtl/ip/dsm_ip_top.v` | Reusable streaming datapath wrapper |
| `rtl/axi/dsm_ip_axi_top.v` | Current Vivado packaged top |

## Generated or Rebuildable Content

These directories are temporary and can be regenerated:

- `.Xil/`
- `ip/build/`
- `ip/ip_repo/`
- `verif/out_xsim_ip_smoke/`
- `verif/out_xsim_p0/xsim.dir/`
- `vivado*.log`
- `vivado*.jou`

These directories contain compact evidence or simulation summaries and are
normally kept with the handoff when intentionally curated:

- `matlab/out/*.csv`
- `verif/out_xsim_p0/summary*.csv`
- `docs/evidence/`

## GitHub Files

| File | Purpose |
|---|---|
| `.github/workflows/repo-hygiene.yml` | Checks required files, forbidden public markers, and tracked temp files |
| `.github/pull_request_template.md` | Pull request checklist |
| `.github/ISSUE_TEMPLATE/` | Bug report and feature request templates |
| `CONTRIBUTING.md` | Contributor workflow and checks |
| `SECURITY.md` | Secret and credential handling |
| `CODE_OF_CONDUCT.md` | Minimal collaboration expectations |
