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
- `s_axis`: AXI-Stream packed Q1.15 I/Q input
- `rf_bit`, `rf_signed`, `rf_valid`: downstream RF/IF output interface

AXI-Stream packing:

```text
s_axis_tdata[15:0]  = signed Q1.15 I
s_axis_tdata[31:16] = signed Q1.15 Q
```

## Register Map

| Offset | Name | Access | Description |
|---:|---|---|---|
| `0x00` | `CTRL` | RW | bit0 `enable`, bit1 `soft_reset` |
| `0x04` | `STATUS` | RO | enable/reset/valid/ready status |
| `0x08` | `CFG_PHASE_INC` | RW | NCO phase increment |
| `0x0C` | `ALGORITHM` | RO | compiled DSM algorithm ID |
| `0x10` | `DUC_MODE` | RO | compiled DUC mode |
| `0x14` | `VERSION` | RO | wrapper version |

`ALGORITHM` and `DUC_MODE` are compile-time parameters in this release.

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
