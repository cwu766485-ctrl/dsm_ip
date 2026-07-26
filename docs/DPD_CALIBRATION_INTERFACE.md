# DPD Calibration and Feedback Interface

## Scope

The PL datapath executes deterministic fixed-point DPD. Coefficient
identification, model selection, and optimisation run on PS software or a PC.
This separation keeps the transmit sample path synthesizable, bounded, and
independent of a particular PA vendor.

## Feedback AXI-Stream

`dsm_ip_axi_top` already exposes an observation input named
`s_axis_obs_*`. It is the standard feedback entry point for PA observation
samples.

| Signal | Meaning |
|---|---|
| `tdata[15:0]` | Observed I sample, signed Q1.15 |
| `tdata[31:16]` | Observed Q sample, signed Q1.15 |
| `tvalid/tready` | AXI-Stream transfer handshake |
| `tlast` | End of the configured capture window |
| `tuser[0]` | Invalid sample marker; the observer counts it as a drop |

`s_axis_obs_*` is synchronous to `aclk`. An ADC, RFSoC, or observation
receiver that uses another clock must be connected through an AXI-Stream
asynchronous FIFO before this IP. The IP deliberately does not sample an
unrelated clock domain directly.

`rtl/dpd/dpd_observer_async_bridge.v` provides that boundary as a reusable
AXI-Stream adapter. It preserves `tdata`, `tlast`, and `tuser[0]` across two
clock domains. The default policy is lossless backpressure: a full FIFO holds
`s_axis_tready` low. `DROP_ON_FULL=1` is available only for explicitly
loss-tolerant observation paths and increments `s_drop_count` for every lost
sample. Both source and destination resets must be asserted together; a reset
intentionally drains the FIFO and invalidates any partial observation window.
The bridge is not instantiated inside the current single-clock full-TX build.
It is packaged independently by `ip/package_dpd_observer_bridge.ps1` so an
integrator can place it between an external feedback source and `dsm_ip`.

The observer pairs this stream with accepted TX input samples, applies the
programmed delay and complex gain correction, and reports paired samples,
drops, error power, peak, clipping, saturation, and spectral-proxy bins.
It is not an RF receiver implementation and does not claim physical EVM or
ACLR without a calibrated observation chain.

## Calibration Sequence

1. Disable or hold the TX stream at an idle boundary.
2. Program observer delay, complex gain, window size, and condition metadata.
3. Set `OBS_CTRL.start`, then send the known reference stream and the aligned
   observed PA feedback stream.
4. Wait for `OBS_STATUS.done`; accept the capture only when
   `OBS_STATUS.valid_window=1`. Reject a nonzero drop count or an asserted
   overflow flag. If software needs the 64-bit L1 error total, write
   `OBS_SNAPSHOT.bit0=1` and read the snapshot low/high words rather than
   separately reading the live accumulator.
5. PS/PC estimates a PA/DPD model, quantizes Q2.14 coefficients, and checks
   coefficient and clipping limits.
6. Write all coefficients to the inactive memory-DPD bank through
   `MP_SELECT`/`MP_DATA`, then write `MP_COMMIT.bit0=1` once. Poll
   `MP_COMMIT_STATUS`: pending/inflight means the TX input is temporarily
   held while already accepted samples drain; `commit_ack=1` and an incremented
   epoch mean the new bank is active. Treat `failed=1` as a rejected package.
7. Read counters and retain the package only if the selected score improves.

The reference and feedback streams must share an explicit sample-rate
definition. The observer delay field is 0 through 31 accepted TX samples;
the maximum reference history is 32 samples. Delay and gain/phase alignment
are explicit because a PA/observation receiver has unknown group delay and
gain. A capture starts with a clean statistics epoch. Invalid feedback, absent
reference, FIFO reset, or configured drop-on-full invalidates the affected
window; the PS/PC must retry rather than silently train on it.

`OBS_CTRL.bit16` enables `obs_irq`. The level interrupt is asserted while the
sticky `done` state is set and is cleared by `OBS_CTRL.start` or
`OBS_CTRL.clear`. This permits either polling or a PS interrupt controller.
The drop policy is deterministic: invalid feedback samples and samples with no
available delayed reference are accepted, counted as drops, and excluded from
the error and spectral accumulators. The observer also flags finite-width
counter, error, magnitude/slew, clip/saturation, and fixed-bin accumulator
overflow. A calibration result is valid only when the window is done,
`valid_window=1`, and the reported drop count is zero.

## Compile-Time DPD Choices

`dpd_frontend` has these synthesis parameters:

| Parameter | Default | Purpose |
|---|---:|---|
| `MP_MAX_TAPS` | 4 | Maximum memory depth. Supported values are 1 to 6. |
| `MP_POLY_ORDER` | 5 | Selected polynomial order for a build. The memoryless execution kernel implements orders 3, 5, and 7; the banked memory-polynomial kernel currently implements through fifth order. |
| `ENABLE_DPD_POLY` | 1 | Retains the memoryless polynomial branch when set; a disabled runtime request resolves to bypass. |
| `ENABLE_DPD_LUT` | 1 | Retains the LUT DPD branch when set; a disabled runtime request resolves to bypass. |
| `ENABLE_DPD_MEMORY` | 1 | Retains the banked memory-polynomial branch when set; a disabled runtime request resolves to bypass. |
| `COEFF_SAFE_ABS` | 24576 | Maximum allowed absolute Q2.14 coefficient when safety is enabled. |

The registered production configuration remains four taps with first-, third-,
and fifth-order terms. The seventh-order memoryless core is scoped as
`C1/C3/C5/C7`. `DPD_POLY_ORDER` remains a compile-time choice because it
removes unused arithmetic from synthesis. C7 itself is now programmable at
AXI-Lite byte address `0x100` (`DPD_C7`, real Q2.14 in bits 15:0 and imaginary
Q2.14 in bits 31:16). This extends the AXI-Lite address width to nine bits;
the legacy `0x00` through `0xFC` byte addresses are unchanged.

The banked memory-polynomial engine intentionally remains C1/C3/C5. Adding C7
to every memory tap is a separate architecture option and must be selected
from measured PA fit improvement and PPA evidence, rather than enabled by
default.

The development configuration keeps all three execution branches. A product
configuration should use the `ENABLE_DPD_*` parameters to prune unused RTL at
synthesis time, then select only among retained modes at runtime. The OOC
feature matrix in `syn/run_ooc_dpd_feature_matrix.ps1` is the source of PPA
evidence for those configurations.

## Latency Contract

The banked memory-polynomial engine has a fixed accepted-input-to-output
latency of ten `clk` cycles. Its complex-product output is registered before
the term reduction and Q2.14 rescale stage so that Vivado can map a dedicated
DSP output register. `dpd_frontend` aligns its bypass, LUT, and memoryless
polynomial branches to the same output epoch. Latency is fixed while a stream
is flowing; normal AXI-Stream backpressure may delay acceptance of a later
input but never reorders accepted samples.

## Safety and Rollback

Set `DPD_CTRL.bit8` to enable safety. `DPD_CTRL.bit9` is a write-one clear for
the safety-fault latch.

- An inactive-bank MP or LUT write outside `COEFF_SAFE_ABS` is rejected.
- A commit is rejected if that inactive bank contains an unsafe write. Software
  writes `DPD_CTRL.bit9=1` to abandon that invalid shadow transaction before
  reloading a complete known-safe package.
- A saturation event from the selected DPD mode latches a safety fault and
  changes subsequent accepted samples to bypass mode.
- `ERROR_STATUS.bit2` is safety fault, bit3 is rejected MP commit, and bit4 is
  rejected LUT commit. Clear the fault only after loading a known-safe package.

The active bank remains unchanged after a rejected commit. Thus the last
committed package is the rollback package. Direct memoryless polynomial
registers are intentionally not treated as an atomic calibration target; use
the banked memory-polynomial or LUT modes for closed-loop updates.

## Software and Hardware Responsibilities

| Layer | Responsibility |
|---|---|
| PL / ASIC | Fixed-point DPD execution, AXI-Stream transport, counters, coefficient banks, safety fallback |
| PS / PC | PA identification, least-squares/RLS/indirect-learning optimisation, coefficient quantization, package scoring, AXI-Lite writeback |
| RF test chain | PA, coupler, observation receiver calibration, and physical EVM/ACLR measurement |

`matlab/dpd/run_dpd_model_selection_sweep.m` is the offline complexity
selection flow. Its score combines behavioral EVM/ACLR, fixed-point clipping,
and structural multiplier/state proxies. It provides a synthesis candidate,
not an RF hardware guarantee.
