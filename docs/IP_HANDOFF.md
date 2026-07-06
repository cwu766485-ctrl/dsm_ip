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

`ALGORITHM`, `DUC_MODE`, and `INTERP_MODE` are compile-time parameters in this
release. Their read-only registers report the selected hardware build; they do
not switch a runtime mux.

`CTRL[1]` is a software reset trigger pulse. `CTRL[2]` clears status counters
and sticky errors. Legal AXI-Stream backpressure increments
`INPUT_STALL_COUNT`; it is not a sticky error. `ERROR_STATUS[0]` is set when
AXI-Stream input is asserted while the IP is disabled or held in reset.
`ERROR_STATUS[1]` is set when an accepted input sample has nonzero `tuser`.

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
