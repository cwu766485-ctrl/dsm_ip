#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DC_SHELL=${DC_SHELL:-/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell}
DB=${DSM_ASIC_STDCELL_DB:?set DSM_ASIC_STDCELL_DB to the TSMC28 RVT .db}
FLAVOUR=${DSM_ASIC_FLAVOUR:?set DSM_ASIC_FLAVOUR to thermo3 or thermo5}
STAMP=$(date +%Y%m%d_%H%M%S)
RUN=${DSM_ASIC_RUN_DIR:-$ROOT/syn/reports/asic_${FLAVOUR}_tsmc28_${STAMP}}
mkdir -p "$RUN"
DSM_ASIC_STDCELL_DB="$DB" DSM_ASIC_RUN_DIR="$RUN" DSM_ASIC_FLAVOUR="$FLAVOUR" \
  "$DC_SHELL" -f "$ROOT/syn/asic/dc_thermo_frontend.tcl" >"$RUN/dc.log" 2>&1
grep -q THERMO_ASIC_DC_COMPLETE "$RUN/dc.log"
if grep -Eq '^Error:|No target library found|unmapped logic|Unable to match ports|Width mismatch' "$RUN/dc.log"; then
  echo "ERROR: DC completed with mapping/elaboration errors; see $RUN/dc.log" >&2
  exit 1
fi
for f in library check_design check_timing_pre check_timing qor area timing_setup timing_hold power reference constraints; do
  test -s "$RUN/reports/$f.rpt"
done
if grep -Eiq 'unmapped|unresolved|No target library' "$RUN/reports/area.rpt" "$RUN/reports/check_design.rpt"; then
  echo "ERROR: mapped-design checks contain unmapped/unresolved logic" >&2
  exit 1
fi
echo "THERMO_ASIC_DC_PASS flavour=$FLAVOUR run=$RUN"
