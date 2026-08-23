# Frozen SKU Coverage Audit

## Scope

This audit covers the synthesizable hierarchy below `dsm_uvm_tb.dut` for the
frozen Performance SKU:

```text
ALGORITHM=3
DUC_MODE=3
INTERP_MODE=4
INTERP_IMPL=0
ENABLE_DPD_POLY=0
ENABLE_DPD_LUT=0
ENABLE_DPD_MEMORY=1
DPD_MP_MAX_TAPS=4
DPD_POLY_ORDER=5
aclk=100 MHz
```

The target is complete coverage of reachable RTL in this elaboration. It is
not appropriate to claim raw 100% coverage while feature-pruned logic and
defensive paths remain in the source tree.

## Current Evidence

The latest completed system regression contains 15 UVM tests with 20 seeds per
test: **300 PASS / 0 FAIL**. An accepted run must have all of the following:

- process exit code zero;
- `UVM_ERROR=0` and `UVM_FATAL=0`;
- `[TEST_DONE]` in the simulation log;
- the applicable scoreboard completion marker.

Declared functional coverage for the system UVM covergroups is 100%.

The current unadjusted DUT-subtree URG report is:

| Metric | Result |
|---|---:|
| Score | 77.11% |
| Line | 77.37% |
| Condition | 77.45% |
| Toggle | 67.89% |
| Branch | 61.84% |
| Assertion | 78.12% |

These are code-coverage measurements, not functional-coverage results. They
remain open until each residual bin is closed by a legal test or an audited,
source-linked exclusion.

## Reviewed Exclusions

`FROZEN_SKU_COVERAGE_WAIVERS.csv` is the source of truth for exclusions. It
currently records only frozen-SKU-specific cases:

- Poly and LUT datapaths are compile-time disabled in this SKU.
- Mirrored FIR coefficient-table entries are not addressed by the elaborated
  symmetric FIR specializations.
- The one-bit RF encoding cannot legally produce `-32768`; an SVA checks this
  invariant whenever `rf_valid` is asserted.

An exclusion applies only to this exact build. It must not be reused for an
enabled Poly/LUT SKU or a different interpolation specialization.

## Open Coverage Work

The following paths are deliberately still open:

- `abs_s32(32'h8000_0000)` overflow protection in the spectral path;
- residual observer and wrapper coverage bins;
- memory-polynomial pipeline flow-control bins;
- legal reset, commit, FIFO-boundary, W1C, and long-backpressure combinations.

The focused `tb_dpd_memory_poly_random_protocol.sv` test exercises random
memory-DPD input and output stalls. It must be included in a current merged
coverage database before its bins are marked closed.

## Reproduction

Run from a licensed Linux VCS environment:

```bash
cd <repository-root>
bash uvm_verif/sim/run_reachable_corner_linux.sh
bash uvm_verif/sim/run_ip_extended_regression_linux.sh
bash uvm_verif/sim/run_ip_extended_coverage_linux.sh
bash uvm_verif/sim/coverage/run_frozen_sku_coverage_triage_linux.sh
```

Inspect the generated CSV and URG report under `uvm_verif/sim/out/vcs/`.
Coverage output, VDBs, waveforms, and logs are generated artifacts and are not
part of the public source release.

## Board Boundary

Board replay is a digital I/O check: a 100 MSPS, one-bit stream with Fs/4
content centered at 25 MHz is compared with the MATLAB/Python/RTL golden trace.
It does not establish PA efficiency, RF output power, EVM, ACLR, or closed-loop
calibration performance. Those claims require a defined RF path and feedback
receiver.
