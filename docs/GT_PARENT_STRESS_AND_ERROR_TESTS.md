# Thermo5 GT-Parent Stress and Error-Frame Tests

## Scope

The Vivado 2026.1 XSim tests use the generated four-channel ZU15EG GT Wizard
behavioral model configured for RAW 64-bit TX at 14.0 Gb/s with a 125-MHz
reference clock. Stimulus enters through AXI-Stream and the AXI-Lite control
wrapper; checks observe both the 256-bit GT user interface and sampled TXP
pins. The pin sampler uses a 71.428571-ps unit interval.

These tests verify digital behavior in the vendor GT model. RX word comparison
is intentionally skipped because RX user-clock/data recovery is not closed.
They do not sign off analog eye, jitter, BER, physical lane skew, board I/O,
PA/RF output, or routed GT-PMA timing.

## Reproducible XSim scenarios

From the repository root, use a distinct output directory for each run:

```powershell
.\syn\run_thermo5_qsfp_gt14_parent_sim.ps1 `
  -OutDir .\runs\gt_stress_ramp -SkipRxCompare -Scenario Stress -Pattern 0
.\syn\run_thermo5_qsfp_gt14_parent_sim.ps1 `
  -OutDir .\runs\gt_stress_zero -SkipRxCompare -Scenario Stress -Pattern 1
.\syn\run_thermo5_qsfp_gt14_parent_sim.ps1 `
  -OutDir .\runs\gt_stress_signed_extremes -SkipRxCompare -Scenario Stress -Pattern 2
.\syn\run_thermo5_qsfp_gt14_parent_sim.ps1 `
  -OutDir .\runs\gt_stress_impulse -SkipRxCompare -Scenario Stress -Pattern 3
.\syn\run_thermo5_qsfp_gt14_parent_sim.ps1 `
  -OutDir .\runs\gt_bad_frames -SkipRxCompare -Scenario BadFrames
```

Pattern IDs are: 0 = signed ramp, 1 = zero I/Q at half-scale frame gain,
2 = alternating signed I/Q extrema (`0x7fff`/`0x8000`), and 3 = a two-sample
I/Q impulse with quarter-scale frame gain. Each stress case uses seed
`0x5eed0000` to introduce eight reproducible AXIS valid-gap cycles during the
first eight FIFO-prefill beats. The existing stimulus then pauses for the
AXI-Lite RUN write and sends the rest of the packet without injected bubbles.
This perturbs source timing without intentionally violating the line-rate
producer contract and manufacturing an underflow.

Every stress case accepted 32 AXIS beats, emitted 56 four-plane 256-bit GT
user words (56 64-bit words per lane), and matched all 3,584 serialized bits
on each of the four TXP lanes. No underflow, frame protocol error, or
serializer stream fault was observed. The 128-bit alternating-idle check and
P/N differential polarity check also passed per lane.

The bad-frame scenario covers two different contracts:

| Injection | Expected behavior | Observed result |
|---|---|---|
| Assert early `TLAST` on beat 15, then continue through the legal beat-31 `TLAST` | The AXI-Lite wrapper sets sticky `core_protocol_error`; the packet is not silently treated as a legal 32-beat quantum. A common reset clears the diagnostic. | `THERMO5_GT_EARLY_TLAST_OBSERVED`; reset clears status; a legal 56-word replay matches every TXP lane. |
| Start a run, send only 16 AXIS beats, then stop the source without `TLAST` | The continuous GT-user boundary cannot backpressure. It latches `stream_fault`, deasserts PA enable, and drives the configured idle word on GT TXDATA. | `THERMO5_GT_PARTIAL_FRAME_FAULT_OBSERVED`; common reset clears the sticky fault; a legal replay again matches every TXP lane. |

The XSim process emits `THERMO5_QSFP_GT14_STRESS_PASS` or
`THERMO5_QSFP_GT14_BAD_FRAMES_PASS` only after the checks above complete.

## Full-IP UVM pressure and protocol-negative regression

The generic-FIFO VCS regression was run with Synopsys VCS
V-2023.12-SP1, seed values defined by the existing Make target, and isolated
output at `runs/thermo5_stress_dv_regression_20261025/`:

```bash
make -C dv/uvm/sim thermo5-vcs-regression \
  THERMO5_OUT=/mnt/e/workspace/chip/dsm_ip/runs/thermo5_stress_dv_regression_20261025
```

It passed the nominal bit-true frame with PA-ready stalls, full-chain valid-gap
plus backpressure, FIFO-full recovery, intentional FIFO starvation/underflow,
active-stream reset and replay, five residual-state reset points, and the
misaligned-frame negative test. The negative test intentionally triggers the
RTL alignment assertion, observes sticky `protocol_error`, and verifies that
public reset clears it; the regression target checks that expected assertion
and exits successfully. All UVM tests reported zero UVM errors/fatals.

The VCS runs supplement the four-lane GT TXP tests: they check AXIS/source
ordering and MATLAB bit-true outputs, while the GT-parent tests compare the
serialized pins against the actual GT user words. Neither class substitutes
for physical link measurements.

## Evidence

The combined Vivado/XSim run directory is
`runs/thermo5_gt14_stress_20261025_224631/`. It retains a separate
`pattern*_simulate.log` for each data pattern, `badframes_simulate.log`, and
`baseline_simulate.log`. The VCS run directory contains the compile log and
per-test logs listed above. Generated logs and simulator products remain under
the ignored `runs/` tree and are not repository sources.
