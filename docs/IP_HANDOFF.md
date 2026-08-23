# IP Handoff

## Integration Contract

Instantiate `dsm_ip_axi_top` in a single-clock 100 MHz domain for the frozen
SKU. Drive the AXI4-Lite and TX AXI4-Stream interfaces from a bus fabric or DMA
engine. Use `aresetn` as the common active-low reset.

```text
PS or host software
  -> AXI4-Lite register writes
  -> DMA / AXI4-Stream Q1.15 I/Q
  -> DPD -> interpolation -> Fs/4 mixer -> BP EFDSM2
  -> rf_bit/rf_signed/rf_valid
```

## Software Sequence

1. Assert soft reset or hold TX traffic idle.
2. Write coefficients to the inactive DPD bank.
3. Request commit and wait for the reported safe completion.
4. Clear sticky status only after recording the source.
5. Start TX AXI4-Stream traffic and monitor counters.

The control plane must not assume that an illegal write or commit succeeds.
The active coefficient bank remains unchanged after a rejected request.

## Clocking and Physical Boundary

`rf_bit` changes only on the IP clock and is qualified by `rf_valid`. It is a
digital modulator output, not a direct PA gate-control signal. A production
implementation needs an RF clock/PLL, output retiming, complementary non-
overlap generation, level shifting, gate drive, and the selected PA/matching
network. These blocks are outside this IP handoff.

## Feedback Boundary

The optional observation input can use a separate feedback clock. Feed it only
through `dpd_observer_async_bridge`; the bridge reports drops and window status.
The IP does not include an ADC, receiver, PA, or training engine.
