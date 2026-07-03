# AGENTS.md

## Project

This is a DSM digital IP project for digital IC design and verification.

Maintain it as a reusable RTL/IP handoff package, not a one-off experiment.

Main flows:

- MATLAB fixed-point / bit-true reference model
- Synthesizable Verilog RTL DSM IP
- SystemVerilog XSim verification
- Vivado IP packaging
- OOC synthesis, timing, and resource analysis
- FPGA / RFSoC board validation support

## Language

- Use Chinese for documentation, update logs, review comments, task summaries, and final reports unless the user explicitly requests otherwise.
- Keep code identifiers, signal names, module names, file names, commands, and EDA/tool terms in English.

## Key Paths

Read relevant docs before editing.

- `rtl/`: synthesizable RTL
- `matlab/`: algorithm, fixed-point, bit-true model, vector generation, analysis
- `verif/`: XSim testbench, tests, vectors, regression scripts
- `scripts/`: top-level MATLAB/CMD utility scripts
- `ip/`: Vivado IP packaging flow
- `syn/`: OOC synthesis, timing, resources, constraints
- `fpga/`: board validation and RFSoC-related work
- `data/`: validation data
- `docs/`: project documentation and update logs

Important files:

- `rtl/filelist_p0.f`
- `ip/filelist_dsm_ip.f`
- `matlab/path_setup.m`
- `verif/RUN_REGRESSION.md`
- `syn/RUN_OOC.md`
- `docs/IP_SPEC.md`
- `docs/VERIFICATION_PLAN.md`
- `docs/project_map.md`
- `docs/update_log.md`

## Source Priority

When information conflicts, follow this order:

1. User's latest explicit instruction
2. This `AGENTS.md`
3. Existing regression scripts and filelists
4. MATLAB bit-true reference
5. RTL implementation
6. Existing docs
7. Code comments

Do not guess from file names only. Read the relevant files first.

## Core Rules

- Preserve MATLAB/RTL bit-true behavior.
- Do not silently change fixed-point width, signedness, scaling, rounding, truncation, saturation, reset value, state update order, vector format, or latency.
- Do not modify golden vectors, expected outputs, or regression criteria just to make tests pass.
- Do not change public RTL/IP interfaces unless explicitly requested.
- Keep RTL synthesizable.
- Keep changes small, localized, and reviewable.
- Future UVM work must go under `verif/uvm/`.
- Do not delete existing tests, scripts, vectors, or docs unless explicitly requested.
- Do not commit secrets, passwords, tokens, licenses, server addresses, or private account data.
- Do not add generated logs, waveform dumps, caches, or large artifacts unless intentionally tracked.
- AGENTS.md should never be modified except to add new rules or clarify existing ones.

## Bit-True Contract

The MATLAB model is the algorithm and fixed-point reference.

RTL changes must preserve:

- input/output vector format
- signedness and Q format
- bit width
- rounding/truncation/saturation behavior
- DSM state update order
- reset initialization
- pipeline latency
- MATLAB/RTL comparison alignment

If numerical behavior or latency changes, update all affected MATLAB, RTL, testbench, vector, script, docs, and `docs/update_log.md` files together.

## Required Checks

After RTL changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
```

After MATLAB/algorithm changes:

```powershell
.\scripts\run_matlab_p0_bittrue_check.cmd
```

After IP wrapper or packaging changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1
```

After synthesis/timing/resource changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1
```

If a required tool is unavailable, report it as `未运行` and explain why. Never fake pass results.

## Update Log

When tracked project files change, update:

```text
docs/update_log.md
```

Use system time and include:

- 修改时间
- 修改文件
- 修改内容
- 修改原因
- 运行检查
- 通过/失败/未运行状态
- 剩余限制或风险

## Workflow

For every task:

1. Read relevant code, filelists, scripts, and docs.
2. Identify the source of truth.
3. Make the smallest safe change.
4. Run required checks.
5. Update docs and `docs/update_log.md` if needed.
6. Report clearly in Chinese.

## Final Report Format

```markdown
## 修改内容

- ...

## 检查结果

- ...

## 未运行/受限项

- ...

## 风险与后续建议

- ...
```

## Code Review Checklist

When reviewing code or project quality, check:

- MATLAB/RTL bit-true consistency
- fixed-point width/sign/scaling
- reset behavior
- pipeline latency
- vector format compatibility
- testbench/checker correctness
- regression script coverage
- synthesizability
- filelist completeness
- IP packaging impact
- timing/resource impact
- documentation consistency
- Windows PowerShell/CMD portability

If `code_review.md` exists, read it and follow it.