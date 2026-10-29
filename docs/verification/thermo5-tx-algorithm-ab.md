# Thermo5 TX algorithm A/B — Linux evidence

**Status:** `PASS_LINUX_FUNCTIONAL_EQUIVALENCE; PERFORMANCE_OPEN`

**Source commit:** `dfb15a278657e4417b545fc138df0f0dd0399ac4`  
**Source tree:** `ef075943be1b6fe3c9570d3bd8c54324240c0a1f`  
**Date:** 2026-10-29 (Asia/Singapore)

This stage adds a full-chain, non-identity four-tap DPD oracle case and reruns
the existing two-tap case and EF2 pair look-ahead equivalence. It does not
change the product TX configuration. RX and AI-DPD were not modified. Full
commands, run paths, and SHA-256 hashes are in
[`thermo5-tx-gate1-evidence.json`](thermo5-tx-gate1-evidence.json); complete
logs and VDBs are preserved locally under the ignored
`runs/thermo5_tx_gate1_dfb15a2/` directory.

## Results

| Candidate | Linux evidence | Result | Disposition |
| --- | --- | --- | --- |
| EF2 two-sample pair look-ahead | 4,096-cycle VCS miter at seed 20261028; VC Formal 7/7 assertions and 4/4 covers, zero black boxes | **PASS: bit-true and relationally equivalent** | Keep `PAIR_LOOKAHEAD=0` in the product. No LUT/FF/DSP/Fmax or routed result exists, so there is no implementation benefit to justify enabling it. |
| Non-identity 2-tap DPD | Centered-cubic + EF2, `STEP=5120`; 56-word one-frame and 112-word two-frame VCS comparisons | **PASS: all four 64-bit planes matched; 0 UVM errors/fatals** | Test-only hand-selected coefficient image. QAM improvement is unmeasured. |
| Non-identity 4-tap DPD | Same configuration and frame lengths; all four taps active with nonzero `C1` and `C3` coefficients | **PASS: all four 64-bit planes matched; 0 UVM errors/fatals** | Test-only image in the AXI-Lite UVM elaboration (`DPD_MAX_TAPS=4`); it is not the one-tap GT parent SKU. |
| Python reference suite | Python 3.12, complete suite | **PASS: 37/37** | Includes the new four-tap fixed-point model case. |

The pair-look-ahead miter observed 2,662 accepted transactions, including
1,638 back-to-back accepts, 307 positive clamps, 408 negative clamps, 818
stalls, and 616 input bubbles. Formal covered the candidate bounds/no-wrap,
ready/valid/state and two quantizer-equivalence properties under its documented
pair-transfer assumptions. This establishes equivalence for the proven
contract; it does not show improved timing or area.

The DPD tests establish coefficient programming, memory history, frame-tail,
and four-plane fixed-point agreement for the specified images. Those images are
verification stimuli, not coefficients fitted to an inverse PA model. They do
not establish lower QAM256 BER/EVM, improved ACLR, or a useful production
predistorter. RTL synthesis/resource comparison is also open. `yosys` and
`verilator` are not installed here, and FPGA resource/timing work is deferred
for this Linux phase.

## Coverage evidence

URG was run separately on the four non-identity DPD VCS runs (two seeds for
each tap count). The raw AXI-Lite UVM hierarchy result was:

| Metric | Raw result |
| --- | ---: |
| Line | 3,320 / 4,241 = 78.28% |
| Condition | 596 / 1,183 = 50.38% |
| Toggle | 96,408 / 125,344 = 76.91% |
| FSM | 15 / 22 = 68.18% |
| Branch | 410 / 841 = 48.75% |
| Assertion | 11 / 17 = 64.71% |
| Functional group | 59.7958% |

This is a raw exploratory candidate-run merge, not the Gate 0 Generic or
full-regression coverage score and not the Gate 3 audited closure result. No
coverage denominator was edited and no exclusions were used. The detailed
baseline raw scores remain in [`thermo5-tx-baseline.md`](thermo5-tx-baseline.md).

## Commands

Run from the repository root, using unique output directories:

```bash
cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v
make -C dv/uvm/sim thermo5-axil-centered-nonlinear-bittrue-vcs PYTHON=python3.12 THERMO5_OUT="$PWD/runs/thermo5_tx_gate1_dfb15a2/dpd2/vcs" THERMO5_NONLINEAR_SHORT_VECTORS="$PWD/runs/thermo5_tx_gate1_dfb15a2/dpd2/vectors/short" THERMO5_NONLINEAR_LONG_VECTORS="$PWD/runs/thermo5_tx_gate1_dfb15a2/dpd2/vectors/long" THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120
make -C dv/uvm/sim thermo5-axil-centered-nonlinear-tap4-bittrue-vcs PYTHON=python3.12 THERMO5_OUT="$PWD/runs/thermo5_tx_gate1_dfb15a2/dpd4/vcs" THERMO5_NONLINEAR_TAP4_SHORT_VECTORS="$PWD/runs/thermo5_tx_gate1_dfb15a2/dpd4/vectors/short" THERMO5_NONLINEAR_TAP4_LONG_VECTORS="$PWD/runs/thermo5_tx_gate1_dfb15a2/dpd4/vectors/long" THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120
make -C dv/uvm/sim thermo5-ef2-pair-vcs THERMO5_EF2_PAIR_OUT="$PWD/runs/thermo5_tx_gate1_dfb15a2/pair/vcs"
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py --jobs ef2_pair --out-dir "$PWD/runs/thermo5_tx_gate1_dfb15a2/pair/formal_pair"
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 -dir runs/thermo5_tx_gate1_dfb15a2/dpd2/vcs/simv.vdb runs/thermo5_tx_gate1_dfb15a2/dpd2/vcs/cov_thermo5_sku_axil_nonlinear_bittrue_test_seed610213.vdb runs/thermo5_tx_gate1_dfb15a2/dpd2/vcs/cov_thermo5_sku_axil_nonlinear_bittrue_test_seed610214.vdb runs/thermo5_tx_gate1_dfb15a2/dpd4/vcs/simv.vdb runs/thermo5_tx_gate1_dfb15a2/dpd4/vcs/cov_thermo5_sku_axil_nonlinear_tap4_bittrue_test_seed612004.vdb runs/thermo5_tx_gate1_dfb15a2/dpd4/vcs/cov_thermo5_sku_axil_nonlinear_tap4_bittrue_test_seed612005.vdb -report runs/thermo5_tx_gate1_dfb15a2/dpd_ab_urg/report -dbname thermo5_dpd_ab
```

**Gate 1 Linux acceptance:** functional equivalence evidence is complete for
these candidates. Communication benefit and FPGA PPA remain unproven; neither
candidate is promoted to the product configuration.
