# Thermo5 Frozen SKU Regression Handoff

## Graduate-DV package entry

Use `dv/uvm/sim/run_thermo5_dv_package_wsl.ps1` on this Windows/Rocky
workstation, or `run_thermo5_dv_package.py` from a licensed login environment.
This wraps the frozen baseline below, matching-build coverage follow-ups,
zero-black-box scoped formal, and two historical bug negative controls.
`thermo5-dv-portfolio.md` lists prerequisites and the evidence tables.
The latest review directory is `runs/thermo5_dv_package_delivery_20261006/`.
It provides unified diagnostics, exact commands, source/vector/binary hashes,
seeds, tool banners, VDB paths and automatic coverage summary.

Date: 2026-10-06. Scope: reproducible Linux VCS/URG execution for the frozen
thermo5 two-tap interpolation, one-tap identity DPD subsystem.

## Launcher

From the repository root in the licensed Linux environment:

```bash
python3.12 dv/uvm/sim/run_thermo5_frozen_regression.py \
  --xpm-root /path/to/Vivado/2024.1
```

The launcher creates a new directory under `runs/` and writes `manifest.json`
and `summary.json`. Use `--out-dir runs/<new-name>` to choose a path; it must
not already contain files. The dry-run command writes the exact planned argv
and tool discovery result without starting VCS or URG:

```bash
python3.12 dv/uvm/sim/run_thermo5_frozen_regression.py --dry-run
```

The default payload vectors are the existing independent MATLAB payload sets
for seeds 101, 202, and 303 under
`runs/uvm_thermo5_payload_20261003/`. `--payload-root` selects a different
existing payload directory. I/Q samples, frame metadata, and all four
golden PA planes are SHA-256 recorded before use. The launcher also requires
the existing eight-file base-vector
set under `runs/uvm_thermo5_i2_d1/vectors` for compile and the seven-case
regression.

For each FIFO implementation it compiles once, runs the seven directed cases
(including the expected illegal-frame assertion), checks completion markers,
zero UVM errors/fatals, coverage summaries and VDB presence, runs all three
payload seeds against their independent four-plane vectors, then performs a
separate URG merge. Generic and XPM databases and reports are never merged
together. The machine-readable manifest records git commit and dirty state,
an RTL/DV source digest, tool discovery/version probes, configuration, vector
hashes, exact command arguments, exit codes, log and VDB paths, test markers,
scoreboard contract counts, functional coverage counters, and merge artifacts.
License environment values are not recorded.

## Evidence and limits

`scoreboard_contract` records the per-test accepted input and four-plane word
counts: full-stream cases check 32/56, FIFO starvation checks four accepted
beats and seven words before the expected sticky underflow, and reset cases
discard partial 24-beat epochs before checking a 32/56 replay. The UVM PASS
markers are emitted after each test's scoreboard wait/count and drain checks.
Reset tests intentionally accumulate partial-frame and replay words in event
coverage, so the event counter is not equated with the final-epoch scoreboard
count. The illegal-frame negative case expects zero PA output and is exempt
from normal queue-drain criteria.

The launcher captures source/core functional covergroup percentages and
per-test event counts from `[SKU_COVERAGE]`. It also extracts score, line,
condition, toggle, FSM, branch, and assertion values for the DUT row in each
separate URG hierarchy report. The XPM DUT hierarchy includes vendor cells,
so its overall coverage percentage is not comparable to generic. Remaining
instance-level coverage dispositions still require review in the existing
coverage audit; the summary does not close any bins.

The launcher checks the visible expected assertion text and negative-test
marker, but simulator-version-specific assertion behavior still needs review
if the diagnostic format changes. A missing log, VDB, summary, marker,
nonzero command status, UVM error/fatal, or URG load error fails the run.

## Local execution result

The Windows-hosted default WSL shell used Python 3.6 and had no licensed
tools, so its dry-run and preflight results were not verification passes.
The audited Rocky-8.10 bridge supplied Python 3.12, VCS V-2023.12-SP1,
URG, and mounted Vivado 2024.1 XPM simulation sources. The first full
licensed run completed with status `PASS` at
`runs/thermo5_frozen_regression_20261006_rocky/manifest.json`: 14
seven-case results, six independent-payload results, two separate URG
merges, and zero launcher errors. Its merged DUT hierarchy scores were
87.00% generic and 79.96% XPM. These differ in hierarchy and are not
comparable. The repeat after fail-fast scoreboard hardening also completed
with `PASS`, 14 seven-case results, six payload results, two URG merges, and
zero launcher errors at
`runs/thermo5_frozen_regression_hardened_20261006/manifest.json`.
Use this newer manifest for handoff. Its per-implementation `audit/` CSVs
are summarized in `thermo5-uvm-coverage.md`; reachable condition, reset,
toggle, branch, and vendor gaps remain OPEN.
