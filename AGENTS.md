# AGENTS.md

## Project

This repository is a reusable DSM digital IP handoff package for digital IC design and verification.

Main flows:

- MATLAB fixed-point and bit-true reference modeling
- Synthesizable Verilog/SystemVerilog RTL
- SystemVerilog XSim verification
- Vivado IP packaging
- OOC synthesis, timing, and resource analysis
- FPGA/RFSoC board-validation support

## Key Paths

- `rtl/`: synthesizable RTL and IP wrappers
- `matlab/`: fixed-point models, vector generation, and analysis scripts
- `dv/verif/`: simulation testbenches, vectors, and regression scripts
- `ip/`: Vivado IP packaging flow
- `syn/`: OOC synthesis scripts and reports
- `fpga/`: board integration notes and local validation support
- `docs/`: specifications, status, plans, and handoff notes

Read the relevant source files before making changes. Do not infer behavior from file names only.

## Core Rules

- Keep all public project files in English.
- Do not commit passwords, tokens, licenses, server addresses, private account data, or restricted vendor/board collateral.
- Preserve MATLAB/RTL bit-true behavior unless a behavior change is explicitly requested.
- Do not change fixed-point width, signedness, scaling, rounding, truncation, saturation, reset state, update order, vector format, or latency silently.
- Keep RTL synthesizable and interfaces stable.
- Keep changes small, localized, and reviewable.
- Place UVM work under `dv/uvm/`.
- Do not add generated logs, waveform dumps, tool caches, or large temporary artifacts.

## Source Priority

When information conflicts, follow this order:

1. Latest user instruction
2. This file
3. Regression scripts and filelists
4. MATLAB bit-true reference
5. RTL implementation
6. Project documentation
7. Code comments

## Required Checks

After RTL changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
```

After MATLAB or algorithm changes:

```powershell
.\scripts\run_matlab_p0_bittrue_check.cmd
```

After IP wrapper or packaging changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1
```

After synthesis, timing, or resource changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1
```

If a required tool is unavailable, report it clearly. Never claim a check passed unless it was run.

## Documentation

When tracked project behavior, structure, verification evidence, or limitations change, update the relevant docs and `docs/UPDATE_LOG.md`.

Record:

- date and time
- changed files
- reason for change
- checks run
- remaining limitations

## Work Flow

For every task:

1. Read `docs/exec-plans/active/execution-frontier.md` and the relevant files.
2. Identify the source of truth.
3. Make the smallest safe change.
4. Run the required checks.
5. Update docs if needed.
6. Report the result with exact checks and remaining risks.

## Execution Frontier

`docs/exec-plans/active/execution-frontier.md` is the concise source of truth
for active execution state. Read it before work. Update it when a failure is
reproduced, a root cause is confirmed, an implementation or verification
milestone materially changes, work is paused/handed off, or the next action
changes. Move completed module plans to `docs/exec-plans/inactive/`; do not
use the frontier as a chat transcript.


## Navigation and current status

Read `docs/ai-native/repository-map.md`, `docs/ai-native/design-verification-index.md`, `docs/ai-native/commands.md`, and `docs/exec-plans/active/execution-frontier.md` before work.

- ASIC manifest: `eda.yaml`; DC top: `tid32_thermo3_axis_frontend_tx_asic_dc`.
- FPGA thermo3/thermo5 routed OOC evidence is signed off at 218.75 MHz.
- TSMC28 DC thermo3/thermo5 runs are unfinished; do not claim ASIC PASS until mapped reports and netlists exist.
- `rtl/` is canonical RTL; `dv/verif/` is directed DV; `dv/uvm/` is Linux UVM/formal. Both verification trees were physically migrated and consumers updated; see the migration map.
- `syn/asic/` is the ASIC DC flow; `fpga/` is the vendor/device boundary; `matlab/` is the algorithm source of truth.

Before changes: run `git status`, preserve generated/vendor/PDK content, and update the frontier after each non-trivial flow. Required smoke commands are listed in `docs/ai-native/commands.md`. Never treat unavailable tools or intermediate reports as PASS.

## Migration status

- Physical migration map: `docs/exec-plans/active/physical-migration-map.json`.
- `verif/` and `uvm_verif/` were physically migrated to `dv/verif/` and `dv/uvm/`; no ordinary legacy verification tree remains at the old paths.
- Canonical target skeleton now includes `docs/spec/`, `docs/architecture/`, `docs/verification/`, `docs/exec-plans/{active,completed}/`, `tools/hw/`, `config/`, and `runs/`.
<!-- organize-chip-project:generated-end -->
