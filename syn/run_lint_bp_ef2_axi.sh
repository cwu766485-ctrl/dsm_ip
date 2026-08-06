#!/usr/bin/env bash
set -euo pipefail
# Lint-only DC elaboration. No compile_ultra and no PPA claim.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DC_SHELL=${DC_SHELL:-${DC_HOME:+$DC_HOME/bin/dc_shell}}
STDCELL_DB=${DSM_LINT_STDCELL_DB:-/home/ray/pdk/TSMC28/standard_cell_rvt/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp7t40p140_180a/tcbn28hpcplusbwp7t40p140tt0p9v25c.db}
STAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR=${DSM_LINT_RUN_DIR:-"$ROOT/syn/reports/lint_bp_ef2_axi_${STAMP}"}
if [[ -z "$DC_SHELL" || ! -x "$DC_SHELL" ]]; then echo "ERROR: dc_shell is unavailable; set DC_SHELL or DC_HOME." >&2; exit 127; fi
if [[ ! -f "$STDCELL_DB" ]]; then echo "ERROR: standard-cell DB is missing: $STDCELL_DB" >&2; exit 2; fi
mkdir -p "$RUN_DIR"
DSM_LINT_STDCELL_DB="$STDCELL_DB" DSM_LINT_RUN_DIR="$RUN_DIR" \
  "$DC_SHELL" -f "$ROOT/syn/dc_lint_bp_ef2_axi.tcl" >"$RUN_DIR/dc_lint.log" 2>&1
test -s "$RUN_DIR/LINT_PASS"
for report in check_design check_timing reference timing_paths ports; do test -s "$RUN_DIR/reports/${report}.rpt"; done
echo "BP EFDSM2 AXI DC lint reports: $RUN_DIR"
