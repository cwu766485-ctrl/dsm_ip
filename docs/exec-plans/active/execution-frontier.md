# Execution frontier

## Mission

Repository organization is now tracked by
`docs/exec-plans/active/physical-migration-map.json`. The AI-native navigation
layer is generated under `docs/ai-native/`; `rtl/`, `verif/`, and `uvm_verif/`
remain canonical paths. A trial move of verification trees was reverted before
any consumer changed because the root-relative filelist/script closure was not
yet validated.

The first full TSMC28 thermo3 DC run (`syn/reports/asic_thermo3_tsmc28_20260923_213624`)
was terminated by hangup during `compile_ultra` mapping optimization. It produced
`library.rpt`, `check_design.rpt`, and `check_timing_pre.rpt`, but no final area,
setup/hold, power, DDC, or mapped-netlist reports. This is an incomplete run, not
an ASIC timing or synthesis PASS. The next attempt should use a persistent Rocky
terminal/session and a bounded DC compile strategy before retrying thermo5.

Deliver a reviewable FPGA/ASIC-oriented digital transmitter IP handoff.

- Device: `xczu15eg-ffvb1156-2-i` for FPGA evidence.
- Core cadence: `64 x 218.75 MHz = 14 GS/s` real-sample output cadence.
- Digital carrier mapping: one `Fs/4` mapping produces a 3.5 GHz IF.
- A `14 Gb/s` value refers to raw GT serial line rate, not a 14 GHz RF carrier.
- QAM acceptance uses one fixed OFDM/BPF/DDC/synchronization/demodulation path:
  EVM <= 3.5% and SNDR >= 29.12 dB.

## Active implementation

The thermo3 baseline and thermo5 extended frontend are both timing-closed
with a runtime identity memory-DPD wrapper. The wrapper is physically
implemented, with identity coefficients; it is not a DPD-free synthesis
shortcut.

```text
125 MHz AXI-S, 14 complex samples/beat
  -> asynchronous FIFO
  -> fixed 14:8 gearbox
  -> 218.75 MHz core, 8 complex samples/word
  -> Q2.14 frame gain
  -> x2 polyphase interpolator
  -> 16-lane 4-tap memory-DPD (identity coefficients)
  -> x2 polyphase interpolator
  -> 32-lane Cartesian thermometric TID
  -> two thermo3 raw planes, 64 raw bits/plane/core word
```

- Both clock domains sustain exactly 1.75 GS/s complex input throughput.
- Lane 0 is the earliest sample; interpolated lanes are new time samples,
  never zero-filled lanes.
- `frame_start` is legal only on a 56-sample superframe boundary.
- The FIFO must prefill before the recursive core is enabled.
- Underflow or a bubble in an active frame is an error.
- The pre- and post-DPD elastic slices preserve word atomicity and add only
  fixed latency; coefficients, history, quantization, ordering, and state
  update order are unchanged.

## Signed-off FPGA fabric evidence

Full routed OOC, not a Quick diagnostic:

| Item | Result |
|---|---|
| Top | `tid32_thermo3_axis_frontend_tx_ooc` |
| Flow | `opt_design -> place_design -> phys_opt_design -> route_design` |
| Core clock | 218.75 MHz (4.571 ns) |
| AXI clock | 125 MHz (8.000 ns) |
| Setup / hold | WNS `+0.290 ns`, WHS `+0.027 ns` |
| Aggregate slack | TNS/THS `0 / 0` |
| Tool result | 0 errors, 0 critical warnings |
| Core endpoints | 208,286 setup and hold endpoints, zero failing |
| AXI endpoints | 145 setup and hold endpoints, WNS/WHS `+4.966/+0.047 ns` |
| Utilization | 59,921 LUT, 83,797 FF, 6.5 BRAM, 2,030 DSP |

Artifact: `syn/out/tid32_thermo3_axis_frontend_20260921_104738/`.

The identically scoped thermo5 full routed OOC also passes at 218.75 MHz:
WNS/WHS `+0.308/+0.027 ns`, TNS/THS `0/0`, with 0 errors and 0 critical
warnings.  It uses 71,869 total LUTs (62,308 logic and 9,561 memory), 97,249
registers, 6.5 BRAM tiles, and 2,032 DSP48E2.  Artifact:
`syn/out/tid32_thermo5_axis_frontend_20260921_213551/`.

The frozen comparison is in `docs/THERMO3_THERMO5_ROUTED_PPA.md`.  Thermo5
adds 11,948 total LUTs, 13,452 registers, and 2 DSPs, while retaining slightly
more setup margin.  Both worst paths are ten-level memory-DPD DSP/carry paths.
The reported 103,766/121,078 high-fanout nets are the routed global core clock,
not failing valid/data nets.  Both variants have the same fixed core pipeline
depth and one-word-per-core-clock steady-state throughput.

The independent XPM CDC wrapper also has a routed ZU15EG result:
WNS/WHS `+1.807/+0.042 ns`, 896 LUT, 749 FF, 6.5 BRAM, and 0 DSP.
This proves neither the complete frontend nor a GT target.

## Functional evidence

- Thermo3 and thermo5 frontend MATLAB-to-XSim tests: PASS.
- Each test covers 64 input words and 2,048 final complex samples.
- Raw output mismatch: zero for every checked plane.
- Project P0 regression: 7/7 PASS, 65,536 samples/design, zero mismatch.
- IP smoke regression: 5/5 PASS.
- Generic Gray FIFO and FPGA XPM FIFO CDC tests: PASS for 112 contiguous
  samples, 14 core words, no order/frame/gain mismatch, bubble, or underflow.
- CDC executable checks cover asynchronous-assert/two-edge synchronous reset
  release, single-bit-or-zero local Gray-pointer updates, no accepted
  full/empty transaction, legal 14:8 residual populations, 56-sample frame
  boundaries, stable backpressured payload/metadata, a four-source-word FIFO
  prefill, and no core output before explicit enable.
- Thermo5 four-plane behavioral serializer loopback: PASS for 64 words and
  4,096 serial bits per path, with recovered words matching MATLAB golden
  words.  This is an ideal model and not GT or board evidence.
- Vendor-neutral raw-link bring-up/BERT endpoint XSim: PASS.  The endpoint
  implements known-word training, PRBS31 word generation/checking, link/reset
  state transitions, sticky error and error counters, clear/retrain recovery,
  single-cycle error injection, and protocol assertions.  It is connected at
  the same 64-bit user-word boundary used by `gt_tx_raw64_boundary`; it does
  not model GTH analog/CDR behavior.
- Training-to-run uses an explicit run-arm/drain cycle to absorb the one-word
  loopback latency before PRBS phase starts.  The launcher requires the PASS
  marker and rejects fatal/error diagnostics instead of trusting exit status.
- Vivado 2024.1 GT Wizard generation: PASS for ZU15EG GTH `X1Y12`, RAW
  14.0-Gb/s TX/RX, 125-MHz refclk, 64-bit user data, with synthesis and
  simulation targets generated outside the source tree.  Vendor GT behavioral
  integration and routed GT implementation remain pending; no board claim is
  made.  The BERT top now has a routed implementation entry point; the run
  completed with 0 DRC errors and positive constrained setup/hold slack, while
  vendor PRBS acquisition remains a behavioral-model limitation.
- Added a concrete GT/BERT integration top with RXSLIDE alignment, an
  asynchronous RX-word FIFO, vendor behavioral simulation script, and routed
  implementation script.  GT behavioral simulation reaches all GT ready/lock
  status outputs; PRBS acquisition still needs final closure for the model's
  variable RX latency and is not claimed PASS.

## RF-model evidence and limits

- Full frontend plus behavioural switching-DPA/BPF/DDC passes 256-QAM at
  17.08984375 MHz: identity EVM `2.3917%`, SNDR `32.4257 dB`.
- A 250 MHz thermo5 peak-normalized mild-profile simulation passed three
  isolated seeds; it is not a constant-RMS, physical-PA, or board result.
- The 4-tap memory-DPD candidate failed held-out deployment acceptance;
  active coefficients remain identity.
- DPA, BPF, ACLR, and PA results are parameterized digital simulations, not
  measured RF hardware characterization.

## Explicitly not signed off

- No four-lane physical GT/serializer timing or board mapping exists.
- Existing dual-SFP GT evidence uses a deterministic smoke payload, not this
  QAM frontend, and has no loopback/BERT/recovered-word result.
- No physical PA, coupler feedback, RF channel, antenna, or measured ACLR
  claim exists.
- OOC warnings about `HD.CLK_SRC` and `HD.PARTPIN_LOCS` are non-critical for
  this result; real top-level/GT integration must provide actual constraints.

## Current execution order

1. Add an FPGA low-power experiment: `run/idle` state, frame-boundary-only
   clock enables, FIFO watermark gating, and activity-based Vivado power
   comparison. Do not fabric-gate clocks or pause TID mid-frame.
2. Run fixed-point algorithm/PPA sweeps for interpolation taps, thermometric
   step/drive, and frame scaling. Every point must preserve bit-true
   contracts and report EVM/SNDR together with resource/timing cost.
3. Connect the completed BERT endpoint to the generated ZU15EG GT Wizard user
   port, run vendor behavioral simulation, and perform GT-aware implementation
   with the actual refclk/package XDC.  Keep physical CDR/BER/eye results
   explicitly deferred until hardware is available.
4. Add a vendor-neutral PRBS31/known-word generator and checker, link/reset
   FSM, error counters, sticky status, assertions, and behavioral error
   injection.  Keep the ideal serializer result distinct from physical GT.
   (The endpoint is implemented; next step is integration with the selected
   GT Wizard user port.)
5. When a valid 28 nm `.db` standard-cell library is supplied, build a
   separate ASIC pre-layout synthesis/STA SKU. Do not infer ASIC results
   from FPGA OOC or require analog PA/serializer libraries for digital RTL
   synthesis.
   Environment audit: Rocky-8.10 WSL has Synopsys DC V-2023.12-SP1 at
   `/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell`. The standard-cell probe
   completed successfully against the TSMC28 RVT TT `.db`, reporting 839
   cells and 15 inverter-name matches. ASIC-specific thermo3/thermo5 wrappers,
   source list, dual-clock SDC, and DC flow are now present under `syn/asic`.
   The first real thermo3 run reached mapping optimization after fixing an
   existing 8-lane wrapper width mismatch; final reports are still pending.
   The referenced SRAM `.db` path under `/home/ray/ic/CIMForge/syn/out/`
   `pdk_cache/TS1N28HPCPL2SVTB4096X32M4MWBASO_tt0p9v25c.db` is absent, so
   macro-aware synthesis remains blocked until that library is restored.
6. Perform GT/board loopback or BERT only when actual port, reference-clock,
   reset, and loopback resources are available.

## Digital-IC portfolio narrative

- Multi-clock streaming IP: rate-matched AXI ingress, asynchronous FIFO,
  reset contract, and deterministic 14:8 gearbox.
- Timing closure: converted a routing/fanout-limited `-1.524 ns` frontend
  failure into a full-flow `+0.290/+0.027 ns` setup/hold pass at 218.75 MHz
  without lowering frequency or changing numerical behavior.
- Verification: MATLAB fixed-point oracle, bit-true XSim, assertions, P0,
  IP smoke, routed STA, and explicit evidence boundaries.
- PPA trade-offs: scalable thermo3/thermo5 output architecture, pipelining,
  local valid distribution, FIFO BRAM cost, DSP use, latency, and timing.
- Low power: a measurable FPGA activity/clock-enable study that maps cleanly
  to ASIC ICG/UPF intent later, rather than an unsupported UPF claim today.
