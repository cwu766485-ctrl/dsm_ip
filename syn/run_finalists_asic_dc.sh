#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DC_SHELL=${DC_SHELL:-${DC_HOME:+$DC_HOME/bin/dc_shell}}
PERIOD_NS=${DSM_ASIC_PERIOD_NS:-10.0}
FAST=${DSM_ASIC_FAST:-0}
MAX_CORES=${DSM_ASIC_MAX_CORES:-4}
STAMP=$(date +%Y%m%d_%H%M%S)
OUT_ROOT=${DSM_ASIC_OUT_ROOT:-"$ROOT/syn/reports/finalists_asic_dc_${STAMP}"}
RESUME=${DSM_ASIC_RESUME:-0}

DB_28=${DSM28_STDCELL_DB:-/home/ray/pdk/TSMC28/standard_cell_rvt/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp7t40p140_180a/tcbn28hpcplusbwp7t40p140tt0p9v25c.db}
DB_40=${TSMC40_LIB_TC:-}
NODES=${DSM_ASIC_NODES:-"28nm 40nm"}
CASES=${DSM_ASIC_CASES:-"I0_D0_EFDSM:2 I0_D1_LPDSM2:1 I0_D3_MASH11:4 I0_D5_MB_EFDSM:9"}

if [[ -z "$DC_SHELL" || ! -x "$DC_SHELL" ]]; then
  echo "ERROR: dc_shell is unavailable; set DC_SHELL or DC_HOME." >&2
  exit 127
fi
mkdir -p "$OUT_ROOT"
printf 'Node,Library,Case,Algorithm,Period_ns,Status,RunDir\n' > "$OUT_ROOT/summary.csv"
overall_status=0

run_node() {
  local node=$1 db=$2
  for item in $CASES; do
    local label=${item%%:*} algorithm=${item##*:}
    local run_dir="$OUT_ROOT/${node}/${label}"
    if [[ "$RESUME" == "1" && -s "$run_dir/dc.log" ]] && \
       grep -q 'DSM ASIC DC completed:' "$run_dir/dc.log" && \
       [[ -s "$run_dir/reports/qor.rpt" ]] && [[ -s "$run_dir/reports/area.rpt" ]] && \
       [[ -s "$run_dir/reports/timing.rpt" ]] && [[ -s "$run_dir/reports/hold_timing.rpt" ]] && \
       [[ -s "$run_dir/reports/power.rpt" ]]; then
      printf '%s,%s,%s,%s,%s,PASS,%s\n' "$node" "$db" "$label" "$algorithm" "$PERIOD_NS" "$run_dir" >> "$OUT_ROOT/summary.csv"
      continue
    fi
    mkdir -p "$run_dir"
    printf '%s,%s,%s,%s,%s,RUNNING,%s\n' "$node" "$db" "$label" "$algorithm" "$PERIOD_NS" "$run_dir" >> "$OUT_ROOT/summary.csv"
    set +e
    DSM_ASIC_STDCELL_DB="$db" DSM_ASIC_NODE="$node" DSM_ASIC_LABEL="$label" \
      DSM_ASIC_ALGORITHM="$algorithm" DSM_ASIC_PERIOD_NS="$PERIOD_NS" \
      DSM_ASIC_RUN_DIR="$run_dir" DSM_ASIC_FAST="$FAST" DSM_ASIC_MAX_CORES="$MAX_CORES" "$DC_SHELL" -f "$ROOT/syn/dc_finalist_axi_asic.tcl" \
      >"$run_dir/dc.log" 2>&1
    local rc=$?
    set -e
    local status=FAIL
    if [[ $rc -eq 0 ]] && grep -q 'DSM ASIC DC completed:' "$run_dir/dc.log" && \
       [[ -s "$run_dir/reports/qor.rpt" ]] && [[ -s "$run_dir/reports/area.rpt" ]] && \
       [[ -s "$run_dir/reports/timing.rpt" ]] && [[ -s "$run_dir/reports/hold_timing.rpt" ]] && \
       [[ -s "$run_dir/reports/power.rpt" ]]; then
      status=PASS
    else
      overall_status=1
    fi
    printf '%s,%s,%s,%s,%s,%s,%s\n' "$node" "$db" "$label" "$algorithm" "$PERIOD_NS" "$status" "$run_dir" >> "$OUT_ROOT/summary.csv"
  done
}

for node in $NODES; do
  case "$node" in
    28nm) run_node 28nm "$DB_28" ;;
    40nm) run_node 40nm "$DB_40" ;;
    *) echo "ERROR: unknown node '$node'; use 28nm and/or 40nm." >&2; exit 2 ;;
  esac
done
echo "ASIC finalist DC summary: $OUT_ROOT/summary.csv"
exit "$overall_status"
