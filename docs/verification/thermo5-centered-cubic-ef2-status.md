# Thermo5 centered-cubic + EF2 main-chain status

## Current main-chain status (2026-10-28)

Centered-cubic x2 interpolation and second-order Cartesian error-feedback
TIDSM (`STEP=5120`, 20-bit state) are the active thermo5 main-chain defaults.
First-order TIDSM and causal interpolation remain selectable fallbacks.
VCS V-2023.12-SP1 has passed the full generic-FIFO regression, AXI-Lite
integration regression, and the focused two-packet STOP/drain/restart case.
The latter checked 112 ordered four-plane outputs against the Python oracle,
hit all six STOP/restart functional bins, and ended with zero underflow or
protocol errors.

The AXI-Lite wrapper now preserves pre-RUN FIFO prefill and, after a completed
STOP/drain, waits until two new source beats have entered the FIFO before
starting the 14:8 gearbox on a fresh RUN. This prevents the restart path from
starting against an empty FIFO. A RUN held high after a finite stream is
exhausted still reports underflow as designed; software should issue STOP to
close a finite transmission cleanly.

The centered-cubic EF2 qualification covers sustained traffic, positive and
negative state clamps, clamp-candidate stalls, reset/replay, PA backpressure,
and a behavioral four-path serializer loopback. The current merged generic
URG score is 79.86%; raw code coverage is not closed. No EF2 GT Wizard/TXP
rerun, XSim run on this Linux host, formal EF2 proof, real-XPM coverage, or
physical QAM256 signoff is claimed. FPGA timing/resource work remains deferred
per user direction.

## Historical checkpoint (2026-10-27; superseded)

The centered-cubic sustained-throughput test was rerun with Vivado 2026.1
XSim and passed again: 1,024 contiguous ordered outputs, zero bubbles,
1,023 cycles from first to last output. The log is
`runs/centered_cubic_sustained_xsim/xsim.log`.

The STOP/drain/restart test and six event bins are now part of the optional
centered-cubic + EF2 candidate target. A correct EF2 run generated its 112-word
oracle vectors at centered cubic, order 2, STEP 5120, then the VCS launcher
stopped before compile with `Cannot find license file`. This scenario therefore
remains OPEN and is not counted as a regression pass. The Make dry-run verified
that the candidate target propagates order 2 / STEP 5120 to both vector
generation and RTL compilation. The existing generic/XPM candidate regression
results from 2026-10-26 remain historical evidence for the suite that ran then;
they do not cover the new STOP/restart scenario.

A longer independent software-model check ran six held-out seeds
`1117,1123,1129,1151,1153,1163`, 24 256-QAM OFDM symbols per seed, 4097-tap
receiver filter, EF2 STEP 5120, 20-bit state, and RMS drive 0.08. It evaluated
84,096 QAM decisions / 672,768 uncoded bits and found 117 hard-decision bit
errors: BER `1.7391e-4`, 95% Wilson interval `[1.4512e-4, 2.0840e-4]`; mean
digital EVM `2.5170%`, worst-seed EVM `2.5403%`, mean SNDR `31.982 dB`, and zero
input/state saturation samples. The input peak preflight ranged from 0.2505 to
0.3153 against the model limit 0.35. Detailed per-seed data is in
`runs/thermo5_ef2_heldout_extension_20261027/ef2_heldout.json`; the runner is
`dv/uvm/refmodel/python/benchmark_thermo5_ef2_heldout_extension.py`.

This is a longer uncoded digital link-model statistic, not physical GT BER,
receiver conformance, or a production BER/BLER signoff. It also uses RMS 0.08,
whereas the earlier 12-symbol held-out benchmark used RMS 0.10, so the two BERs
are not a controlled like-for-like comparison. A separate attempt at RMS 0.10
was correctly rejected by the input-drive guard because seed 1117's OFDM peak
was 0.3941, above 0.35; this was a stimulus-envelope rejection, not a DUT
failure.

## Throughput correction

The centered-cubic FIR holds two input vectors for future-sample lookahead.
Previously `in_ready` deasserted whenever both entries were occupied, even on
the cycle that `out_ready` consumed the head. This prevented simultaneous
pop/push and inserted a bubble between outputs. `in_ready` now grants credit
when the head will be popped on that edge. A directed XSim test drove 1,024
contiguous zero-valued vectors plus one synthetic lookahead tail with the sink
permanently ready. It observed 1,024 ordered outputs in 1,023 cycles from first
to last, zero output bubbles, and correct frame markers:

```text
CENTERED_CUBIC_SUSTAINED_PASS inputs=1025 outputs=1024 bubbles=0 output_cycles=1023
```

The focused regression does not replace full-chain flow-control testing.

## Candidate functional evidence

For the centered-cubic + EF2 (`STEP=5120`) candidate:

- XSim full-chain bit-true check passed with generic FIFO and with XPM FIFO:
  32 accepted source words, 56 ordered output words per plane, with 21 and 17
  PA-stall cycles respectively.
- Full VCS/UVM candidate regression passed with generic and XPM FIFO. It
  included nominal four-plane bit-true comparison, source bubbles/PA
  backpressure, FIFO boundary/full, FIFO starvation and sticky underflow,
  reset/replay, residual-reset sweep, and expected illegal-frame assertion and
  recovery. Both runs returned zero UVM errors/fatals. The bubble/backpressure
  test explicitly exercised partial four-plane readiness; its plane-atomic
  cross reported 100% and counted 109 partial-ready stall cycles.
- The AXI-Lite configuration/control regression also passed with generic and
  XPM FIFO. It covered register protocol, commit/mailbox/frame-boundary
  application, coefficient transport, tap-4 identity, graceful STOP/drain,
  expected negative-frame/mailbox assertions, and coverage merge. The
  nonlinear DPD coefficient configuration case checks mailbox transport only;
  its separate arithmetic bit-true test passed for both FIFO builds at 56 and
  112 output words (one and two packets), comparing all four planes to the
  matching Python fixed-point oracle. This confirms the DPD arithmetic path
  for those directed vectors, not a universal signal-envelope guarantee.
- The candidate oracle was generated from the Python fixed-point reference
  with seed 1101, 56 words, centered cubic, EF2, and STEP 5120.

Local simulator outputs are ignored under `runs/thermo5_centered_ef2_signoff_20261026/`
and `runs/uvm_thermo5_i2_d1/`; they are evidence from this workspace, not
checked-in artifacts.

## Benchmark metrics and BER limitation

The held-out fixed-point 256-QAM model run reports 23 natural-binary hard
decision errors among 168,192 uncoded bits:

```text
BER = 23 / 168192 = 1.367e-4
mean digital EVM = 2.461%
```

This is a finite, uncoded baseband-model statistic. It is neither a GT-PMA
measurement nor a calibrated RF receiver BER. The project has not specified an
air interface, coding/decoder and HARQ configuration, channel/SNR, RF
impairment model, packet-error objective, or target BER/BLER; therefore there
is no project-defined production BER target to sign against. For context only,
The current Release 19 NR base-station spec gives a 3.5% 256-QAM PDSCH EVM
limit for BS type 1-C/1-H under its specified measurement frame. Receiver
performance conformance defines BLER test points together with modulation/code
rate, propagation condition, and SNR. That illustrates why an uncoded BER
number alone is not a portable acceptance criterion. See [ETSI TS 38.104
V19.6.0](https://www.etsi.org/deliver/etsi_ts/138100_138199/138104/19.06.00_60/ts_138104v190600p.pdf)
and [ETSI TS 38.521-4 V19.2.0](https://www.etsi.org/deliver/etsi_ts/138500_138599/13852104/19.02.00_60/ts_13852104v190200p.pdf).
Those standard limits are not automatically interchangeable with this
behavioral model's EVM/BER calculation.

## Open signoff risks

1. **EF2 timing (P0):** the EF2 RTL evaluates all 32 time-ordered nonlinear
   recurrences in one combinational path. This preserves the scalar model but
   is not timing-qualified for 218.75 MHz. ZU15EG OOC synthesis generated a
   62,597,295-byte `synthesized.dcp`, utilization report, and clock report:
   88,880 LUTs (26.04%), 58,909 FFs (8.63%), 2,108 DSP48E2 (59.75%), and 6.5
   BRAM tiles (0.87%); modeled periods are 4.571 ns core, 10 ns AXI-Lite, and
   8 ns AXI-Stream. However, the Vivado launcher did not return a clean
   `THERMO5_AXIL_SYNTH_PASS`; it reported failure to load feature
   `fpga_compiler`. No placed/routed timing report exists. Timing-driven route
   remains OPEN until the licensing issue is resolved and at least 12-14 GiB
   of implementation memory is available. The resource report and DCP are
   useful synthesis evidence, not timing signoff.
2. **State saturation (P1):** 20-bit saturation prevents state arithmetic
   wrap, but does not prove the clamp can never activate for all legal signed
   16-bit inputs. The three held-out OFDM waveforms did not clamp; constant/high
   inputs can. Keep the 20-bit behavior and require the system owner to define
   the supported input envelope before claiming no-clamp operation. The
   ideal-loop NTF claim applies only while the clamp is inactive.
3. **Remaining verification/physical boundary:** EF2-specific formal proof,
   routed OOC timing, physical GT/board measurements, and a production BER/BLER
   target remain open. The focused VCS STOP/drain/restart scenario now passes
   on the current source: two packets, 112 ordered four-plane outputs,
   six-of-six event bins, and zero underflow/protocol errors. This closes the
   earlier runtime blocker, but does not establish analog BER, eye/jitter
   margin, or board-level signal integrity. Historical license-blocked
   attempts below are superseded by the 2026-10-28 run.

## Next closure gates

1. Obtain a supported input-amplitude envelope and a system BER/BLER/EVM
   acceptance plan tied to the intended waveform, coding, receiver, and channel.
2. Complete EF2-specific formal properties and rerun the GT Wizard/TXP
   scenarios on the EF2 defaults when the vendor simulation environment is
   available.
3. Restructure EF2 into a timing-qualified architecture while preserving its
   required sample ordering, or keep it as a correctness/quality prototype and
   use the frozen first-order path for timing signoff. Only after that decision,
   run ZU15EG timing-driven implementation and the relevant GT parent/board
   validation.
