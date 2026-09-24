#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR/../.."
make -C dv/uvm/sim vcs PYTHON=python3.12 COVERAGE=1
python3.12 dv/uvm/sim/run_regression.py \
  --sim vcs \
  --tests dsm_control_stress_test \
  --seeds 1,7,31 \
  --jobs 3 \
  --skip-compile
make -C dv/uvm/sim coverage-merge \
  RUN_TAGS="dsm_control_stress_test_seed1 dsm_control_stress_test_seed7 dsm_control_stress_test_seed31"
