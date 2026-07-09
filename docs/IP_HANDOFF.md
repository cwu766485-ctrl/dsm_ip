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
| `0x40` | `DPD_CTRL` | RW | `DPD_CTRL[1:0]`: 0 bypass, 1 polynomial DPD, 2 LUT DPD, 3 reserved |
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
3: reserved for memory polynomial DPD
```

The DPD frontend is internally pipelined. The polynomial path registers the
square, radius, coefficient multiply, gain accumulation, complex multiply, and
saturation stages. Bypass and LUT modes are delayed to match the polynomial
path so the mode-selected output remains sample-aligned under AXI-Stream
backpressure. This changes latency only; the fixed-point output sequence is
kept bit-true against the MATLAB DPD reference.

LUT updates are single-buffered. Software should update `DPD_LUT_ADDR` and
`DPD_LUT_DATA` while the stream is idle or after software reset.

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
