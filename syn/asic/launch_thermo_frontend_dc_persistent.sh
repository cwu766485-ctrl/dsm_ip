#!/usr/bin/env bash
set -euo pipefail

# Launch one DC run independently of the calling terminal.  stdout contains
# the PID and run directory; completion is determined by status.txt and the
# normal report/netlist gates in run_thermo_frontend_dc.sh.
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
FLAVOUR=${DSM_ASIC_FLAVOUR:?set DSM_ASIC_FLAVOUR to thermo3 or thermo5}
STAMP=$(date +%Y%m%d_%H%M%S)
RUN=${DSM_ASIC_RUN_DIR:-$ROOT/runs/${STAMP}-dc-${FLAVOUR}-tsmc28}
mkdir -p "$RUN"

env \
  DC_SHELL="${DC_SHELL:-/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell}" \
  DSM_ASIC_STDCELL_DB="${DSM_ASIC_STDCELL_DB:?set DSM_ASIC_STDCELL_DB}" \
  DSM_ASIC_FLAVOUR="$FLAVOUR" \
  DSM_ASIC_COMPILE_MODE="${DSM_ASIC_COMPILE_MODE:-bounded}" \
  DSM_ASIC_RUN_DIR="$RUN" \
  DSM_ASIC_INPUT_DDC="${DSM_ASIC_INPUT_DDC:-}" \
  nohup bash -lc '
    # Non-interactive login shells do not consistently source the Rocky user
    # tool setup.  Restore the Synopsys/DC and license environment explicitly.
    if [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi
    set +e
    "$0/syn/asic/run_thermo_frontend_dc.sh" >"$1/launcher.log" 2>&1
    rc=$?
    printf "%s\n" "$rc" >"$1/exit_code.txt"
    if [ "$rc" -eq 0 ]; then printf "PASS\n" >"$1/status.txt"; else printf "FAIL\n" >"$1/status.txt"; fi
    exit "$rc"
  ' "$ROOT" "$RUN" </dev/null >"$RUN/nohup.log" 2>&1 &

pid=$!
printf "%s\n" "$pid" >"$RUN/pid.txt"
printf "THERMO_ASIC_DC_LAUNCHED flavour=%s pid=%s run=%s\n" "$FLAVOUR" "$pid" "$RUN"
