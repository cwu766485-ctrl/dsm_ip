#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PERIOD_NS=${DSM28_PERIOD_NS:-10.0}
STDCELL_DB=${DSM28_STDCELL_DB:-/home/ray/pdk/TSMC28/standard_cell_rvt/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp7t40p140_180a/tcbn28hpcplusbwp7t40p140tt0p9v25c.db}
STAMP=$(date +%Y%m%d_%H%M%S)
OUT_ROOT="$ROOT/syn/reports/finalists_28nm_dc_${STAMP}"
mkdir -p "$OUT_ROOT"
printf 'Case,Algorithm,Period_ns,Status,RunDir\n' > "$OUT_ROOT/summary.csv"

if ! command -v dc_shell >/dev/null 2>&1; then
  for item in I0_D0_EFDSM:2 I0_D1_LPDSM2:1 I0_D3_MASH11:4 I0_D5_MB_EFDSM:9; do
    label=${item%%:*}
    algorithm=${item##*:}
    printf '%s,%s,%s,TOOL_UNAVAILABLE,\n' "$label" "$algorithm" "$PERIOD_NS" >> "$OUT_ROOT/summary.csv"
  done
  echo "ERROR: dc_shell is unavailable on PATH; no 28nm synthesis was run." >&2
  echo "Finalist 28nm DC summary: $OUT_ROOT/summary.csv"
  exit 127
fi
if [[ ! -f "$STDCELL_DB" ]]; then
  echo "ERROR: TSMC28 standard-cell DB is missing: $STDCELL_DB" >&2
  exit 2
fi

for item in I0_D0_EFDSM:2 I0_D1_LPDSM2:1 I0_D3_MASH11:4 I0_D5_MB_EFDSM:9; do
  label=${item%%:*}
  algorithm=${item##*:}
  run_dir="$OUT_ROOT/$label"
  mkdir -p "$run_dir"
  set +e
  DSM28_STDCELL_DB="$STDCELL_DB" DSM28_LABEL="$label" \
    DSM28_ALGORITHM="$algorithm" DSM28_PERIOD_NS="$PERIOD_NS" \
    DSM28_RUN_DIR="$run_dir" dc_shell -f "$ROOT/syn/dc_finalist_axi_28nm.tcl" \
    >"$run_dir/dc.log" 2>&1
  rc=$?
  set -e
  if [[ $rc -eq 0 ]] && grep -q "DSM 28nm DC completed:" "$run_dir/dc.log"; then
    status=PASS
  else
    status=FAIL
  fi
  printf '%s,%s,%s,%s,%s\n' "$label" "$algorithm" "$PERIOD_NS" "$status" "$run_dir" >> "$OUT_ROOT/summary.csv"
done
echo "Finalist 28nm DC summary: $OUT_ROOT/summary.csv"
