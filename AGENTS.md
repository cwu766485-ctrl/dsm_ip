# AGENTS.md

## Project purpose

This branch is the thermo5-focused digital transmitter IP handoff package. The
full multi-SKU repository remains on `main`.

Main flows:

- MATLAB fixed-point and bit-true reference modeling
- Synthesizable Verilog/SystemVerilog RTL
- SystemVerilog XSim verification
- Thermo5 ZU15EG OOC synthesis and timing analysis
- OOC synthesis, timing, and resource analysis
- FPGA/RFSoC board-validation support

## Key Paths

- `rtl/`: synthesizable RTL and IP wrappers
- `matlab/`: fixed-point models, vector generation, and analysis scripts
- `dv/verif/`: simulation testbenches, vectors, and regression scripts
- `syn/`: OOC synthesis scripts and reports
- `fpga/`: board integration notes and local validation support
- `tools/hw/`: thermo5 coverage, report, and closure utilities
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
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_thermo5_i2_d1_axis.ps1 -VectorDir .\runs\uvm_thermo5_i2_d1\vectors
wsl -d Rocky-8.10 -- bash -ilc 'export VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1; make -C dv/uvm/sim thermo5-vcs-regression THERMO5_OUT=/mnt/e/workspace/chip/dsm_ip/runs/thermo5_verify_<unique>'
```

After MATLAB or algorithm changes, regenerate the thermo5 oracle vectors and
rerun the directed XSim/UVM bit-true tests above.

After synthesis, timing, or resource changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_thermo5_axil_control.ps1
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

This branch is the thermo5-focused code view. The full multi-SKU source tree is
preserved on `main`; this branch retains shared dependencies required by the
thermo5 DUT and verification flows.

Read `docs/ai-native/repository-map.md`, `docs/ai-native/design-verification-index.md`, `docs/ai-native/commands.md`, and `docs/exec-plans/active/execution-frontier.md` before work.

- Thermo5 DUT top: `tid32_thermo5_axis_frontend_tx`; optional AXI-Lite wrapper: `tid32_thermo5_axi_lite_axis_frontend_tx`.
- Thermo5 verification source of truth: `dv/uvm/sim/thermo5_sku_filelist.f`; directed XSim tests are under `dv/verif/`.
- ZU15EG thermo5 AXI-Lite OOC routed evidence is positive at 218.75 MHz under the modeled OOC constraints. Parent I/O budgets, system CDC/RDC, and physical board output remain outside that signoff.
- The `eda.yaml` and DC top for thermo3 are intentionally absent here; use the full `main` branch or the dedicated `thermo3` branch for that design.
- `rtl/` is canonical RTL; `dv/verif/` is directed DV; `dv/uvm/` is thermo5 Linux UVM/formal; `syn/` and `fpga/` retain thermo5 integration flows; `matlab/` retains thermo5 reference models.

Before changes: run `git status`, preserve generated/vendor/PDK content, and update the frontier after each non-trivial flow. Required smoke commands are listed in `docs/ai-native/commands.md`. Never treat unavailable tools or intermediate reports as PASS.

## Migration status

- Physical migration map: `docs/exec-plans/active/physical-migration-map.json`.
- `verif/` and `uvm_verif/` were physically migrated to `dv/verif/` and `dv/uvm/`; no ordinary legacy verification tree remains at the old paths.
- Canonical target skeleton now includes `docs/spec/`, `docs/architecture/`, `docs/verification/`, `docs/exec-plans/{active,completed}/`, `tools/hw/`, `config/`, and `runs/`.
<!-- organize-chip-project:generated-end -->
