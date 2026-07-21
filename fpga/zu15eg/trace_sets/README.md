# Multi-Scenario DPD Trace Sets

This directory defines the provenance required before a calibration trace can
be used to train or evaluate the trace-aware DPD policy. Raw traces remain in
`fpga/zu15eg/out/` and are intentionally ignored because they are local board
artifacts. Retain a manifest and the associated run logs in the project
evidence archive approved for the board data.

## Manifest

Copy `manifest_template.csv` to a local working manifest, replacing all
placeholder values. One row is one completed full-calibration run. Repeated
runs of the same operating condition use the same `scenario_id`; this makes
the leave-one-scenario-out split remove every replicate of that condition.

Required fields:

| Field | Meaning |
|---|---|
| `scenario_id` | Stable ID for the PA/QAM/bandwidth/backoff condition |
| `pa_profile` | Controlled PA or emulator profile name |
| `pa_strength_db` | Numeric PA-drive/strength setting observable by the policy |
| `qam` | QAM order |
| `bandwidth_mhz` | Occupied bandwidth in MHz |
| `used_subcarriers` | Active OFDM subcarriers |
| `input_backoff` | Normalized input backoff used to create the transmitted vector |
| `waveform_id` | Immutable vector generator/configuration identifier |
| `calibration_profile` | Cost weights and search-limit profile |
| `trace_csv` | Path to the JTAG-exported full-calibration CSV, relative to the manifest |

Do not relabel a trace produced by the built-in synthetic `fill_iq_vector()` as
QAM/PA data. The current board application uses that internal smoke vector, so
it proves control-path repeatability only. A valid RF scenario needs the
actual generated waveform plus a PA/feedback observation configuration.

## Capture Matrix

Collect at least two values for every requested dimension: PA strength,
modulation, occupied bandwidth, and input backoff. For each condition, run a
full calibration (not `CAL_TRACE_POLICY_ONLY`), preserve its ELF build inputs,
then export the JTAG trace. Capture one or more repeated runs per
`scenario_id` before moving to policy replay.

The capture helper can append a manifest row directly when complete metadata
is supplied. See `fpga/zu15eg/README.md` for the command.

## Simulation Feedback Threshold Calibration

The existing PL monitor costs are not RF measurements. This project currently
calibrates the gate against the MATLAB memory-PA and observation-receiver
simulation. Do not relabel a PL trace as a PA-strength or feedback result.
For each simulated policy run used to calibrate a gate, retain all of the
following:

- one generated policy report CSV with its predicted cost, scenario distance,
  and dispersion;
- the simulation feedback CSV containing RF-recovered EVM, ACLR, pass/fail,
  PA profile/strength, random seed, and observation-model configuration.

The calibrator requires at least two PA strength values and at least two runs
per scenario. A run with no failed simulation result can only produce a
provisional output; it cannot demonstrate that a threshold rejects unsafe
modelled conditions.

```powershell
call .\scripts\run_matlab_dpd_policy_threshold_simulation.cmd

python .\fpga\zu15eg\scripts\calibrate_dpd_policy_thresholds.py `
  --simulation-feedback-csv .\matlab\out\dpd\dpd_policy_threshold_simulation.csv `
  --min-repeats 2 `
  --prefix dpd_policy_rf_thresholds_<date>
```

The JSON output contains suggested distance, relative-dispersion, and runtime
residual limits in ppm. Review the retained accepted/rejected simulated
measurements, then pass those values explicitly to `train_dpd_trace_policy.py`.
The tool does not rewrite a policy header and never labels any output RF safety
certified.

The expanded `run_dpd_pa_robustness_sweep` study is a stronger negative test:
it varies PA gain, saturation, memory length, observation noise, and drift.
If the calibration output is `simulation_gate_not_separable`, do not deploy
its thresholds. That means the current three gate features overlap safe and
unsafe modeled conditions; add observable monitor features to the predictor.

## Behavioral Gate Replay Against Retained Board Traces

After a behavioral monitor-gate study completes, replay its candidate
threshold against retained JTAG full-calibration traces before considering any
board-policy change:

```powershell
python .\fpga\zu15eg\scripts\replay_sim_monitor_gate.py `
  --manifest-csv .\fpga\zu15eg\out\trace_matrix\manifest_waveform_only_clean.csv `
  --simulation-gate-csv .\matlab\out\dpd\dpd_pa_monitor_gate_loso.csv `
  --threshold-strategy min `
  --out-csv .\fpga\zu15eg\out\trace_matrix\dpd_sim_monitor_gate_board_replay_min.csv
```

Use `min`, `median`, and `max` only to study threshold sensitivity. This is an
offline compatibility replay: the behavioral PA and retained-board monitor
distributions are separate evidence domains. The script always writes
`header_update_allowed=0`; it does not generate or modify `dpd_trace_policy.h`.

## Behavioral Regret-Policy Replay

The regret policy estimates whether the first polynomial candidate is worth
refining with the existing one-round local search. It uses C-friendly Q20
monitor ratios, median/IQR normalization, and five-neighbor weighted regret
prediction. Replay it against each held board trace before considering any
implementation of its constants:

```powershell
python .\fpga\zu15eg\scripts\replay_sim_regret_policy.py `
  --manifest-csv .\fpga\zu15eg\out\trace_matrix\manifest_waveform_only_clean.csv `
  --simulation-csv .\matlab\out\dpd\dpd_pa_robustness_simulation.csv `
  --regret-budget 100 `
  --feature-distance-ppm 100000 `
  --neighbors 5 `
  --out-csv .\fpga\zu15eg\out\trace_matrix\dpd_sim_regret_policy_board_replay.csv
```

`direct_cost_validated=1` means the selected one-candidate cost can be
compared with the retained full-search final cost. A `local_search` decision
does not prove a 14-candidate board result from a 49-candidate trace; it is
marked `board_replay_required=1` until a new policy-only board run captures
that branch. The tool always writes `header_update_allowed=0`.

The retained eight nominal waveform conditions have now been measured with
the forced bounded branch. Use `run_policy_local_search_matrix.ps1` to repeat
the test; it builds each waveform with `CAL_TRACE_POLICY_ONLY=1` and
`CAL_FORCE_POLICY_LOCAL_SEARCH=1`, captures its JTAG trace, and rejects any
run that does not contain exactly one policy record, 12 search records, and
one final record. It uses the existing static trace policy only as a seed and
does not generate or deploy regret-predictor constants.

## DSM-Aware Dataset

Build a provenance-preserving host data set after both the retained
full-calibration traces and the measured policy/local-search traces exist:

```powershell
python .\fpga\zu15eg\scripts\build_dsm_aware_dpd_dataset.py `
  --manifest-csv .\fpga\zu15eg\out\trace_matrix\manifest_waveform_only_clean.csv `
  --local-search-summary-csv .\fpga\zu15eg\out\policy_local_search_matrix\policy_local_search_matrix_summary.csv
```

The tool rejects incomplete or unsafe local-search traces and writes ignored
local artifacts under `fpga/zu15eg/out/dsm_aware_dataset/`. Each row records
waveform and PA provenance, DSM build provenance, first-policy DPD package and
PL monitors, plus the one-candidate, 14-candidate, and retained 49-candidate
cost labels. `search_benefit` is strictly the PL-proxy-cost reduction from the
measured policy candidate to the measured bounded local search; it is not RF
EVM or ACLR improvement.

The present board matrix has one DSM build only: `ALGORITHM=2` (EFDSM 1-bit),
`INTERP_MODE=0`, and OSR 32. Its DSM fields are intentionally reported as
constants, so it cannot answer whether joint DSM-plus-DPD selection beats
DPD-only selection. Before fitting any DSM-aware predictor, collect matched
waveform/PA rows for at least one additional DSM build, while preserving the
same policy/local/full labels. Do not generate board policy constants from the
current eight-row exploratory data set.

## EFDSM2 Matched Matrix

The first controlled second build is `ALGORITHM=3` (EFDSM2 1-bit), with
`INTERP_MODE=0`, OSR 32, and the existing fixed Fs/4 DUC. This changes only
DSM loop order relative to the original EFDSM 1-bit board build. Run its
matched full-calibration and bounded-policy matrices with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_dsm_ef2_matrix.ps1
```

The wrapper packages the IP, rebuilds the local board image with
`ALGORITHM=3`, exports the XSA, captures the eight full-calibration traces,
then measures an eight-row 14-candidate local-search matrix. Each bounded
measurement uses a LOSO policy fitted only from the other seven same-DSM full
traces. Results are stored below the ignored
`fpga/zu15eg/out/dsm_ef2_1bit_osr32_interp0/` directory.

The first matched EFDSM2 board matrix is complete: eight 49-candidate
full-calibration traces and eight 14-record bounded-search traces. Every
bounded trace has one policy, 12 search, and one final row with zero
stall/error/clip/saturation. The bounded branch uses a LOSO-generated
polynomial-only seed so its 12 perturbations remain meaningful; LUT packages
continue to be evaluated by the retained full-calibration label.

After it completes, construct a two-DSM data set by pairing the original
legacy manifest with its explicit default arguments and the new EFDSM2
manifest:

```powershell
python .\fpga\zu15eg\scripts\build_dsm_aware_dpd_dataset.py `
  --manifest-csv .\fpga\zu15eg\out\trace_matrix\manifest_waveform_only_clean.csv `
  --local-search-summary-csv .\fpga\zu15eg\out\policy_local_search_matrix\policy_local_search_matrix_summary.csv `
  --manifest-csv .\fpga\zu15eg\out\dsm_ef2_1bit_osr32_interp0\manifest_ef2_1bit_osr32_interp0.csv `
  --local-search-summary-csv .\fpga\zu15eg\out\dsm_ef2_1bit_osr32_interp0\policy_local_search\policy_local_search_matrix_summary.csv
```

This prepares matched evidence for analysis. It still does not establish
external RF performance, and no C policy constants should be generated from
the two-configuration data set without held-condition validation.

## Repeat And Joint LOSO

Normalize the existing first captures, then use the resulting manifests as the
only inputs for repeat collection. The collector resumes after interruption and
does not duplicate a full/local pair already registered by full-trace path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_trace_matrix.ps1 `
  -ManifestCsv .\fpga\zu15eg\out\dsm_repeat_matrix\efdsm_1bit_osr32_interp0\manifest.csv `
  -DsmConfigId efdsm_1bit_osr32_interp0 -DsmAlgorithm 2 -RepeatsPerScenario 3

powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_repeat_policy_local_search_matrix.ps1 `
  -ManifestCsv .\fpga\zu15eg\out\dsm_repeat_matrix\efdsm_1bit_osr32_interp0\manifest.csv `
  -OutRoot .\fpga\zu15eg\out\dsm_repeat_matrix\efdsm_1bit_osr32_interp0\policy_local_search `
  -TargetRepeats 3 -GenerateLosoPolicy
```

Run the same two commands for EFDSM2 with configuration ID
`ef2_1bit_osr32_interp0` and algorithm 3. Rebuild the combined repeat-aware
dataset, then run `analyze_dsm_dpd_repeats.py` and
`evaluate_joint_dsm_dpd_loso.py`. The repeat report includes mean, standard
deviation, 95% confidence interval, paired win rate, and an explicit third-DSM
gate. The completed three-repeat EFDSM/EFDSM2 board evidence fails that gate:
the CI is `-3457.07` to `1518.40` and EFDSM2 wins 3/8 paired conditions. The
gate requires at least three repeats per matched condition, a 95% paired CI
below zero, and at least 75% candidate win rate.

`run_dsm_lp2_repeat_matrix.ps1` is the only supported LPDSM2 (`ALGORITHM=1`)
collection entry point. It reads that gate and refuses to build or collect
until the repeat evidence passes. LPDSM2 stays 1-bit with OSR 32 and bypass
interpolation, so its monitor semantics remain comparable. Do not substitute a
multibit MASH configuration at this point.

## Leave-One-Scenario-Out Evaluation

Run the evaluator after all full-calibration traces have been collected:

```powershell
python .\fpga\zu15eg\scripts\evaluate_dpd_trace_loso.py `
  --manifest-csv .\fpga\zu15eg\trace_sets\manifest.csv `
  --prefix dpd_trace_policy_loso_<date>
```

It excludes all rows with the held `scenario_id`, predicts one mode/package
from other conditions, and compares that action against the package costs in
the held full-calibration trace. Its output reports regret, candidate
reduction, and whether the selected action existed in the held trace. This is
offline policy evaluation, not a substitute for a newly measured policy-only
board replay.
