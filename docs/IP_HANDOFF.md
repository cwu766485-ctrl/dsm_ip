# IP Handoff

## Deliverable

The Vivado-packaged IP top is:

```text
rtl/axi/dsm_ip_axi_top.v
```

The reusable streaming datapath is:

```text
rtl/ip/dsm_ip_top.v
rtl/ip/dsm_ip_core.sv
```

Generated IP-XACT output:

```text
ip/ip_repo/dsm_ip_1_0/component.xml
```

## Integration Interfaces

- `s_axi`: AXI-Lite style control/status interface
- `s_axis`: AXI-Stream packed Q1.15 I/Q input with `tlast` and `tuser`
- `rf_bit`, `rf_signed`, `rf_valid`: downstream RF/IF output interface

AXI-Stream packing:

```text
s_axis_tdata[15:0]  = signed Q1.15 I
s_axis_tdata[31:16] = signed Q1.15 Q
s_axis_tlast        = optional frame marker
s_axis_tuser        = optional upstream error/tag field
```

The optional observation input uses the same packing:

```text
s_axis_obs_tdata[15:0]  = signed Q1.15 observation I
s_axis_obs_tdata[31:16] = signed Q1.15 observation Q
s_axis_obs_tlast        = observation-window/frame marker
s_axis_obs_tuser[0]     = invalid observation sample
```

Observation traffic never backpressures the TX input. The observation slave
only asserts `tready` while an explicitly started training window is active.

## Register Map

| Offset | Name | Access | Description |
|---:|---|---|---|
| `0x00` | `CTRL` | RW | bit0 `enable`, bit1 `soft_reset` |
| `0x04` | `STATUS` | RO | enable/reset/valid/ready/error status |
| `0x08` | `CFG_PHASE_INC` | RW | NCO phase increment |
| `0x0C` | `ALGORITHM` | RO | compiled DSM algorithm ID |
| `0x10` | `DUC_MODE` | RO | compiled DUC mode |
| `0x14` | `VERSION` | RO | wrapper version |
| `0x18` | `INPUT_SAMPLE_COUNT` | RO | accepted AXI-Stream samples |
| `0x1C` | `OUTPUT_SAMPLE_COUNT` | RO | emitted RF samples |
| `0x20` | `SOFTWARE_RESET_COUNT` | RO | software reset trigger count |
| `0x24` | `ERROR_STATUS` | RW1C | sticky error bits |
| `0x28` | `FRONTEND_SAMPLE_COUNT` | RO | samples accepted by the interpolation/DSM frontend |
| `0x2C` | `INPUT_STALL_COUNT` | RO | AXI-Stream backpressure stall cycles |
| `0x30` | `INTERP_MODE` | RO | compiled interpolation mode |
| `0x34` | `INPUT_FRAME_COUNT` | RO | accepted AXI-Stream samples with `tlast=1` |
| `0x38` | `LAST_TUSER` | RO | last accepted AXI-Stream `tuser` value |
| `0x3C` | `USER_ERROR_COUNT` | RO | accepted AXI-Stream samples with nonzero `tuser` |
| `0x40` | `DPD_CTRL` | RW | `DPD_CTRL[1:0]`: 0 bypass, 1 polynomial DPD, 2 LUT DPD, 3 memory-polynomial DPD |
| `0x44` | `DPD_C1` | RW | packed Q2.14 coefficient `{c1_im, c1_re}` |
| `0x48` | `DPD_C3` | RW | packed Q2.14 coefficient `{c3_im, c3_re}` |
| `0x4C` | `DPD_C5` | RW | packed Q2.14 coefficient `{c5_im, c5_re}` |
| `0x50` | `DPD_SAMPLE_COUNT` | RO | samples accepted by the DPD frontend |
| `0x54` | `DPD_SATURATION_COUNT` | RO | DPD output saturation count |
| `0x58` | `DPD_LUT_ADDR` | RW | LUT DPD table address |
| `0x5C` | `DPD_LUT_DATA` | RW | packed Q2.14 LUT gain `{gain_im, gain_re}` |
| `0x60` | `DPD_LUT_COMMIT` | RW/RO | write bit0 to swap LUT bank, read bit0 active bank |
| `0x64` | `MON_INPUT_POWER` | RO | accumulated input magnitude-power proxy |
| `0x68` | `MON_OUTPUT_POWER` | RO | accumulated RF output magnitude-power proxy |
| `0x6C` | `MON_CLIP_COUNT` | RO | input near-full-scale clipping proxy count |
| `0x70` | `MON_PEAK` | RO | packed `{output_peak[15:0], input_peak[15:0]}` |
| `0x74` | `MON_AVG_MAG` | RO | packed EWMA `{output_avg[15:0], input_avg[15:0]}` |
| `0x78` | `MON_EVM_PROXY` | RO | accumulated DPD correction-magnitude proxy |
| `0x7C` | `MON_ACPR_PROXY` | RO | accumulated RF slew proxy |
| `0x80` | `MON_SPEC_BIN0` | RO | fixed-bin spectral proxy at DC/leakage bin |
| `0x84` | `MON_SPEC_BIN1` | RO | fixed-bin spectral proxy at Fs/4 carrier bin |
| `0x88` | `MON_SPEC_BIN2` | RO | fixed-bin spectral proxy at Fs/2 high-frequency bin |
| `0x8C` | `MON_SPEC_ADJ` | RO | adjacent/out-of-band spectral proxy, `BIN0 + BIN2` |
| `0x90` | `MP_SELECT` | RW | tap `[1:0]`, order selector `[3:2]` (`0/1/2` = `C1/C3/C5`), active taps `[10:8]` (`2..4`) |
| `0x94` | `MP_DATA` | RW | inactive-bank packed Q2.14 coefficient `{imag, real}` |
| `0x98` | `MP_COMMIT` | RW/RO | write bit0 to atomically swap coefficient bank; read active bank |
| `0x9C` | `OBS_CTRL` | RW | bit0 enable, bit1 start, bit2 clear, delay `[12:8]` (`0..31`) |
| `0xA0` | `OBS_GAIN` | RW | programmed Q2.14 complex alignment gain `{imag, real}` |
| `0xA4` | `OBS_WINDOW` | RW | paired-sample target; zero means run until software stops/clears |
| `0xA8` | `OBS_STATUS` | RO | bit0 ready, bit1 active, bit2 done, bit3 `tlast` seen |
| `0xAC` | `OBS_PAIR_COUNT` | RO | valid aligned reference/observation pairs |
| `0xB0` | `OBS_DROP_COUNT` | RO | invalid or unavailable-reference observations |
| `0xB4` | `OBS_ERROR_LO` | RO | aligned L1 error accumulator `[31:0]` |
| `0xB8` | `OBS_ERROR_HI` | RO | aligned L1 error accumulator `[63:32]` |
| `0xBC` | `CONDITION_CTRL` | RW | bit0 valid, condition ABI version `[15:8]` (current `1`) |
| `0xC0` | `CONDITION_QAM` | RW | modulation order (`16` or `64` in the qualified table) |
| `0xC4` | `CONDITION_BW_KHZ` | RW | occupied bandwidth in kHz (`20000` or `40000` trained anchors) |
| `0xC8` | `CONDITION_BACKOFF_PPM` | RW | normalized input backoff in ppm (`580000` or `700000` anchors) |
| `0xCC` | `CONDITION_ENV` | RW | signed Q8.8 `{temperature_degC, power_dB}` |
| `0xD0` | `CONDITION_MONITOR` | RW | runtime fault/state bits; any of `[3:0]` forces fallback |
| `0xD4` | `SEED_STATUS` | RO | seed `[2:0]`, known bit3, fallback bit4, local-search-required bit5 |
| `0xD8` | `OBS_ENV` | RO | `{schema_version=2, reserved, latched_temperature_q8_8}` |
| `0xDC` | `OBS_REF_MAG` | RO | aligned valid-reference `sum(|I|+|Q|)` |
| `0xE0` | `OBS_MAG` | RO | saturated aligned-observation `sum(|I|+|Q|)` |
| `0xE4` | `OBS_PEAK` | RO | peak saturated aligned-observation `|I|+|Q|` |
| `0xE8` | `OBS_CLIP_SAT` | RO | packed `{saturation_count[15:0], clip_count[15:0]}` |
| `0xEC` | `OBS_SLEW` | RO | complex first-difference proxy `sum(|dI|+|dQ|)` |
| `0xF0` | `OBS_SPEC_BIN0` | RO | complex fixed-bin magnitude proxy at DC |
| `0xF4` | `OBS_SPEC_BIN1` | RO | complex fixed-bin magnitude proxy at Fs/4 |
| `0xF8` | `OBS_SPEC_BIN2` | RO | complex fixed-bin magnitude proxy at Fs/2 |
| `0xFC` | `OBS_SPEC_ADJ` | RO | saturated `OBS_SPEC_BIN0 + OBS_SPEC_BIN2` |

`ALGORITHM`, `DUC_MODE`, and `INTERP_MODE` are compile-time parameters in this
release. Their read-only registers report the selected hardware build; they do
not switch a runtime mux.

`CTRL[1]` is a software reset trigger pulse. `CTRL[2]` clears status counters
and sticky errors. Legal AXI-Stream backpressure increments
`INPUT_STALL_COUNT`; it is not a sticky error. `ERROR_STATUS[0]` is set when
AXI-Stream input is asserted while the IP is disabled or held in reset.
`ERROR_STATUS[1]` is set when an accepted input sample has nonzero `tuser`.

The DPD frontend is inserted before `dsm_ip_top` in the AXI wrapper. It is in
bypass mode by default and uses identity coefficients/LUT entries, so existing
DSM behavior is preserved unless software selects another `DPD_CTRL[1:0]`
mode. DPD input/output samples are signed Q1.15 complex I/Q; DPD coefficients
and LUT gains are signed Q2.14 complex values.

Current DPD modes:

```text
0: bypass
1: memoryless polynomial DPD
2: amplitude-indexed LUT DPD
3: 2-to-4-tap memory polynomial DPD
```

Memory-polynomial mode implements
`sum_m x[n-m]*(C1[m] + C3[m]|x[n-m]|^2 + C5[m]|x[n-m]|^4)`.
Its four-tap coefficient table is double-buffered; software writes the inactive
bank through `MP_SELECT/MP_DATA` and then commits once. Mode 0/1/2 arithmetic,
latency, and register addresses remain unchanged.

The DPD frontend is internally pipelined. The polynomial path registers the
square, radius, coefficient multiply, gain accumulation, complex multiply, and
saturation stages. Bypass and LUT modes are delayed to match the polynomial
path so the mode-selected output remains sample-aligned under AXI-Stream
backpressure. This changes latency only; the fixed-point output sequence is
kept bit-true against the MATLAB DPD reference.

LUT and memory-polynomial coefficients use shadow banks and commit pulses, so a
complete table can be prepared without exposing a partial update to streaming
data.

The observation block uses a 32-sample reference ring. `OBS_CTRL.delay=0`
pairs a same-cycle TX reference; delay `N` selects the reference accepted `N`
samples earlier. `OBS_GAIN` and delay are programmed by software. Automatic
delay/gain estimation and formal EVM/ACLR calculation are not implemented in
this block.

Wrapper version `0x00010002` adds observation schema
`aligned_complex_pa_monitor_v2`. On `OBS_CTRL.start`, the block clears all
window statistics and latches the signed Q8.8 temperature from
`CONDITION_ENV`. Only valid aligned pairs update the statistics. The complex
gain result is saturated to Q1.15 before magnitude, clip, slew, and fixed-bin
spectral proxies are calculated; `OBS_ERROR_LO/HI` retains its previous
unsaturated wide-alignment L1 definition. Clip means either saturated aligned
component has magnitude at least 31130. Saturation means either pre-saturation
aligned component lies outside signed 16-bit range.

`OBS_PAIR_COUNT` is the sample-count denominator and `OBS_MAG / OBS_PAIR_COUNT`
is the arithmetic average-magnitude proxy. The 32-bit sum and spectral
accumulators use finite-width hardware arithmetic, so software must select a
bounded window that cannot overflow for the intended signal level. These
multiplier-free fixed-bin and slew values are calibration features, not formal
ACLR or EVM measurements.

The runtime seed predictor accepts QAM, bandwidth, backoff, power, temperature,
and monitor state. It reports the nearest trained seed package (`2` near 0.58
backoff, `5` near 0.70) and fails closed for unknown/version-mismatched or
faulted conditions. `local-search-required` is intentionally always one: the
qualified AI policy still requires the 14-candidate bounded search.

The monitor registers are low-cost PL observability metrics for PS-side
calibration. They are intended to rank DPD packages and catch clipping,
saturation, spectral leakage, and abnormal activity on board. The spectral
proxy uses multiplier-free fixed-bin accumulators over `rf_signed`: `BIN0`
tracks DC/leakage, `BIN1` tracks the Fs/4 carrier bin, `BIN2` tracks the Fs/2
bin, and `MON_SPEC_ADJ` combines `BIN0 + BIN2` as a lightweight adjacent-band
penalty. These registers are not a replacement for offline EVM/ACLR/SNDR
measurement with a defined reconstruction or receiver chain.

## ZU15EG Bring-Up

The current board-validation target is the user's `xczu15eg-ffvb1156-1-i`
MPSoC board. The recommended first loop is:

```text
PS DDR
-> AXI DMA MM2S
-> DSM IP s_axis
-> rf_valid/rf_signed
-> ILA
```

Bring-up notes and helper scripts are under:

```text
fpga/zu15eg
```

## Default Configuration

```text
Clock              = 100 MHz
Default DUC mode   = fixed Fs/4
Default IF center  = 25 MHz
Input format       = signed Q1.15 I/Q
```

## Boundary

This handoff is an RTL/IP package with verification and synthesis evidence. It
is not a complete RFSoC4x2 bitstream-ready board project.

RFSoC board files, schematics, BOMs, reference manuals, and vendor board
packages are local-only collateral and should not be published unless
redistribution rights are confirmed.
