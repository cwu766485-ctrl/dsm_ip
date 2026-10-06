# Formal Verification

## Thermo5 scoped coverage proofs

```bash
python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py --out-dir runs/thermo5_formal_review
```

`thermo5_gap_harness.sv` instantiates production reset and DPD RTL. The reset
model allows runtime reassertion but changes reset only on the falling edge;
the exact active-edge collision cover is uncoverable within that model. The
counter model independently counts acceptances and bounds them to 2072 per
reset epoch. It proves counter equality/bounds and zero bits31:12, with
accept/stall/recovery covers. The runner gates setup, assertions, expected
cover outcomes, vacuity and **zero black boxes**, recording commands, source
hashes and tool banners. These proofs do not replace full-chain URG hits or
prove unrestricted asynchronous timing and unlimited counter operation.

This directory contains the VC Formal FPV flow for the frozen DSM IP
Performance SKU control and protocol boundary.

## Scope

The harness elaborates the real `dsm_ip_axi_top` with:

- BP EFDSM2 and the Fs/4 IF path;
- interpolation bypass, because interpolation arithmetic is signed off by
  MATLAB/Python/RTL bit-true simulation;
- polynomial DPD enabled at order 5;
- memory-polynomial DPD enabled with four taps;
- LUT DPD disabled.

The proof checks AXI response stability, RF bit encoding, software-reset drain,
serialized coefficient-bank commit, bank/acknowledge/epoch causality, failed
commit retention, and observer ready-state legality. Source-side AXI payload
stability is modeled as an environment assumption.

## Signed-Off Result

The VC Formal V-2023.12-SP2 run on 2026-08-15 produced:

```text
Assertions: 14 found, 14 proven
Vacuity:    18 found, 18 non-vacuous
Covers:      7 found,  7 covered
Black boxes: 0
```

The selected setup audit reports zero clock, glitch, oscillating-loop,
combinational-loop, and multi-driver violations. The generic reset setup check
is deliberately excluded: `core_rst_n = aresetn & ~soft_reset` is a runtime
software reset, not an initialization-only reset. Its assertion, drain, commit
cancellation, and reachability behavior remains in the formal state space and
is checked by dedicated SVA. Constraining `soft_reset` inactive would make the
proof weaker and is not used.

The proof found and drove fixes for two real wrapper defects:

- a sticky rejection from an older memory-DPD commit could reject a new commit
  before the new pulse reached the DPD frontend;
- software reset coincident with commit completion could incorrectly increment
  the commit epoch and leave stale wrapper transaction state.

Hardware completion now wins over a same-cycle W1C status clear. Linux VCS
memory-DPD bit-true and safety tests pass after these fixes.

Generated reports are under `dv/uvm/formal/out/dsm_ip_fpv/` and are ignored
by Git. The sign-off source files are:

- `dsm_ip_formal_harness.sv`
- `dsm_axi_protocol_sva.sv`
- `dsm_formal_filelist.f`
- `run_dsm_ip_fpv.tcl`
- `run_dsm_ip_fpv_linux.sh`
- `run_dsm_ip_fpv_wsl.ps1`

## Commands

Probe the installed tools and license:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\uvm\formal\run_formal_tool_check_wsl.ps1
```

Run the proof directly through Rocky WSL:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\uvm\formal\run_dsm_ip_fpv_wsl.ps1
```

The runner fails if the selected setup audit has a nonzero violation count, a
report is missing, or an assertion is falsified, inconclusive, undetermined, or
unprocessed.

The shared bridge entry remains available for machines where only the bridge
daemon owns the Linux EDA session. A stale `status.txt` or `result.log` is not
new evidence. The direct WSL runner is preferred on this workstation because
the Synopsys PATH is loaded by the interactive shell.

## Boundary

Thermo5 gap runner also supports `--unbounded-counter`: production 32-bit
counter, external-tap identity configuration, no acceptance budget, 35
assertions (including each bit/carry relationship), four covers, zero-black-box
and vacuity gates. Run in a new `runs/` directory. Latest passing evidence
and coverage boundaries are in
`docs/verification/thermo5-coverage100-assessment.md`.
Optional `--identity-and-residual` adds expensive arithmetic/gearbox
experiments; arithmetic remains inconclusive. The completed residual repeat
at `runs/thermo5_coverage100_residual_exact_20261006/` passes four assertions
and nine covers after constructing a registered legal source and setting
exact 7:4 clock periods; source stability is non-vacuous and black boxes zero.
`--residual-only` adds this job without arithmetic; `--jobs cdc_residual`
runs only that job. Original reset/budget defaults remain. Proofs do not
become URG hits, and no exclusions are applied.

This FPV result is not a CDC/RDC report, formal arithmetic equivalence proof,
gate-level/SDF sign-off, physical implementation sign-off, or proof of every
compile-time DSM/DPD/interpolation SKU. `dsm_async_fifo_order_checker` remains a
simulation-only data-order checker for the asynchronous feedback subsystem.
Formality is an equivalence-checking product and does not replace VC Formal FPV.
