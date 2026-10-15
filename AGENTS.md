# DSM Study Branch Instructions

## Purpose and scope

This branch is a focused study of scalar-sample low-pass DSM algorithms.
Canonical RTL is under `rtl/dsm/singlebit/` and `rtl/dsm/multibit/`. The P0
I/Q wrappers exist only to carry the scalar cores through deterministic
regression and OOC comparison. Do not add unrelated transmitter, DPD,
interpolation, AXI/FIFO, GT, or board-integration source here.

## Change rules

- Public project files are in English.
- Read the relevant MATLAB model, RTL, testbench, and current frontier before
  changing algorithm behavior.
- Preserve bit widths, signedness, scaling, rounding, saturation, reset,
  enable/update ordering, and latency unless the user explicitly requests a
  behavior change.
- Keep changes localized and synthesizable. Do not commit secrets, licenses,
  generated logs, waveforms, caches, or run outputs.
- Treat MATLAB as the source of truth for fixed-point model behavior. Do not
  claim RTL/model agreement without running the corresponding comparison.
- Do not delete user-local, untracked, or generated data. Keep run evidence in
  ignored `runs/dsm/` directories and commit only concise summaries where
  appropriate.

## Required checks

After RTL changes, run the applicable Windows regression(s):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_multibit.ps1
```

After MATLAB/model changes, run the matching MATLAB check, for example:

```text
scripts/run_matlab_p0_bittrue_check.cmd
```

After synthesis/timing changes, run the focused OOC flow:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1
```

If a tool is unavailable, report that explicitly. Never infer PASS from an
intermediate checkpoint or stale output.

## Documentation and navigation

Before work, read:

- `docs/ai-native/repository-map.md`
- `docs/ai-native/design-verification-index.md`
- `docs/ai-native/commands.md`
- `docs/exec-plans/active/execution-frontier.md`

When a result, limitation, or next action materially changes, update the
frontier and `docs/UPDATE_LOG.md`. Keep the frontier concise and move finished
plans out of the active folder.
