# Thermo5 DPD counter bit18 closure - 2026-10-08

## Result

The independent 262,150-word range-stress stream passed the current-source
thermo5 long-counter test on both generic and real XPM FIFO builds. All four
PA planes matched for 262,150 output words, and the test's post-stream reset
check cleared all 16 DPD lane counters. UVM reported zero errors and fatals.

The exact-final same-binary URG merges report native raw DUT hierarchy scores
of 87.50% generic and 80.30% XPM. Compared with the prior exact-final reports
(87.49% and 80.29%), bit18 added coverage in the existing denominator.
For every one of the 16 DPD `sample_count` instances in each FIFO report,
URG groups bit18 with `sample_count[18:0]` and reports toggle, 1-to-0, and
0-to-1 as Yes. The `sample_count[31:19]` group remains uncovered for all 16
instances. Thus bit18 is covered in both directions; bits 19 through 31 remain 416
counter directions per FIFO OPEN. Overall coverage remains partial.

The XPM FSM remains 8/9. Existing open reset tuples, generic interpolation
clamp bins and branch arms, and other previously recorded gaps remain open.
The updated source-matched per-bin audit is
`runs/thermo5_high_counter_xpm_bin_audit_after_bit18_20261008.json`. No
exclusions or coverage waivers were added.

## Oracle and generator evidence

The initial MATLAB PID 26480 call started at 14:52:49 SGT and was still CPU
active at 18:56 SGT with no output files in
`runs/thermo5_bit18_fast_20261008`. After confirming its exact command and
empty target, that process was stopped to use the existing independent
NumPy integer oracle. The MATLAB attempt recorded at
`runs/thermo5_bit18_20261008/attempt.json` is a separate earlier 32-minute
attempt; it remains an accurate record of that run.

`tools/hw/thermo5_range_oracle.py` validated all eight output files against
the 36-word MATLAB fixture in
`runs/thermo5_fast_oracle_compare_20261008/range_stress_s610073_t2_legacy`,
then generated the 262,150-word stream in about 30 seconds. Provenance and
SHA256 digests are in
`runs/thermo5_bit18_oracle_20261008/oracle_manifest.json`. The fast and legacy
MATLAB generators also matched all eight `.mem` hashes in each of 18 short
configuration pairs (144 files, zero mismatches), summarized in
`runs/thermo5_fast_oracle_compare_20261008/comparison_manifest.json`. A separate 56-word
extreme-profile check with frame gains `[32767,-32768,24576]`, step 4096, and
two interpolation taps matched all eight fast/legacy hashes.
The vector generator now exposes a selectable `fast`/`legacy` TID engine;
the production MATLAB TID step and RTL are unchanged. The long stream used
the independently validated NumPy integer oracle, not the stalled MATLAB run.

The required MATLAB P0 command remains
`scripts/run_matlab_p0_bittrue_check.cmd`; its persisted result is
`matlab/out/p0_bittrue_compare.csv`: seven designs, 65,536 samples each,
zero mismatches. The command writes that CSV but does not create a separate
run log.

## VCS and URG provenance

Source digest for the current 202 RTL/DV files:
`0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`.
The long-counter simulations reused the exact-source PASS binaries recorded
in `runs/thermo5_frozen_regression_fwftmon_20261008/manifest.json`. Commands:

```text
make -C dv/uvm/sim thermo5-vcs-run-only THERMO5_FIFO_IMPL=generic THERMO5_OUT=/mnt/e/workspace/chip/dsm_ip/runs/thermo5_frozen_regression_fwftmon_20261008/generic THERMO5_VECTORS=/mnt/e/workspace/chip/dsm_ip/runs/thermo5_bit18_oracle_20261008 THERMO5_TESTNAME=thermo5_sku_long_counter_test UVM_SEED=610073 "THERMO5_EXTRA_ARGS=+CORE_WORDS=262150 +EXPECT_SIGNED_EXTREMES" THERMO5_COVERAGE=1
make -C dv/uvm/sim thermo5-vcs-run-only THERMO5_FIFO_IMPL=xpm THERMO5_XPM_ROOT=/mnt/d/Xilinx/Vivado/2024.1 THERMO5_OUT=/mnt/e/workspace/chip/dsm_ip/runs/thermo5_frozen_regression_fwftmon_20261008/xpm THERMO5_VECTORS=/mnt/e/workspace/chip/dsm_ip/runs/thermo5_bit18_oracle_20261008 THERMO5_TESTNAME=thermo5_sku_long_counter_test UVM_SEED=610073 "THERMO5_EXTRA_ARGS=+CORE_WORDS=262150 +EXPECT_SIGNED_EXTREMES" THERMO5_COVERAGE=1
```

VCS was V-2023.12-SP1. Generic CPU time was 165.500 seconds; XPM was
178.690 seconds. The final URG merges used all 17 generic VDBs and 31 XPM
VDBs present in the matching-source build directories, including the prior
exact-final inputs and the new bit18 VDB. Their simulator binary SHA256s are
`f6b20aff14127d7b1b939fdbbec6fc176d8c6db343cc83954ab0855f0869cd97`
(generic) and
`27f1199892d65ebd9abc262921ce68823ce6fd4d6d096c5ff460d7a712d4dfa`
(XPM).

Logs and consolidated same-binary URG reports:

- Generic log: `runs/thermo5_frozen_regression_fwftmon_20261008/generic/thermo5_sku_long_counter_test_seed610073.log`
- XPM log: `runs/thermo5_frozen_regression_fwftmon_20261008/xpm/thermo5_sku_long_counter_test_seed610073.log`
- Generic URG: `runs/thermo5_bit18_urg_20261008/generic_coverage/exact_final_plus_bit18_final`
- XPM URG: `runs/thermo5_bit18_urg_20261008/xpm_coverage/exact_final_plus_bit18_final`
- URG logs: `runs/thermo5_bit18_urg_20261008/generic_urg_exact_final_plus_bit18_final.log` and `runs/thermo5_bit18_urg_20261008/xpm_urg_exact_final_plus_bit18_final.log`

Each consolidated report merged every VDB present in its same-binary build,
including the previous exact-final set and the new bit18 VDB. No VDB from a
different simulator binary was merged. Reports, raw URG HTML, and VDBs remain
under `runs/` as generated evidence.
