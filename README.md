# thermo5 Digital Transmitter IP

This branch contains the thermo5 digital transmitter RTL, its verification
environment, and the scripts/evidence needed to reproduce its digital checks.
The full multi-SKU repository remains on `main`; this branch intentionally
excludes unrelated transmitter architectures and board applications.

## Frozen verification target

- Device target for FPGA OOC: `xczu15eg-ffvb1156-2-i`.
- AXI-Stream source clock: 125 MHz; core clock: 218.75 MHz.
- Input: 14 complex samples per AXI beat, packed into signed 16-bit I/Q lanes.
- Gearbox: 14:8 asynchronous FIFO/gearbox, preserving sample order and frame
  alignment while crossing into the core clock domain.
- Datapath: frame gain -> two x2 polyphase interpolation stages -> configurable
  memory-polynomial DPD wrapper (frozen regression SKU uses identity DPD) ->
  32-lane Cartesian TIDSM -> four synchronous 64-bit PA-code planes.
- Frozen SKU: `INTERP_TAPS=2`, `DPD_MAX_TAPS=1`, identity coefficient, XPM FIFO
  for the prospective GT parent; generic and XPM FIFO are both verified.

## Verification entry points

Generate the 56-word independent MATLAB reference vectors:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\uvm\sim\generate_thermo5_sku_vectors.ps1 `
  -OutDir .\runs\uvm_thermo5_i2_d1\vectors -Words 56
```

Run the directed XSim full-chain bit-true test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_thermo5_i2_d1_axis.ps1 `
  -VectorDir .\runs\uvm_thermo5_i2_d1\vectors
```

The VCS/UVM regression, AXI-Lite configuration tests, coverage merge, and
scoped formal scripts are under `dv/uvm/sim/` and `dv/uvm/formal/`. For XPM
simulation, set `THERMO5_XPM_ROOT` to the local Vivado installation. Licensed
tool installations and generated vectors/logs are intentionally not committed.

For Rocky WSL with the licensed VCS installation, run the frozen regression
from an interactive login shell so its license environment is loaded:

```powershell
wsl -d Rocky-8.10 -- bash -ilc 'export VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1; make -C dv/uvm/sim thermo5-vcs-regression THERMO5_OUT=/mnt/e/workspace/chip/dsm_ip/runs/thermo5_verify_<unique>'
```

Add `THERMO5_FIFO_IMPL=xpm THERMO5_XPM_ROOT=/mnt/d/Xilinx/Vivado/2024.1` for
the XPM implementation. Choose a new output directory for each run.

## Timing evidence boundary

The latest thermo5 AXI-Lite OOC route on ZU15EG reported
WNS/TNS/WHS/THS = `+0.198/0.000/+0.018/0.000 ns` at 218.75 MHz under the
modeled OOC constraints. This is not parent-level I/O, board, GT CDC/RDC, or
measured RF-output signoff. See `docs/exec-plans/active/execution-frontier.md`
and `docs/UPDATE_LOG.md` for the exact reports and remaining limitations.
