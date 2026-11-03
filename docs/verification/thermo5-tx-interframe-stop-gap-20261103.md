# Thermo5 TX Interframe Gap and STOP/Drain Closure

Date: 2026-11-03 (Asia/Singapore)
Product RTL source SHA: `1236d49c72360aa62e316aea147528d93a1b3705`
Verification worktree HEAD during targeted run: `0279b8e4e64d3f7a1fe214b905c60d5018b5f726`

## Result

The frame-replacement test clears RUN after both complete 32-beat source
packets are accepted, then drains and checks the finite DSP tail. It checks the
entire underflow counter and protocol STATUS. This fixes the test's earlier
stop-after-output ordering, which allowed a source bubble to starve the core
while RUN remained high. No product RTL or algorithm changed.

Three useful diagnostics had no coverage effect: one-cycle source gaps before
beats 31 and 32, and a no-gap run, each passed the 112-word four-plane checker
with zero underflow and STATUS predictor mismatch. A timing-derived 11-cycle
gap before source beat 32 exercised the target single-entry pop/push decision
in both Centered-Cubic stages. The run used the product DUT coverage hierarchy
(`thermo5_product_dut_coverage.hier`), seed 930833, and passed with:

- `stage1=1 stage2=1` target event counts;
- 64 accepted source beats, two TLASTs, and 112/112 four-plane Oracle matches;
- zero underflow, STATUS predictor mismatch, protocol error, UVM warning,
  error, or fatal.

The 11-cycle-gap run was compiled with the formal product file list and
`-cm_hier` hierarchy selection. Its VDB tree SHA-256 is
`392430e0c94f3c5d76ee09a0caa00e58ede00f27c597d13cca84406dbfe6e692`.

## Coverage update

The 245-test VDB set consists of the prior 244-test set plus the validated
11-cycle-gap VDB. Raw and Adjusted URG used the exact same VDB list, current
product configuration fingerprint, and current waiver pipeline audit. No
waivers were approved and no exclusions were active, so Adjusted equals Raw.

| Metric | Before: 244 VDBs | After: 245 VDBs | Delta |
|---|---:|---:|---:|
| Branch | 523/637 | 525/637 | +2 |
| Condition | 656/849 | 658/849 | +2 |
| Line | 3337/3796 | 3351/3796 | +14 |
| Toggle | 84180/104480 | 84180/104480 | 0 |
| FSM states | 13/13 | 13/13 | 0 |
| FSM transitions | 17/22 | 17/22 | 0 |

The two closed semantic Raw records were:

- `TXB-9141942b3f6f51689217`, stage 1, `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:255`;
- `TXB-33db6d34081fd3b6ec60`, stage 2, the same source line.

Both records disappeared from the refreshed Raw OPEN-bin ledger. The exact
outstanding-counter saturation and underflow records remain OPEN. Total open
code records are now 21,053 in 457 root-cause groups; no denominator was
changed. Legally applicable Functional Coverage remains 392/392. The
fail-closed result remains `RAW_100_OPEN`.

## Formal and assertion status

The continuous-legal-packet outstanding-counter run used zero environment
assumptions and zero black boxes. Source/core/output activity Covers were
witnessed and both assertions were non-vacuous, but both guard assertions and
both target Covers remain **INCONCLUSIVE**. The counter Branches remain OPEN.

The legal-only assertion view has zero failures; two Centered-Cubic frame-tail
assertions remain uncovered and two have no attempts. The all-test Raw
assertion inventory includes two expected failures from separate negative
tests. These categories are not combined into a legal assertion PASS claim.

## Reproduction and evidence

The complete VCS, Formal, Raw/Adjusted URG commands, source hashes, VDB
inventory, logs, and gate output are indexed in
[`thermo5-tx-interframe-stop-gap-20261103.json`](data/thermo5-tx-interframe-stop-gap-20261103.json).
Large logs and VDBs remain under the ignored `runs/` directory.

The earlier 16-point gap sweep is excluded from positive coverage because all
16 logs recorded an AXI-Lite STATUS predictor mismatch. The no-gap and
one-cycle-gap diagnostics are retained only as test evidence; only the
11-cycle-gap VDB produced valid targeted Raw coverage hits and is included in
the 245-test merge.

## Remaining work

- Outstanding-counter Formal convergence and its two Raw Branches remain OPEN.
- Other reachable Branch, Condition, Line, Toggle, FSM, and assertion gaps
  remain OPEN; the full open-bin ledger is not signed off.
- All 371 waiver rows are pending review; zero are approved.
- DPD Identity Formal, real XPM and GT Wizard simulation, FPGA PPA/routed
  timing, and physical RF/QAM256 validation remain outside this Linux closure.
