# ZU15EG PS-Side DPD Control

This directory contains the first PS-side control layer for the DSM TX IP.
It moves coefficient updates from PC/XSDB bring-up toward the target MPSoC
architecture:

```text
PS Linux / bare-metal C / Python
  -> calibration / ML / optimization
  -> AXI-Lite writes DPD coefficients or LUT entries
  -> AXI DMA sends I/Q samples
  -> PL DPD + interpolation + DSM
```

The current script uses Linux `/dev/mem` for direct AXI-Lite register access.
It is a bring-up helper, not a production driver. A production system should
prefer UIO, a kernel driver, or a bare-metal/Vitis application with the same
register map.

## Usage

Read status:

```bash
sudo python3 dsm_dpd_ps_control.py --dsm-base 0xA0010000 status
```

Enable polynomial DPD:

```bash
sudo python3 dsm_dpd_ps_control.py --dsm-base 0xA0010000 poly \
  --c1 0xFFFB4009 \
  --c3 0xF1A41F6F \
  --c5 0xDE503A39
```

Enable LUT DPD with unity gain in all 16 bins:

```bash
sudo python3 dsm_dpd_ps_control.py --dsm-base 0xA0010000 lut \
  --lut-default 0x00004000
```

Enable LUT DPD with selected bin overrides:

```bash
sudo python3 dsm_dpd_ps_control.py --dsm-base 0xA0010000 lut \
  --lut-default 0x00004000 \
  --lut-entry 0=0xFFF3401D \
  --lut-entry 15=0xFAED4A4C
```

Disable DPD:

```bash
sudo python3 dsm_dpd_ps_control.py --dsm-base 0xA0010000 bypass
```

Use `--dry-run` on a PC or non-board Linux host to print the AXI-Lite accesses
without opening `/dev/mem`.

From the Windows development PC, copy and run the helper over SSH:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\ps_linux\run_ps_dpd_control_over_ssh.ps1 `
  -HostName <board-ip> `
  -User root `
  -DsmBase 0xA0010000 `
  -Mode status
```

The wrapper intentionally does not contain passwords, private server addresses,
or board-specific credentials.

## Current Boundary

This helper configures the PL DPD block. It does not yet start AXI DMA or run
the full calibration algorithm on PS. The current MATLAB sweep remains the
coefficient generator; the next step is to port a small calibration loop to
PS-side Python or C.
