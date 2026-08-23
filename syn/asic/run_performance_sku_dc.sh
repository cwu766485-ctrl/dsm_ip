#!/usr/bin/env bash
set -euo pipefail

# Public launcher for the fixed Performance SKU. A caller supplies the local
# Design Compiler executable and permitted standard-cell DB through env vars.

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DC_SHELL=${DC_SHELL:-${DC_HOME:+$DC_HOME/bin/dc_shell}}
if [[ -z "$DC_SHELL" ]]; then
  DC_SHELL=$(command -v dc_shell 2>/dev/null || true)
fi
STDCELL_DB=${DSM_ASIC_STDCELL_DB:-}
TARGET_MHZ=${DSM_ASIC_TARGET_MHZ:-100}
NODE=${DSM_ASIC_NODE:-unknown_node}
LABEL=${DSM_ASIC_LABEL:-performance_sku}
STAMP=$(date +%Y%m%d_%H%M%S)
PERIOD_NS=$(awk -v mhz="$TARGET_MHZ" 'BEGIN { if (mhz <= 0) exit 1; printf "%.6f", 1000.0 / mhz }')
RUN_DIR=${DSM_ASIC_RUN_DIR:-"$ROOT/syn/reports/asic_${LABEL}_${NODE}_${TARGET_MHZ}mhz_${STAMP}"}

if [[ -z "$DC_SHELL" || ! -x "$DC_SHELL" ]]; then
  echo "ERROR: dc_shell was not found or is not executable: '${DC_SHELL:-<unset>}'" >&2
  echo "       Run this launcher from a Linux shell, not the dc_shell> Tcl prompt." >&2
  echo "       Either unset DC_SHELL to use dc_shell from PATH, or set it with:" >&2
  echo "       export DC_SHELL=\"\$(command -v dc_shell)\"" >&2
  exit 127
fi
if [[ -z "$STDCELL_DB" || ! -f "$STDCELL_DB" ]]; then
  echo "ERROR: set DSM_ASIC_STDCELL_DB to a readable standard-cell .db file." >&2
  exit 2
fi

mkdir -p "$RUN_DIR"
DSM_ASIC_STDCELL_DB="$STDCELL_DB" \
DSM_ASIC_RUN_DIR="$RUN_DIR" \
DSM_ASIC_PERIOD_NS="$PERIOD_NS" \
DSM_ASIC_TARGET_MHZ="$TARGET_MHZ" \
DSM_ASIC_NODE="$NODE" \
DSM_ASIC_LABEL="$LABEL" \
DSM_ASIC_ACTIVITY_FILE="${DSM_ASIC_ACTIVITY_FILE:-}" \
DSM_ASIC_INTERP_MODE="${DSM_ASIC_INTERP_MODE:-4}" \
DSM_ASIC_DPD_POLY_ORDER="${DSM_ASIC_DPD_POLY_ORDER:-5}" \
DSM_ASIC_DPD_MP_MAX_TAPS="${DSM_ASIC_DPD_MP_MAX_TAPS:-4}" \
DSM_ASIC_ENABLE_DPD_MEMORY="${DSM_ASIC_ENABLE_DPD_MEMORY:-1}" \
DSM_ASIC_ENABLE_DPD_POLY="${DSM_ASIC_ENABLE_DPD_POLY:-0}" \
DSM_ASIC_ENABLE_DPD_LUT="${DSM_ASIC_ENABLE_DPD_LUT:-0}" \
  "$DC_SHELL" -f "$ROOT/syn/asic/dc_performance_sku.tcl" >"$RUN_DIR/dc.log" 2>&1 || {
    echo "ERROR: Design Compiler exited unsuccessfully. Diagnostic tail:" >&2
    tail -n 80 "$RUN_DIR/dc.log" >&2 || true
    exit 1
  }

grep -q "ASIC_PERFORMANCE_SKU_DC_COMPLETE" "$RUN_DIR/dc.log"
if grep -Eq '(^Error:|^ERROR:)' "$RUN_DIR/dc.log"; then
  echo "ERROR: Design Compiler reported a script or mapping error." >&2
  tail -n 80 "$RUN_DIR/dc.log" >&2
  exit 1
fi
if grep -q 'This design contains unmapped logic' "$RUN_DIR/reports/area.rpt"; then
  echo "ERROR: Design Compiler completed but the area report contains unmapped logic." >&2
  tail -n 80 "$RUN_DIR/reports/area.rpt" >&2
  exit 1
fi
for report in check_design check_timing qor area timing hold_timing power clocks constraints; do
  [[ -s "$RUN_DIR/reports/${report}.rpt" ]]
done

python3 "$ROOT/syn/asic/parse_dc_reports.py" --run-dir "$RUN_DIR"
echo "ASIC_PPA_PASS run_dir=$RUN_DIR"
