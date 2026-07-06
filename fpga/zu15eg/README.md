# ZU15EG Bring-Up

This folder contains public, source-only bring-up notes for validating the DSM
IP on an `xczu15eg-ffvb1156-1-i` MPSoC board.

Private board schematics, board files, vendor examples, license files, server
addresses, and local capture data must stay outside the public repository.

## First Board Goal

Build the smallest PS-to-PL validation loop:

```text
Zynq UltraScale+ PS
-> AXI DMA MM2S
-> DSM IP s_axis
-> interpolation frontend
-> DSM core
-> Fs/4 DUC
-> rf_valid / rf_signed
-> ILA probes
```

The first board pass does not need an external DAC or high-speed connector. The
goal is to prove that software can configure the IP, stream known I/Q samples,
and observe expected PL activity with ILA.

## Recommended Configuration

Start with the lightest compiled configuration:

```text
ALGORITHM   = 2   EFDSM 1-bit
INTERP_MODE = 0   bypass
DUC_MODE    = 0   fixed Fs/4
Clock       = 100 MHz
```

After the baseline works, test the heavier routed-OOC configurations:

```text
ALGORITHM=6,  INTERP_MODE=4
ALGORITHM=12, INTERP_MODE=4
```

These two combinations already have retained ZU15EG routed OOC evidence in
`docs/evidence/ooc`.

## Register Smoke Sequence

Software should perform this minimum sequence:

1. Read `VERSION`, `ALGORITHM`, `DUC_MODE`, and `INTERP_MODE`.
2. Write `CTRL=0x00000004` to clear counters and sticky status.
3. Write `CTRL=0x00000002` to issue software reset.
4. Write `CTRL=0x00000001` to enable the IP.
5. Start AXI DMA MM2S with a known packed I/Q vector.
6. Poll `INPUT_SAMPLE_COUNT`, `FRONTEND_SAMPLE_COUNT`, `OUTPUT_SAMPLE_COUNT`,
   `INPUT_STALL_COUNT`, `INPUT_FRAME_COUNT`, and `ERROR_STATUS`.

Useful register offsets:

| Offset | Name |
|---:|---|
| `0x00` | `CTRL` |
| `0x04` | `STATUS` |
| `0x0C` | `ALGORITHM` |
| `0x10` | `DUC_MODE` |
| `0x14` | `VERSION` |
| `0x18` | `INPUT_SAMPLE_COUNT` |
| `0x1C` | `OUTPUT_SAMPLE_COUNT` |
| `0x24` | `ERROR_STATUS` |
| `0x28` | `FRONTEND_SAMPLE_COUNT` |
| `0x2C` | `INPUT_STALL_COUNT` |
| `0x30` | `INTERP_MODE` |
| `0x34` | `INPUT_FRAME_COUNT` |
| `0x38` | `LAST_TUSER` |
| `0x3C` | `USER_ERROR_COUNT` |

## ILA Probes

Probe these first:

```text
s_axis_tvalid
s_axis_tready
s_axis_tdata
s_axis_tlast
s_axis_tuser
rf_valid
rf_signed
dsm_valid
i_yout
q_yout
phase_acc_dbg
```

Expected first-pass behavior:

- `s_axis_tready` can toggle under interpolation backpressure.
- `INPUT_SAMPLE_COUNT` increments on accepted AXI-Stream samples.
- `FRONTEND_SAMPLE_COUNT` increments on samples accepted by the interpolation
  and DSM frontend.
- `OUTPUT_SAMPLE_COUNT` increments when `rf_valid` is high.
- `ERROR_STATUS` remains zero for a clean stream with `tuser=0`.

## Scripts

| Path | Purpose |
|---|---|
| `scripts/create_dsm_dma_ila_bd.tcl` | Vivado block-design template for PS, AXI DMA, DSM IP, and ILA integration |
| `scripts/pack_p0_iq_for_dma.py` | Packs existing P0 I/Q MEM vectors into a 32-bit DMA binary |

The BD script is intentionally a template because MPSoC PS DDR/MIO setup is
board-specific. Create or import the PS configuration from the board vendor
flow first, then source the template to add the DSM validation datapath.
