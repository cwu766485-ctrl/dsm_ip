#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NODE=${DSM_ASIC_NODE:-unknown_node}
STAMP=$(date +%Y%m%d_%H%M%S)
MATRIX_DIR=${DSM_ASIC_MATRIX_DIR:-"$ROOT/syn/reports/asic_performance_sku_${NODE}_${STAMP}"}
TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=(100 200 300 400 500)
fi

mkdir -p "$MATRIX_DIR"
for mhz in "${TARGETS[@]}"; do
  echo "=== ASIC Performance SKU @ ${mhz} MHz ==="
  DSM_ASIC_TARGET_MHZ="$mhz" \
  DSM_ASIC_RUN_DIR="$MATRIX_DIR/${mhz}MHz" \
  DSM_ASIC_LABEL="performance_sku" \
    bash "$ROOT/syn/asic/run_performance_sku_dc.sh"
done

python3 "$ROOT/syn/asic/parse_dc_reports.py" --matrix-dir "$MATRIX_DIR"
echo "ASIC_PPA_SWEEP_PASS matrix_dir=$MATRIX_DIR"
