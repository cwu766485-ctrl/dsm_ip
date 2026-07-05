# IP Specification

## Scope

This IP release contains the seven P0 DSM comparison paths:

- LPDSM
- LPDSM2
- EFDSM
- EFDSM2
- MASH11
- MASH111
- MASH22

The current RTL/bit-true release scope is single-bit sign-domain DSM for LPDSM,
LPDSM2, EFDSM, EFDSM2 and native signed MASH outputs for MASH11, MASH111, and
MASH22.

Exploratory multibit Cartesian DSM models are provided under:

```text
matlab/cartesian_dsm/dsm_multibit
rtl/dsm/multibit
```

The multibit RTL is covered by MATLAB/RTL bit-true comparison over the P0
65536-sample vectors. It closes the 100 MHz OOC target on the conservative
`xczu15eg-ffvb1156-1-i` target, while two multibit modes still miss timing on
the smaller `xc7z020clg400-1` proxy target.

## Interfaces

Common RTL wrapper interface:

- `clk`
- `rst_n`
- `enable`
- Q1.15 I/Q input or ROM-backed I/Q source
- `rf_valid`
- `rf_bit` for 1-bit sign-domain paths
- `rf_signed` / native multibit `yout` for MASH paths

Reusable IP top:

- `dsm_ip_axi_top`
- AXI-Lite style control/status slave: `s_axi`
- AXI-Stream I/Q sample input: `s_axis`
- `dsm_ip_core`
- streaming datapath wrapper: `dsm_ip_top`
- streaming Q1.15 `i_in` / `q_in`
- `in_valid` input
- `rf_valid`, `rf_bit`, `rf_signed` output
- `ALGORITHM` parameter selects LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11,
  MASH111, MASH22, or exploratory multibit Cartesian modes
- `DUC_MODE=0`: fixed Fs/4 upconversion
- `DUC_MODE=1`: NCO upconversion, controlled by `cfg_phase_inc`
- `phase_acc_dbg` exposes the Fs/4 phase or NCO phase accumulator

The packaged IP now includes the SoC/RFSoC wrapper:

- AXI-Lite style `s_axi` controls enable, soft reset, and `cfg_phase_inc`
- AXI-Stream `s_axis` feeds packed Q1.15 I/Q samples
- a downstream 1-bit PA driver, DAC-facing logic, serializer, or RF digital
  backend consuming `rf_signed/rf_bit`

## AXI-Lite Register Map

| Offset | Name | Access | Description |
|---:|---|---|---|
| `0x00` | `CTRL` | RW | bit0 `enable`, bit1 software reset trigger, bit2 clear status |
| `0x04` | `STATUS` | RO | enable/reset/valid/ready/error status |
| `0x08` | `CFG_PHASE_INC` | RW | NCO phase increment |
| `0x0C` | `ALGORITHM` | RO | compiled DSM algorithm ID |
| `0x10` | `DUC_MODE` | RO | compiled DUC mode |
| `0x14` | `VERSION` | RO | wrapper version |
| `0x18` | `INPUT_SAMPLE_COUNT` | RO | accepted AXI-Stream sample count |
| `0x1C` | `OUTPUT_SAMPLE_COUNT` | RO | emitted RF sample count |
| `0x20` | `SOFTWARE_RESET_COUNT` | RO | software reset trigger count |
| `0x24` | `ERROR_STATUS` | RW1C | sticky error bits |
| `0x28` | `FRONTEND_SAMPLE_COUNT` | RO | samples accepted by the interpolation/DSM frontend |
| `0x2C` | `INPUT_STALL_COUNT` | RO | AXI-Stream backpressure stall cycles |

`STATUS[0]` is `enable`, `STATUS[1]` is the one-cycle software reset pulse,
`STATUS[2]` is `dsm_valid`, `STATUS[3]` is `rf_valid`, `STATUS[4]` is
`s_axis_tready`, `STATUS[5]` is the sticky error summary, and `STATUS[6]` is
the internal AXI-Stream skid-buffer full flag.

AXI-Stream backpressure is a legal flow-control condition. When `s_axis_tvalid`
is high and `s_axis_tready` is low while the IP is enabled and out of reset,
the wrapper increments `INPUT_STALL_COUNT`; it does not set a sticky error.
`ERROR_STATUS[0]` is set only when AXI-Stream input is asserted while the IP is
disabled or held in reset. Writing `1` to an `ERROR_STATUS` bit clears that bit.

## DSM Mode Roadmap

Current RTL modes:

| DSM_MODE | Algorithm | Quantizer domain | Status |
|---:|---|---|---|
| 0 | LPDSM | 1-bit | RTL + MATLAB bit-true |
| 1 | LPDSM2 | 1-bit | RTL + MATLAB bit-true |
| 2 | EFDSM | 1-bit | RTL + MATLAB bit-true |
| 3 | EFDSM2 | 1-bit | RTL + MATLAB bit-true |
| 4 | MASH11 | native signed output | RTL + MATLAB bit-true |
| 5 | MASH111 | native signed output | RTL + MATLAB bit-true |
| 6 | MASH22 | native signed output | RTL + MATLAB bit-true |

Exploratory multibit modes:

| DSM_MODE | Algorithm | Quantizer domain | Status |
|---:|---|---|---|
| 7 | LPDSM | multibit Cartesian | MATLAB exploration + RTL smoke |
| 8 | LPDSM2 | multibit Cartesian | MATLAB exploration + RTL smoke |
| 9 | EFDSM | multibit Cartesian | MATLAB exploration + RTL smoke |
| 10 | EFDSM2 | multibit Cartesian | MATLAB exploration + RTL smoke |
| 11 | MASH11 | multibit Cartesian | MATLAB exploration + RTL smoke |
| 12 | MASH111 | multibit Cartesian | MATLAB exploration + RTL smoke |
| 13 | MASH22 | multibit Cartesian | MATLAB exploration + RTL smoke |

Multibit parameters:

| Parameter | Default | Description |
|---|---:|---|
| `DSM_OUT_W` | 8 | Native DSM output code width exposed by `i_yout/q_yout` |
| `MB_Q_BITS` | 4 | Compile-time multibit quantizer resolution |
| `ACC_W_MB` | 16 | Multibit DSM state width |

`MB_Q_BITS` is intentionally a compile-time parameter. Changing it changes the
quantizer level count, feedback scaling, output range, and downstream interface
requirements. Runtime bit-depth switching should be implemented later as an
explicit mux between separately verified quantizers if it is required.

Current multibit bit-true status:

| DSM_MODE | Algorithm | MATLAB/RTL bit-true |
|---:|---|---|
| 7 | LPDSM multibit | 65536 samples, 0 mismatch |
| 8 | LPDSM2 multibit | 65536 samples, 0 mismatch |
| 9 | EFDSM multibit | 65536 samples, 0 mismatch |
| 10 | EFDSM2 multibit | 65536 samples, 0 mismatch |
| 11 | MASH11 multibit | 65536 samples, 0 mismatch |
| 12 | MASH111 multibit | 65536 samples, 0 mismatch |
| 13 | MASH22 multibit | 65536 samples, 0 mismatch |

Current multibit OOC status on `xc7z020clg400-1`:

| DSM_MODE | Algorithm | OOC 100 MHz status |
|---:|---|---|
| 7 | LPDSM multibit | PASS |
| 8 | LPDSM2 multibit | PASS |
| 9 | EFDSM multibit | PASS |
| 10 | EFDSM2 multibit | FAIL_TIMING, WNS -0.093 ns |
| 11 | MASH11 multibit | PASS |
| 12 | MASH111 multibit | PASS |
| 13 | MASH22 multibit | FAIL_TIMING, WNS -0.688 ns |

Current single-bit/native and multibit OOC status on `xczu15eg-ffvb1156-1-i`:

| Mode group | Count | OOC 100 MHz status | Worst WNS |
|---|---:|---|---:|
| Single-bit/native DSM | 7 | PASS | 5.107 ns |
| Multibit Cartesian DSM | 7 | PASS | 4.896 ns |

The multibit RTL does not yet replace the seven verified single-bit/native MASH
modes.

## Interpolation Frontend

Standalone interpolation/filter frontend RTL is provided under:

```text
rtl/axis/axis_skid_buffer.sv
rtl/interp/dsm_interp_fir_fixed.sv
rtl/interp/dsm_interp2_halfband.sv
rtl/interp/dsm_interp_frontend.sv
```

Current RTL-supported interpolation modes:

| INTERP_MODE | Function | RTL/MATLAB bit-true |
|---:|---|---|
| 0 | bypass | 128 samples, 0 mismatch |
| 1 | x4 halfband FIR cascade | 512 samples, 0 mismatch |
| 2 | x8 halfband FIR cascade | 1024 samples, 0 mismatch |
| 3 | x16 halfband FIR cascade | 2048 samples, 0 mismatch |
| 4 | x32 CIC + compensation FIR | 4096 samples, 0 mismatch |

The frontend uses Q1.15 I/Q samples and a single-clock valid/ready interface.
It is inserted before `dsm_ip_core` in `dsm_ip_top` and is exposed as a
compile-time `INTERP_MODE` parameter through the top-level RTL. AXI-Stream
`s_axis_tready` is driven through a one-entry skid buffer and follows the
frontend `in_ready` signal without dropping samples during legal backpressure.
The FIR implementation uses symmetric-coefficient pre-adds and skips zero
coefficients to reduce arithmetic cost while preserving the current
MATLAB/RTL bit-true vectors. Runtime interpolation mode switching is not
implemented.

## Frequency and Bandwidth Configuration

The IP separates three related but different quantities:

- Output sample rate: the `clk` rate. Default release setting is 100 MHz.
- Upconversion frequency: generated by the DUC. In NCO mode:
  `cfg_phase_inc = round(f_if / f_clk * 2^PHASE_W)`.
- Signal bandwidth: set by the incoming baseband stream and its sample rate.
  The interpolation frontend supports bypass, x4, x8, x16, and x32 modes in
  RTL. The selected mode is compile-time configurable through `INTERP_MODE`.

## Timing Target

- Proxy target: `xc7z020clg400-1`
- Clock: 100 MHz
- Default Fs/4 output center: 25 MHz
- Pass criterion: routed `WNS >= 0`

## QAM-OFDM Profile

- Modulation: 16-QAM
- `Nfft`: 64
- `Ncp`: 16
- `Nsym`: 500
- Active subcarriers: `[-26:-1, 1:26]`
- `OSR`: 32
- `Fs_dsm`: 100 MHz
- `Fs_bb`: 3.125 MHz
- Subcarrier spacing: 48.828125 kHz
- ROM/input width: Q1.15

## Included Tops

- `p0_top_lp1`
- `p0_top_lp2`
- `p0_top_ef1`
- `p0_top_ef2`
- `p0_top_mash11_mb`
- `p0_top_mash111_mb`
- `p0_top_mash22_mb`
- `dsm_ip_core`
- `dsm_ip_top`
- `dsm_ip_axi_top`

## Timing Evidence Boundary

The current Zynq-7020 proxy OOC evidence from 2026-07-03 shows all seven
retained paths meeting the 100 MHz target. LPDSM2 uses the P0 timing-closure
configuration with a 20-bit accumulator.

The current ZU48DR proxy OOC evidence shows all seven retained paths meeting
the 100 MHz target.

The current multibit OOC evidence from 2026-07-05 shows five of seven multibit
modes meeting the 100 MHz target on `xc7z020clg400-1`. EFDSM2 multibit and
MASH22 multibit require additional timing closure before they can be claimed as
100 MHz closed on this target.

The current ZU15EG OOC evidence from 2026-07-05 uses
`xczu15eg-ffvb1156-1-i` and shows all 14 single-bit/native and multibit DSM
tops meeting the 100 MHz target. This is OOC module evidence only; it is not a
board-level implementation, bitstream, or ILA validation result.
