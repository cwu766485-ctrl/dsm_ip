# DSM IP

Reusable digital delta-sigma modulator IP for an all-digital transmitter path.
The repository contains fixed-point MATLAB models, synthesizable RTL, XSim
testbenches, Vivado IP packaging, and out-of-context synthesis evidence.

## Scope

The current release keeps seven DSM structures:

| ID | Algorithm | RTL core |
|---:|---|---|
| 0 | LPDSM | `rtl/dsm/singlebit/dsm_core.sv` |
| 1 | LPDSM2 | `rtl/dsm/singlebit/dsm_core_dsm2.sv` |
| 2 | EFDSM | `rtl/dsm/singlebit/dsm_core_ef1.sv` |
| 3 | EFDSM2 | `rtl/dsm/singlebit/dsm_core_ef2.sv` |
| 4 | MASH11 | `rtl/dsm/singlebit/dsm_core_mash11.sv` |
| 5 | MASH111 | `rtl/dsm/singlebit/dsm_core_mash111.sv` |
| 6 | MASH22 | `rtl/dsm/singlebit/dsm_core_mash22.sv` |

The default P0 profile is a 16-QAM OFDM stream at a 100 MHz DSM clock. The
fixed Fs/4 DUC path places the default IF center at 25 MHz.

## IP Architecture

The Vivado-packaged top is:

```text
rtl/axi/dsm_ip_axi_top.v
```

Internal hierarchy:

```text
dsm_ip_axi_top
  -> AXI-Lite control/status
  -> AXI-Stream packed I/Q input
  -> dsm_ip_top
     -> dsm_ip_core
        -> DSM algorithm core
        -> Fs/4 or NCO DUC
```

`dsm_ip_top.v` remains a non-AXI streaming wrapper for reuse in testbenches or
custom integrations. `dsm_ip_axi_top.v` adds the SoC/RFSoC-facing register and
stream interfaces used by the packaged IP.

## Interfaces

### AXI-Lite Control

| Offset | Name | Access | Description |
|---:|---|---|---|
| `0x00` | `CTRL` | RW | bit0 `enable`, bit1 `soft_reset` |
| `0x04` | `STATUS` | RO | bit0 enable, bit1 soft_reset, bit2 dsm_valid, bit3 rf_valid, bit4 s_axis_tready |
| `0x08` | `CFG_PHASE_INC` | RW | NCO phase increment, default `24'h400000` |
| `0x0C` | `ALGORITHM` | RO | compiled DSM algorithm ID |
| `0x10` | `DUC_MODE` | RO | compiled DUC mode |
| `0x14` | `VERSION` | RO | wrapper version, currently `0x00010000` |

Register behavior:

- `CTRL.enable` enables input acceptance and datapath operation.
- `CTRL.soft_reset` resets the DSM/DUC datapath state while leaving the AXI
  register interface accessible.
- `STATUS` exposes the current enable/reset state and datapath ready/valid
  flags.
- `CFG_PHASE_INC` is used only when `DUC_MODE=1`.
- `ALGORITHM` and `DUC_MODE` are read-only because they are compile-time
  parameters in this release.

For an NCO DUC with `PHASE_W=24`:

```text
phase_inc = round(f_if / f_clk * 2^PHASE_W)
```

### AXI-Stream Input

The input stream is a continuous 32-bit packed I/Q sample stream:

```text
s_axis_tdata[15:0]  = signed Q1.15 I
s_axis_tdata[31:16] = signed Q1.15 Q
s_axis_tvalid       = sample valid
s_axis_tready       = IP can accept a sample
```

The wrapper does not use `tlast`, `tkeep`, `tid`, or `tdest`.

### Outputs

Primary outputs:

- `dsm_valid`
- `i_bit`, `q_bit`
- `i_yout`, `q_yout`
- `rf_valid`
- `rf_bit`
- `rf_signed`
- `phase_acc_dbg`

## DUC Modes

`DUC_MODE=0` selects the fixed Fs/4 path. With a 100 MHz clock:

```text
f_if = 100 MHz / 4 = 25 MHz
```

`DUC_MODE=1` selects the NCO mixer path. This path is included for integration
experiments; the fixed Fs/4 path is the primary low-resource configuration.

## P0 QAM-OFDM Profile

| Parameter | Value |
|---|---:|
| Modulation | 16-QAM |
| `Nfft` | 64 |
| `Ncp` | 16 |
| `Nsym` | 500 |
| Active subcarriers | 52, DC null |
| `OSR` | 32 |
| DSM clock / sample rate | 100 MHz |
| Baseband sample rate | 3.125 MHz |
| Subcarrier spacing | 48.828125 kHz |
| Default Fs/4 IF center | 25 MHz |

The IP does not include a programmable interpolation or channel-filter chain.
The input stream is expected to already be at the DSM sample rate.

## Verification

Run MATLAB/RTL bit-true comparison:

```powershell
.\scripts\run_matlab_p0_bittrue_check.cmd
```

Current evidence file:

```text
matlab/out/p0_bittrue_compare.csv
```

Result summary:

```text
LPDSM    Mismatches = 0
LPDSM2   Mismatches = 0
EFDSM    Mismatches = 0
EFDSM2   Mismatches = 0
MASH11   Mismatches = 0
MASH111  Mismatches = 0
MASH22   Mismatches = 0
```

Run the seven-path XSim regression:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
```

Run the IP smoke tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
```

The IP smoke tests cover the streaming top, the NCO path, and the AXI wrapper
register/stream handshake.

## Vivado IP Packaging

Package the IP:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1
```

Generated IP-XACT output:

```text
ip/ip_repo/dsm_ip_1_0/component.xml
```

The packaged component exposes:

```text
modelName = dsm_ip_axi_top
s_axi     = AXI memory-mapped interface
s_axis    = AXI-Stream interface
aclk      = 100 MHz default clock metadata
```

## OOC Synthesis Evidence

Run proxy OOC synthesis:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xczu48dr-ffvg1517-2-e
```

Summary files:

```text
docs/evidence/ooc/p0_ooc_xc7z020_20260702_summary.csv
docs/evidence/ooc/p0_ooc_xczu48dr_20260702_summary.csv
```

On `xc7z020clg400-1`, LPDSM, EFDSM, and EFDSM2 meet the 100 MHz proxy OOC
target in the current run. On `xczu48dr-ffvg1517-2-e`, all seven retained paths
meet the 100 MHz proxy OOC target.

## RFSoC 4x2 Collateral

RFSoC 4x2 board files, schematics, BOMs, reference manuals, and vendor board
packages are local-only collateral. They are not included in the public
repository unless redistribution rights are explicitly confirmed.

Use a private local copy for:

```text
fpga/hardware/rfsoc4x2_board_files/
fpga/hardware/4x2_PL_FULL_CONSTRAINTS/
fpga/hardware/4x2_PL_FULL_CONSTRAINTS/4x2_SYZYGY.xdc
```

This handoff is not a complete board-ready Vivado project. The current tree
does not include a closed RFSoC `.xpr`, implementation run, bitstream, `.hwh`,
`.xsa`, or board execution script.

## Directory Map

| Path | Purpose |
|---|---|
| `rtl/dsm` | DSM algorithm cores |
| `rtl/duc` | Fs/4 and NCO DUC blocks |
| `rtl/ip` | Reusable streaming DSM datapath |
| `rtl/axi` | AXI-Lite/AXI-Stream wrapper |
| `rtl/top` | ROM-backed P0 tops |
| `matlab/bittrue` | MATLAB fixed-point reference models |
| `matlab/scripts` | MATLAB entry scripts |
| `verif/tb` | XSim testbenches |
| `verif/vectors` | ROM input vectors |
| `syn` | OOC synthesis flow |
| `ip` | Vivado IP packaging |
| `docs` | Architecture, status, and evidence |
| `fpga/rfsoc4x2` | Historical source-only RFSoC board fragments |

See `docs/PROJECT_MAP.md` for the expanded file map.

## Public GitHub Release

Before publishing this repository publicly, review:

```text
docs/GITHUB_RELEASE_CHECKLIST.md
```

Do not publish restricted RFSoC board PDFs, schematics, BOMs, or board files.
Keep them in a private local archive and document the expected local path if a
board flow is restored later.
