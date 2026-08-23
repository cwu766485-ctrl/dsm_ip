#!/usr/bin/env bash
# Read-only standard-cell DB diagnostic. It neither writes netlists nor changes
# the PDK. DSM_ASIC_STDCELL_DB must be supplied by the invoking environment.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DC_SHELL=${DC_SHELL:-}
if [[ -z "$DC_SHELL" ]]; then
  DC_SHELL=$(command -v dc_shell 2>/dev/null || true)
fi

if [[ -z "$DC_SHELL" || ! -x "$DC_SHELL" ]]; then
  echo "ERROR: dc_shell is not available; set DC_SHELL or add dc_shell to PATH." >&2
  exit 2
fi
if [[ -z "${DSM_ASIC_STDCELL_DB:-}" || ! -f "$DSM_ASIC_STDCELL_DB" ]]; then
  echo "ERROR: set DSM_ASIC_STDCELL_DB to a readable standard-cell .db file." >&2
  exit 2
fi

STAMP=$(date +%Y%m%d_%H%M%S)
OUT_DIR="$ROOT/syn/reports/stdcell_probe_${STAMP}"
mkdir -p "$OUT_DIR"

DSM_ASIC_PROBE_DIR="$OUT_DIR" "$DC_SHELL" -f "$ROOT/syn/asic/probe_stdcell_library.tcl" \
  >"$OUT_DIR/dc.log" 2>&1

cat "$OUT_DIR/dc.log"
if ! grep -Eq 'STDCELL_PROBE_LIB .*cells=[1-9][0-9]* .*inv_name_matches=[1-9][0-9]*' "$OUT_DIR/dc.log"; then
  echo "ERROR: The supplied DB is readable but is not a usable logic-mapping library." >&2
  exit 1
fi
echo "STDCELL_PROBE_OUTPUT=$OUT_DIR"
