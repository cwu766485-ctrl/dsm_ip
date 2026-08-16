# DSM Digital Transmitter IP

Reusable digital transmitter IP with fixed-point MATLAB models, synthesizable
RTL, AXI interfaces, DPD, interpolation, delta-sigma modulation, verification,
Vivado packaging, FPGA implementation flows, and pre-layout ASIC evidence.

## Current Validation SKU

```text
target               = xczu15eg-ffvb1156-2-i
clock                = 100 MHz
top                  = dsm_ip_axi_top
ALGORITHM            = 3
DUC_MODE             = 3
INTERP_MODE          = 4
INTERP_IMPL          = 0
DPD                  = Memory-Poly5, 4 taps
ENABLE_DPD_MEMORY    = 1
ENABLE_DPD_POLY/LUT  = 0
```

The selected datapath is:

```text
AXI4-Stream Q1.15 complex I/Q
 -> 4-tap fifth-order memory-polynomial DPD
 -> x32 interpolation
 -> full-precision Fs/4 real-IF mixer
 -> one-bit band-pass EFDSM2
 -> rf_bit/rf_signed
```

The source defaults keep a broader development configuration. Product hardware
is selected with compile-time parameters during synthesis; AXI-Lite cannot
restore a branch removed by a generate condition.

## Implemented Capabilities

- Seven low-pass DSM families: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11,
  MASH111, and MASH22.
- Single-bit and parameterized multibit research implementations.
- Bypass, Poly3/5/7, LUT, and memory-polynomial DPD.
- x4/x8/x16 halfband and x32 CIC plus compensation-FIR interpolation.
- AXI4-Lite control/status and AXI4-Stream TX input.
- Backpressure, frame/sample/stall/error counters, and sticky errors.
- Coefficient shadow banks, safe commit, saturation detection, and fallback.
- Digital observer, monitor proxies, and an asynchronous feedback bridge.
- Bare-metal PS/DMA replay and bounded calibration-search framework.
- Directed XSim/MATLAB regressions, Linux VCS system-UVM regressions, Vivado IP
  packaging, ZU15EG OOC scripts, and 28 nm Design Compiler flows.

## Interfaces

TX input samples are packed as:

```text
s_axis_tdata[15:0]  = signed I, Q1.15
s_axis_tdata[31:16] = signed Q, Q1.15
```

AXI4-Stream transfers occur only on `tvalid && tready`. AXI4-Lite is the
low-rate control plane for reset, DPD configuration, coefficient/LUT writes,
observer controls, monitor readback, and status.

The main BP SKU uses `rf_valid`, `rf_bit`, and `rf_signed`. Cartesian
`i_bit/q_bit` outputs remain for compatible low-pass integration modes.

## Verification

```powershell
.\scripts\run_matlab_p0_bittrue_check.cmd
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
```

The Linux VCS environment under `uvm_verif/` has a frozen-SKU system regression
with Python integer reference scoreboarding. The 2026-08-16 run completed 20/20
testcases with zero UVM errors/fatals and explicit anti-false-pass gates. This
is a functional and functional-coverage closure for the frozen SKU; it is not
100% RTL code coverage, CDC/RDC, gate-level, or all-SKU signoff. See
`docs/VPLAN.md` for the full coverage and evidence boundary.

## Implementation Evidence

- ZU15EG DPD post-synthesis OOC evidence covers bypass, Poly3/5/7, LUT, and
  memory-polynomial 1/2/4/6-tap configurations.
- A historical ZU15EG full-TX routed/bitstream result exists for the older
  Cartesian EFDSM/Fs4 `DUC_MODE=0` path.
- The frozen BP EFDSM2 SKU has a ZU15EG routed OOC result at 100 MHz: setup
  `WNS=+2.632 ns`, `TNS=0`, and zero setup failing endpoints. It uses 12,964
  LUTs, 15,316 FFs, 266 DSP48s, and no BRAM/URAM. This is OOC evidence only;
  a board XDC-constrained bitstream, I/O hold closure, and board replay remain
  pending because the local board Vivado project is not in this repository.
- The same BP SKU has retained 28 nm pre-layout DC evidence. A current structural
  DC lint rerun is blocked by an unavailable Design Compiler license and must
  not be reported as passing.
- No physical PA/ADC feedback loop or measured RF signoff is claimed.

## Repository Map

| Path | Purpose |
|---|---|
| `rtl/` | Synthesizable datapath and wrappers |
| `matlab/` | Fixed-point references, vectors, DPD models, and metrics |
| `verif/` | Directed SystemVerilog/XSim tests |
| `uvm_verif/` | UVM verification scaffold |
| `ip/` | Vivado IP packaging |
| `syn/` | Vivado and Design Compiler flows |
| `fpga/zu15eg/` | ZU15EG integration and bare-metal support |
| `ads/` | Optional DPA circuit experiments |
| `docs/` | Specification, verification plan, status, and evidence |

Start with [the documentation index](docs/README.md) and
[current status](docs/UPDATE_LOG.md).

## Evidence Boundary

MATLAB behavioral, ADS, FPGA OOC, FPGA routed, ASIC pre-layout, and measured RF
results are separate evidence levels. Every performance claim must identify its
configuration and source. Restricted board collateral, PDK files, licenses,
credentials, generated logs, waveforms, and tool workspaces must not be
committed.
