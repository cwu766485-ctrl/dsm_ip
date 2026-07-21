# Fixed-Point Memory-DPD Decision Tree

## Scope

This block is a pre-board deployment candidate for selecting one of six
memory-DPD coefficient packages or requesting the mandatory 14-candidate local
search. It does not replace the DPD datapath, estimate RF EVM/ACLR, or prove
performance on a physical PA.

The current feature schema is `aligned_complex_pa_monitor_v2`. The source must
be a complex PA observation aligned to the TX reference with the exact
finite-width arithmetic implemented by `dpd_observer`. The legacy AXI PL monitor
registers use schema `pl_dsm_monitor_v1`: input fields describe the complex TX
stream, but output power, output peak/average, ACPR, and spectral fields
describe the post-DSM one-bit stream. Identical field names do not make these
schemas numerically interchangeable. Wrapper version `0x00010002` now also
exposes `aligned_complex_pa_monitor_v2` from the complex observation stream.
The v2 behavioral matrix and frozen model now use this exact contract. The old
`behavioral_pa_observation_v1` model remains historical evidence only.

The source data contains 288 behavioral conditions from 12 PA/observation
profiles, eight waveform combinations, and three random seeds. Strict
leave-one-PA-profile software evaluation selected a depth-4 tree over the LUT
baseline. The frozen full-data tree is a separate deployment artifact and must
not be described as a LOSO result.

## Fixed-Point Contract

The interface contains 13 signed 32-bit engineered features in Q12.20. In
index order, the pre-quantization definitions are:

| Index | Definition |
|---:|---|
| 0 | `qam / 64` |
| 1 | `bandwidth_mhz / 40` |
| 2 | `backoff` |
| 3 | `temperature_q8_8 / (85 * 256)` |
| 4 | `output_power / max(input_power, 1)` |
| 5 | `peak / max(avg_mag, 1)` |
| 6 | `evm_proxy / max(input_power, 1)` |
| 7 | `acpr_proxy / max(output_power, 1)` |
| 8 | `spec_adj / max(spec_bin1, 1)` |
| 9 | `spec_bin2 / max(spec_bin0, 1)` |
| 10 | `clip_count / sample_count` |
| 11 | `saturation_count / sample_count` |
| 12 | `observation_error_l1 / max(input_power, 1)` |

The behavioral data uses `sample_count=1152` at 20 MHz and `2304` at 40 MHz.
Board replay must use the actual monitor window sample count instead of
assuming those constants.

Python performs all divisions and Q12.20 round-to-nearest, ties away from zero,
quantization. C and RTL consume exactly those integers; they do not repeat
normalization or ratio division. Tree fitting first reduces every input to its
Q12.20-visible value, then uses z-score normalization. Export maps each split
back to the raw feature domain and chooses the largest left-partition Q20 value
as the threshold. This prevents the model from learning distinctions below one
fixed-point LSB and preserves every fitted path exactly.

`dpd_tinyml_features.c` is the PS-side integer feature builder. It uses 64-bit
intermediates, denominator guards, signed-temperature handling, and saturation
to signed 32-bit output. A separate 288-condition test compares every generated
Q12.20 feature and final C tree decision against Python with no tolerance.

Every feature has an inclusive training-domain minimum and maximum. Invalid or
out-of-domain input always returns package 6, meaning fallback. Qualified
leaves return packages 1, 4, or 5. A leaf is released only when every training
sample in that leaf is safe and the selected package is the oracle package for
every sample. The comparison rule is left on `feature <= threshold` and right
on `feature > threshold`.

## Reproducibility and Equivalence

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_tinyml_tree_equivalence.ps1
```

`scripts/run_memory_tinyml_preboard.ps1` runs strict quantized LOSO, model and
source regeneration, both host C tests, retained-trace replay, and XSim in one
command. `-SkipXsim` is available only for restricted host environments; it
prints a warning and must not be treated as RTL signoff.

The script regenerates the v2 model and 329 golden decisions, builds the C
reference with warnings as errors, and runs the RTL testbench in XSim. The
vectors consist of all 288 behavioral conditions, both sides of every split,
both sides of every feature-domain boundary, released-leaf envelope exits, and
one invalid input. Package,
direct/fallback action, decision path, path length, and out-of-distribution
status must match exactly.

Retained source artifacts:

- `docs/evidence/dpd/memory_tinyml_tree_q20_v2_20260715.json`
- `docs/evidence/dpd/memory_tinyml_tree_q20_loso_v2_20260715.json`
- `docs/evidence/dpd/memory_tinyml_complex_feedback_replay_v2_20260715.json`
- `verif/vectors/dpd/memory_tinyml_tree_q20_v2.txt`
- `fpga/zu15eg/baremetal/src/dpd_tinyml_tree.c`
- `rtl/dpd/dpd_tinyml_tree.v`

The frozen model version is `0x00020000`. It fits the full behavioral set with
154 direct suggestions and 134 fallback decisions, zero training safety
violations, zero training regret, and zero float-to-fixed path changes. These
are consistency/fitting results, not unseen PA or board qualification.

Strict fixed-point PA-profile LOSO retrains and quantizes the tree inside every
fold. A pure tree plus leaf envelope has zero violations but is non-worse than
the LUT in only 2/12 folds, so it is not independently promoted. The qualified
control policy is hierarchical: accept a direct tree result, otherwise run the
existing software LUT safety gate, and use 14-candidate search if both reject.
That combination has zero safety violations, is non-worse than LUT in 12/12
folds and strictly better in 5/12, with 186 direct suggestions and 102 fallback
decisions, mean regret `408.861`, and mean candidate count `5.604`.

The RTL output is therefore a direct suggestion, not final authority. PS must
retain the LUT and fallback arbitration. A standalone RTL fallback must never
be interpreted as permission to bypass search.

## Integration and Board Gate

The standalone RTL is included in project source lists but is not instantiated
in the AXI wrapper. The existing board policy therefore remains unchanged and
continues to require local search. This avoids enabling a one-candidate path
before board replay.

The v2 behavioral generator retains 288 raw Q1.15 reference/feedback traces,
497,664 complex samples total, together with each Q2.14 alignment gain. An
independent Python replay re-executes arithmetic shift, Q1.15 saturation,
special signed absolute values, 32-bit accumulator wrap, complex slew, and the
four-phase fixed-bin state machine. All 288 reconstructed monitor records match
the training CSV exactly. The frozen tree produces 154 direct suggestions with
zero labeled safety violations, zero mean/max regret, and 134 fallbacks.

This is simulation trace evidence, not physical-PA board evidence. Every replay
row deliberately records deployment action `fallback_14`; the AXI wrapper does
not instantiate the tree and the bare-metal policy still mandates the complete
14-candidate search.

The retained 16-row DSM-aware data set has been replayed as a schema audit. All
16 rows correctly request fallback: every row lacks temperature and aligned
observer L1 error, and every row has out-of-domain gain, peak/average, EVM, and
ACPR ratios. Seven rows also miss the behavioral spectral-ratio range and one
misses both spectral ranges. Python and C agree on all 16 fallback decisions.
This result blocks direct deployment and confirms that widening bounds would
hide a feature-source error.

The second architecture path is now implemented at the RTL/register-contract
level. `dpd_observer` exposes aligned reference/observation magnitude sums,
observation peak, clip/saturation, complex slew, complex fixed-bin spectral
proxies, the existing L1 error, pair count, and start-latched temperature. Its
behavioral vector test compares every statistic exactly against MATLAB, and
AXI smoke verifies every new read-only register.

The missing-monitor, exact-data-generation, quantized-LOSO, source-generation,
and simulation-trace gates are complete. Python, host C, and RTL match all 329
condition/boundary decisions, and the C raw-feature builder matches all 288
conditions. The remaining deployment gate is real or independently generated
complex-feedback evidence that was not used to fit the full-data model, plus
PS integration of the qualified hierarchy rather than standalone tree direct
execution.

The two valid model families remain:

1. Extend the behavioral data generator to emulate the exact PL DSM monitor
   arithmetic and train a `pl_dsm_monitor_v1` model. Such a model predicts
   digital proxy cost only and cannot claim PA/RF awareness.
2. Use `aligned_complex_pa_monitor_v2` and train/replay a PA-aware model
   against that exact contract. This is the preferred path when a complex
   feedback receiver or behavioral equivalent is available.

Until independent feedback replay and PS hierarchy integration pass,
`feature_valid` remains disconnected from the AXI wrapper and local search
remains mandatory.
