#!/usr/bin/env bash
set -euo pipefail

# Full AXI BP EFDSM2 SKU, pre-layout DC synthesis at the same 100 MHz target
# used by the retained finalist study. It keeps only the 5th-order, four-tap
# memory-polynomial DPD branch. The caller must provide a usable DC executable
# and the permitted 28 nm standard-cell DB path.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DC_SHELL=${DC_SHELL:-${DC_HOME:+$DC_HOME/bin/dc_shell}}
PERIOD_NS=${DSM28_PERIOD_NS:-10.0}
STDCELL_DB=${DSM28_STDCELL_DB:-}
STAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR=${DSM28_BP_OUT_DIR:-"$ROOT/syn/reports/bp_ef2_axi_28nm_dc_${STAMP}"}

if [[ -z "$DC_SHELL" || ! -x "$DC_SHELL" ]]; then
  echo "ERROR: dc_shell is unavailable; set DC_SHELL or DC_HOME." >&2
  exit 127
fi
if [[ -z "$STDCELL_DB" || ! -f "$STDCELL_DB" ]]; then
  echo "ERROR: set DSM28_STDCELL_DB to an approved readable 28 nm standard-cell .db file." >&2
  exit 2
fi

mkdir -p "$RUN_DIR"
DSM28_STDCELL_DB="$STDCELL_DB" \
DSM28_LABEL="BP_EFDSM2_AXI" \
DSM28_ALGORITHM=3 \
DSM28_DUC_MODE=3 \
DSM28_PERIOD_NS="$PERIOD_NS" \
DSM28_RUN_DIR="$RUN_DIR" \
  "$DC_SHELL" -f "$ROOT/syn/dc_finalist_axi_28nm.tcl" >"$RUN_DIR/dc.log" 2>&1

grep -q "DSM 28nm DC completed:" "$RUN_DIR/dc.log"
if grep -Eq '(^Error:|OPT-101|contains unmapped logic)' "$RUN_DIR/dc.log"; then
  echo "ERROR: DC reported an unmapped or failed synthesis; reports are invalid." >&2
  exit 1
fi
for report in qor area timing hold_timing power; do
  [[ -s "$RUN_DIR/reports/${report}.rpt" ]]
done
if grep -Eq 'Total cell area:[[:space:]]+0\.000000|contains unmapped logic' "$RUN_DIR/reports/area.rpt"; then
  echo "ERROR: DC area report contains unmapped or zero-area logic." >&2
  exit 1
fi
echo "BP EFDSM2 28 nm AXI DC reports: $RUN_DIR"
