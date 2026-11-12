#!/usr/bin/env bash
# Product RTL/parameters are frozen. Build only the DV additions, then four P0s.
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
cd "$repo_dir"
if [[ "${1:-}" != --execute ]]; then
  echo 'Usage: dv/uvm/sim/run_thermo5_v3_p0.sh --execute'
  echo 'Generates vectors, builds fixed MAX_TAPS=1 product plus DV, runs four P0 scenarios.'
  exit 0
fi
mkdir -p runs/dv_convergence_v3
python3.12 tools/hw/thermo5_v3_vectors.py
make -C dv/uvm/sim thermo5-vcs \
  VCS="${VCS_HOME:-/opt/Synopsys/vcs/V-2023.12-SP1}/bin/vcs" \
  THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_FIFO_IMPL=generic \
  THERMO5_VECTORS="$repo_dir/runs/dv_convergence_v3/vectors/reset" \
  THERMO5_OUT="$repo_dir/runs/dv_convergence_v3/compile" \
  THERMO5_COV_HIER="$repo_dir/dv/uvm/sim/thermo5_tx_product_coverage.hier"
python3.12 tools/hw/thermo5_v3_p0.py --execute
python3.12 tools/hw/thermo5_v3_p0_witness.py
