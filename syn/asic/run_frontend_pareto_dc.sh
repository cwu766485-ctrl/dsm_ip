#!/usr/bin/env bash
set -euo pipefail

# Small, interpretable PPA matrix. Signal-quality metrics are deliberately not
# generated here; pair each row with the matching MATLAB fixed-point analysis.

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NODE=${DSM_ASIC_NODE:-unknown_node}
TARGET_MHZ=${DSM_ASIC_TARGET_MHZ:-100}
STAMP=$(date +%Y%m%d_%H%M%S)
MATRIX_DIR=${DSM_ASIC_MATRIX_DIR:-"$ROOT/syn/reports/asic_frontend_pareto_${NODE}_${TARGET_MHZ}mhz_${STAMP}"}

mkdir -p "$MATRIX_DIR"
declare -a CONFIGS=(
  "x4_bypass:1:0"
  "x8_bypass:2:0"
  "x16_bypass:3:0"
  "x32_bypass:4:0"
  "x32_memory_poly5_4tap:4:1"
)

for config in "${CONFIGS[@]}"; do
  IFS=: read -r name interp memory <<<"$config"
  echo "=== Frontend PPA ${name} ==="
  DSM_ASIC_TARGET_MHZ="$TARGET_MHZ" \
  DSM_ASIC_LABEL="$name" \
  DSM_ASIC_INTERP_MODE="$interp" \
  DSM_ASIC_ENABLE_DPD_MEMORY="$memory" \
  DSM_ASIC_DPD_POLY_ORDER=5 \
  DSM_ASIC_DPD_MP_MAX_TAPS=4 \
  DSM_ASIC_RUN_DIR="$MATRIX_DIR/$name" \
    bash "$ROOT/syn/asic/run_performance_sku_dc.sh"
done

python3 "$ROOT/syn/asic/parse_dc_reports.py" --matrix-dir "$MATRIX_DIR"
echo "ASIC_FRONTEND_PARETO_PASS matrix_dir=$MATRIX_DIR"
