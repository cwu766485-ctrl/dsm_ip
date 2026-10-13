# Thermo5 counter bit23 long-stream closure (2026-10-12)

## Status

The independent oracle vectors are generated and fixture-validated. Both the
generic and real-XPM VCS/UVM runs and their separate same-binary URG audits are
**PASS** for bit23. Overall code-coverage closure is still **OPEN**: bits24-31,
other design conditions/branches, and an XPM FWFT transition remain uncovered.

## Oracle input

The 8,388,611-word vector set is in
`runs/thermo5_bit23_oracle_20261012/`. It was produced by
`tools/hw/thermo5_range_oracle.py` from the independently MATLAB-validated
36-word fixture
`runs/thermo5_fast_oracle_compare_20261008/range_stress_s610073_t2_legacy/`.
The generator reported `MATLAB_ALL_EIGHT_FILES_MATCH words=36` and
`ORACLE_COMPLETE words=8388611`. The exact input-source and output-file hashes
are in `oracle_manifest.json`. No RTL or MATLAB algorithm was changed.

The selected length crosses the bit23 threshold and then uses the public reset
at the end of the checked stream to exercise the opposite toggle direction.
This is a reachable code-coverage target, not an exclusion candidate.

## VCS run

The generic VCS/UVM long-counter run uses current source, seed610080,
`thermo5_sku_long_counter_test`, `+CORE_WORDS=8388611`,
`+EXPECT_SIGNED_EXTREMES`, and full line/condition/FSM/toggle/branch/assert
coverage. Its output directory is
`runs/thermo5_bit23_vcs_generic_20261012/`. It checks all four 64-bit output
planes against the generated oracle, verifies the signed endpoint stimulus,
and checks all16 DPD sample/saturation counters clear after public reset.

The generic run was launched in the interactive Rocky shell where the VCS
license setup is available. It completed seed610080 with
`THERMO5_SKU_UVM_PASS source=4793492 output=8388611 four_planes=bittrue`,
`THERMO5_LONG_COUNTER_RESET_PASS`, and UVM_ERROR/UVM_FATAL both zero. CPU time
was5729.870s. The matching URG comparison used this binary's `simv.vdb`, a
same-binary 56-word baseline VDB, and the long-run VDB. The exact audit confirms
`sample_count[23]` toggled both directions in all16 `.u_dpd` lane instances.
The complete per-bit audit is in
`runs/thermo5_bit23_vcs_generic_20261012/bit23_delta_audit/summary.json`;
bits24-31 remain open. The audit's raw hierarchy score uses only the two
same-binary tests and is not a full-regression coverage score.

The real XPM build used seed610081 in its own output directory,
`runs/thermo5_bit23_vcs_xpm_20261012/`. Its completed result is
`source=4793492 output=8388611 four_planes=bittrue`, with the all16-counter
reset PASS marker and zero UVM errors/fatals; CPU time was5847.870s. Generic
and XPM used independent binaries and reports. Do not merge coverage databases
across FIFO implementations.

Each FIFO's same-binary raw URG merge that additionally includes 56-word gain
extreme and gain-toggle MATLAB vectors and passing reset delays1-8 is under
`runs/thermo5_bit23_vcs_{generic,xpm}_20261012/coverage_current_gain_reset_safe/`.
It reports generic DUT score87.00% (line87.09, condition76.46, toggle85.46,
FSM100.00, branch73.00, assertion100.00) and XPM DUT score80.17% (line76.99,
condition67.89, toggle82.88, FSM90.91, branch62.37, assertion100.00). The XPM
hierarchy includes vendor XPM cells, so its denominator is not comparable to
generic. The merge uses only the named original current-test VDBs, two new
passing gain tests, and passing reset-delay VDBs per FIFO; it excludes the
delay9 starvation failure and exploratory/malformed-argument VDBs. These
remain raw scores, not adjusted or 100% coverage.

The added tests used seeds610300/610301 (generic) and610302/610303 (XPM),
`thermo5_sku_bittrue_test`, and the pre-existing
`runs/thermo5_coverage100_vectors_20261006/gain_saturation/` and
`runs/thermo5_gain_toggle_delivery_20261006/` 56-word sets. All four checked
56 output words on each of four planes against the oracle, with signed-extreme
and PA-ready stress enabled; each log reports UVM_ERROR=0 and UVM_FATAL=0.
This cheap stimulus raised raw score by0.22 percentage points for generic and
0.19 for XPM relative to the prior merge. It did not close the remaining
counter, DPD saturation, interpolation/frame-marker, or XPM vendor/FWFT gaps.

A further legal reset-delay sweep used the same compiled generic and XPM
binaries: delays1-8 each passed the 56-word/four-plane replay with zero UVM
errors/fatals. A generic delay9 attempt triggered the test's early-FIFO-
starvation guard and its VDB was excluded. The passing reset trials added no
new URG condition, branch, or toggle hit; the explicitly reviewed merged
report is `coverage_current_gain_reset_safe/` and retains the same raw scores.

The per-bit helper reports `sample_count[23]` both directions in16/16 DPD lane
instances for each FIFO. Bits24-31 remain open in this stream: eight bits x
two directions x16 lanes =256 reachable toggle bins per FIFO. Their absence is
not a waiver candidate. A natural bit24 threshold requires about16.78M output
words (roughly twice this simulation); bit31 remains a multi-day runtime target.

## Closure gate

For each implementation, gates1-3 above PASSed. The next counter experiment is
bit24. It must derive the required vector length from the counter threshold,
validate the generated oracle against the MATLAB fixture, and use separate
generic/XPM binaries and per-bit URG reports. Continue to leave bits25-31
reachable/open until their natural thresholds are hit. Keep exact exclusions
separate from raw scores. Raw 100% is not currently attainable from the
frozen identity-DPD SKU in a practical run: upper counter toggles are reachable
but require very long streams, and parameter-inactive/identity-only bins need
exact proofs and reviewed waivers rather than forced internal state or blanket
exclusions. The FWFT transition is still OPEN, not waived.
