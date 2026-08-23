#!/usr/bin/env bash
set -euo pipefail

# Focused, reproducible regression for legal Performance-SKU control corners.
# This remains separate from the 280-run suite so failures retain one run
# directory and one seed per testcase.
if [[ -z "${DSM_VCS_INTERACTIVE_ENV:-}" ]]; then
  export DSM_VCS_INTERACTIVE_ENV=1
  exec bash -ic 'exec "$@"' bash "$0" "$@"
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR/../.."

make -C uvm_verif/sim vcs PYTHON=python3.12 COVERAGE=1

tests=(
  dsm_axi_lite_channel_backpressure_test
  dsm_commit_during_stream_test
  dsm_commit_reset_interlock_test
  dsm_memory_pipe_stall_coverage_test
)

for test in "${tests[@]}"; do
  tag="${test}_seed1"
  make -C uvm_verif/sim vcs-run-only \
    PYTHON=python3.12 COVERAGE=1 \
    UVM_TESTNAME="$test" UVM_SEED=1 RUN_TAG="$tag"

  log="uvm_verif/sim/out/vcs/runs/${tag}/run.log"
  grep -q '\[TEST_DONE\]' "$log"
  if grep -Eq 'UVM_ERROR\s*:\s*[1-9]|UVM_FATAL\s*:\s*[1-9]' "$log"; then
    echo "ERROR: ${test} reported UVM_ERROR or UVM_FATAL" >&2
    exit 1
  fi
done

echo "REACHABLE_CORNER_REGRESSION_PASS tests=${#tests[@]} seed=1"
