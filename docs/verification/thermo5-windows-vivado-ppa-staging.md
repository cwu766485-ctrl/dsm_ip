# Thermo5 Windows Vivado integration candidate (2026-11-13)

**Status: STAGING ONLY — NOT SIGNED OFF.**

This branch was created at commit `3b60f37929c23d014ab533ba80099e02f67c3e8d`, the last pushed PR #63 HEAD. Its ancestry contains previously *pushed* PR #55–#62 work. This branch is **not** merged to `thermo5`. Local, uncommitted CDC-fix and A/B research work under `/tmp/dsm_ip_cdc_quantified_research` or other worktrees **is not included**.

## Windows checkout

In PowerShell:
```powershell
git clone --branch integration/thermo5-vivado-ppa-20261113 --single-branch https://github.com/cwu766485-ctrl/dsm_ip.git dsm_ip_ppa
cd dsm_ip_ppa
git log -1 --format="%H"
git status --short
```
Expected starting commit before this note is added: `3b60f37929c23d014ab533ba80099e02f67c3e8d`. After the note commit, check the actual current HEAD and save its SHA in output manifests.

## Critical configuration caveat

`syn/run_ooc_thermo5_axil_control.ps1` accepts `-Interpolation causal|centered-cubic`, `-TidOrder 1|2`, and `-Step 5120|7168`, but the Tcl currently hardcodes `DPD_MAX_TAPS=4`, `FPGA_USE_XPM_FIFO=1`, and source clock 125 MHz; the original Linux validation SKU fixes `MAX_TAPS=1` and used Generic FIFO.

**Do not publish a controlled A/B PPA comparison until the Tcl is parameterized and the compared elaborated configurations, test vectors, clocks, FPGA part, constraints, output pipeline semantics, and power-activity assumptions are proven identical apart from the intended architecture factor.** Preserve historical PPA as a separate dataset. Do not treat vectorless estimates as measured power or these OOC runs as board signoff.

## Two workstreams

1. **Product DV signoff**: Reproduce and fix the newest locally reported UVM/CDC candidate, make an immutable *separate* pushed candidate commit, rerun full same-source legal and negative regression, SpyGlass full CDC and RDC, VC Formal, URG, and enforce review/approval. Existing full CDC=0 local evidence and RDC=10539 are unverified against a published SHA.
2. **A/B PPA**: Use this staging branch as a starting point. First establish an AXI-Lite fixed-SKU `DPD_MAX_TAPS=1` XPM build with complete timing reports. Then evaluate 2x2 `causal|centered-cubic` × `TIDSM_ORDER=1|2` with `STEP=5120`, one part and clock contract. Run synth for all four before selected route; for claims use same implementation mode across all runs. Record utilization, WNS/WHS, TNS, timing paths, DSP/BRAM, power provenance and git SHA.

The code-coverage exclusions and CDC/RDC tool waivers are independent approvals and MUST NOT be inferred from A/B FPGA PPA results.

## Source references

- `syn/run_ooc_thermo5_axil_control.ps1`
- `syn/run_ooc_thermo5_axil_control.tcl`
- `syn/README.md`
- `docs/verification/thermo5-tx-design-ablation.md`
- `docs/verification/baseline_reconciliation.md`
- `docs/verification/thermo5_verification_signoff_report.md`
