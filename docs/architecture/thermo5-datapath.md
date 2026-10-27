# Thermo5 Datapath and Ingress Buffering

## Current modulation default

The main thermo5 path now defaults to centered-cubic x2 interpolation and the
fixed-point second-order EF2 TIDSM with `STEP=5120`. Each interpolation stage
uses `[-1, 9, 9, -1]/16` at the half-sample phase; stage 1 provides a tagged
synthetic lookahead vector to flush frame tails while preserving one output
word per input word. The causal polyphase interpolator remains selectable
with `INTERP_CENTERED_CUBIC=0`. EF2 preserves sample chronology but is
implemented as a 32-sample combinational chain. Its generic-FIFO, AXI-Lite,
long-frame, clamp/recovery, and behavioral serializer VCS checks pass; FPGA
timing and resource use have not been measured. See
`docs/verification/thermo5-ef2-stability.md` for the proof scope and
qualification limits.

## Ingress, asynchronous FIFO, and gearbox

The source AXI-Stream interface carries 14 complex I/Q samples per accepted
beat at 125 MHz. The core interface consumes 8 complex samples per accepted
word at 218.75 MHz. Their nominal payload rates match:

```text
14 samples/beat × 125 MHz = 8 samples/word × 218.75 MHz
                           = 1.75 Gcomplex samples/s
```

`dsm_axis14_to_core8_cdc.sv` contains both clock domains. The selected
asynchronous FIFO stores a complete source beat and its frame-start/gain
metadata; FIFO pointer/control logic crosses domains. The generic implementation
is the project's RTL (`dsm_async_fifo.sv`). The thermo5 FPGA top defaults to
the AMD `xpm_fifo_async` implementation through `dsm_xpm_async_fifo.sv`.
Simulation and implementation can select either, but ZU15EG FPGA synthesis
uses XPM by default.

The gearbox is **not** another clock-domain crossing. Its residual-sample
buffer, output register, and 14-to-8 repacking state all run on `core_clk`.
It reads FIFO entries as needed, emits eight consecutive samples, and retains
the leftover samples for the next output word. The residual lane count cycles
through `0, 6, 12, 4, 10, 2, 8`; after seven core words the sequence returns to
zero. Thus four 14-lane source beats (56 samples) become seven 8-lane core
words, without changing sample order or numerical values.

## Current FIFO sizing

The current default is `FIFO_ADDR_W=4`, hence `2^4=16` complete source-beat
entries. In the frozen W=16 configuration, each entry is
`2 × 14 × 16 + 1 frame-start bit + 16 gain bits = 465 bits`; 16 entries hold
7,440 payload bits (930 bytes), excluding pointers and control logic.

The 16-entry choice is elastic buffering, not a way to increase steady-state
bandwidth: the two sides already have equal nominal sample throughput. At
125 MHz, 16 entries correspond to 128 ns of source beats if the core consumes
nothing and the FIFO starts empty. Actual remaining stall headroom is
`16 - current_occupancy` beats. Once full, AXI backpressure must stop the
source without losing data.

When the optional low-power controller is enabled, its default policy
pre-fills four source beats (one 56-sample superframe) before enabling the
core; that is a startup threshold, not the FIFO's total depth. The frozen SKU
currently has low-power control disabled. A 16-entry FIFO cannot absorb an
entire 32-beat frame while the consumer is stopped. If a future system contract requires accepting a
whole 32-beat frame without source backpressure, the depth must be at least 32
entries plus any desired margin, or the system must provide another buffering
policy. Therefore 16 is the current implementation default, not a claim that
it is universally optimal; changing the pause/burst contract requires a new
depth calculation and full/near-full/empty stress tests.

## Main signal-processing path

```text
AXI-Stream 14-lane / 125 MHz
  -> AFIFO + core-clock 14:8 gearbox
  -> frame gain
  -> centered-cubic x2 interpolation (8 -> 16)
  -> Memory-Polynomial DPD (frozen SKU: identity 1-tap)
  -> centered-cubic x2 interpolation (16 -> 32)
  -> four offset TID32/Fs4 branches
  -> four aligned 64-bit digital PA-code planes
  -> raw GT-user continuous-transmit/idle boundary
```

The AXI-Lite wrapper is optional control-plane logic for DPD tap/coefficient
configuration and run control. It is not part of the base frozen SKU's AXI-
Stream datapath.
