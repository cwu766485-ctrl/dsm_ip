#!/usr/bin/env bash
set -euo pipefail

# Long system-UVM stress regression.  This is intentionally separate from the
# 20-run fast closure so developers can run it overnight or in CI capacity.
if [[ -z "${DSM_VCS_INTERACTIVE_ENV:-}" ]]; then
  export DSM_VCS_INTERACTIVE_ENV=1
  exec bash -ic 'exec "$@"' bash "$0" "$@"
fi

cd /mnt/e/workspace/chip/dsm_ip
seeds="1,7,11,19,31,47,61,79,97,113,131,151,173,197,223,251,283,317,349,383"
tests="dsm_axi_protocol_test,dsm_control_stress_test,dsm_memory_dpd_commit_stress_test,dsm_axis_coverage_test,dsm_system_closure_test,dsm_negative_control_test,dsm_register_corner_test"

make -C uvm_verif/sim vcs PYTHON=python3.12 COVERAGE=1
python3.12 uvm_verif/sim/run_regression.py \
  --sim vcs --tests "$tests" --seeds "$seeds" --jobs 4 \
  --summary uvm_verif/sim/out/vcs/ip_extended_regression.csv --skip-compile
