# Feedback Subsystem

## Scope

```text
asynchronous observation AXI-Stream
  -> dpd_observer_async_bridge
  -> dpd_observer window and monitor statistics
```

The subsystem test uses unrelated 166.7 MHz feedback and 100 MHz observer
clocks, a four-entry bridge FIFO, strict source backpressure, invalid-beat
propagation, and a zero-delay/identity-gain observation contract.

## DUT Boundary

- `rtl/dpd/dpd_observer_async_bridge.v`
- `rtl/dpd/dpd_observer.v`

## Evidence

On 2026-08-12, the following test passed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_feedback_subsystem.ps1
```

It transferred 129 feedback beats through the asynchronous bridge. The observer
reported 117 valid pairs, 12 invalid drops, zero error accumulation, 191 source
stall cycles, zero FIFO drops, no overflow flags, and an observed final beat.
The test validates the digital transport and monitor state contract. It does not
model a physical PA, ADC, or calibrated RF receiver.
