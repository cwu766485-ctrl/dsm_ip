#!/usr/bin/env bash
set -euo pipefail

# IP-system coverage regression.  It uses deterministic bit-true tests once
# and exercises the protocol/control tests across three independent seeds.
if [[ -z "${DSM_VCS_INTERACTIVE_ENV:-}" ]]; then
  export DSM_VCS_INTERACTIVE_ENV=1
  exec bash -ic 'exec "$@"' bash "$0" "$@"
fi

cd /mnt/e/workspace/chip/dsm_ip

make -C uvm_verif/sim vcs PYTHON=python3.12 COVERAGE=1

python3.12 uvm_verif/sim/run_regression.py \
  --sim vcs \
  --tests dsm_bp_test,dsm_performance_bittrue_test,dsm_memory_dpd_bittrue_test,dsm_memory_dpd_safety_test,dsm_negative_control_test \
  --seeds 1 \
  --jobs 2 \
  --summary uvm_verif/sim/out/vcs/ip_coverage_deterministic.csv \
  --skip-compile

python3.12 uvm_verif/sim/run_regression.py \
  --sim vcs \
  --tests dsm_axi_protocol_test,dsm_control_stress_test,dsm_memory_dpd_commit_stress_test \
  --seeds 1,7,31 \
  --jobs 3 \
  --summary uvm_verif/sim/out/vcs/ip_coverage_protocol_control.csv \
  --skip-compile

python3.12 uvm_verif/sim/run_regression.py \
  --sim vcs \
  --tests dsm_axis_coverage_test,dsm_system_closure_test \
  --seeds 1,7,31 \
  --jobs 3 \
  --summary uvm_verif/sim/out/vcs/ip_coverage_axis_system.csv \
  --skip-compile

{
  head -n 1 uvm_verif/sim/out/vcs/ip_coverage_deterministic.csv
  tail -n +2 uvm_verif/sim/out/vcs/ip_coverage_deterministic.csv
  tail -n +2 uvm_verif/sim/out/vcs/ip_coverage_protocol_control.csv
  tail -n +2 uvm_verif/sim/out/vcs/ip_coverage_axis_system.csv
} > uvm_verif/sim/out/vcs/ip_coverage_summary.csv
cat uvm_verif/sim/out/vcs/ip_coverage_summary.csv

make -C uvm_verif/sim coverage-merge RUN_TAGS="\
dsm_bp_test_seed1 \
dsm_performance_bittrue_test_seed1 \
dsm_memory_dpd_bittrue_test_seed1 \
dsm_memory_dpd_safety_test_seed1 \
dsm_negative_control_test_seed1 \
dsm_axi_protocol_test_seed1 dsm_axi_protocol_test_seed7 dsm_axi_protocol_test_seed31 \
dsm_control_stress_test_seed1 dsm_control_stress_test_seed7 dsm_control_stress_test_seed31 \
dsm_memory_dpd_commit_stress_test_seed1 dsm_memory_dpd_commit_stress_test_seed7 dsm_memory_dpd_commit_stress_test_seed31 \
 dsm_axis_coverage_test_seed1 dsm_axis_coverage_test_seed7 dsm_axis_coverage_test_seed31 \
 dsm_system_closure_test_seed1 dsm_system_closure_test_seed7 dsm_system_closure_test_seed31"
