#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel)"
OUT_ARG="${1:-runs/thermo5_axil_boundary_bready_gap1_20261012}"
if [[ "$OUT_ARG" = /* ]]; then OUT="$OUT_ARG"; else OUT="$ROOT/$OUT_ARG"; fi
SIMV="$ROOT/runs/uvm_thermo5_i2_d1/simv"
VEC="$ROOT/runs/uvm_thermo5_i2_d1/vectors"
[[ -x "$SIMV" ]] || { echo "ERROR: compiled simv not found: $SIMV" >&2; exit 2; }
[[ -f "$VEC/tid32_thermo5_frontend_pa3.mem" ]] || {
  echo "ERROR: frozen-SKU MATLAB vectors not found: $VEC" >&2
  exit 2
}
mkdir -p "$OUT"

pass_count=0
trace_hits=0
for phase_ps in $(seq 0 500 9500); do
  seed=$((435000 + phase_ps / 500))
  log="$OUT/phase_${phase_ps}ps.log"
  vdb="$OUT/cov_phase_${phase_ps}ps_seed${seed}.vdb"
  marker="THERMO5_AXIL_BOUNDARY_PHASE_UVM_PASS offset=0 aw_gap=1 w_gap=1 gap_beat=-1 gap_cycles=0 start_after_beats=4 commit_on_run=0 commit_after_run_cycles=0 boundary=external-handshake identity=bittrue"
  if ! "$SIMV" \
    +UVM_TESTNAME=thermo5_sku_axil_boundary_phase_test \
    +VEC_DIR="$VEC" +ntb_random_seed="$seed" \
    -cm line+cond+fsm+tgl+branch+assert -cm_dir "$vdb" -no_save \
    +AXIL_BOUNDARY_OFFSET=0 +AXIL_BOUNDARY_AW_GAP=1 +AXIL_BOUNDARY_W_GAP=1 \
    +AXIL_COMMIT_AFTER_RUN_CORE_CYCLES=0 +AXIL_EARLY_BREADY \
    +AXIL_CLOCK_PHASE_PS="$phase_ps" +THERMO5_AXIL_PHASE_TRACE \
    -l "$log" > /dev/null 2>&1; then
    echo "FAIL AXI-clock-phase-ps=$phase_ps seed=$seed (simulator exit)" >&2
    tail -n 24 "$log" >&2
    exit 1
  fi
  grep -q "$marker" "$log" || {
    echo "FAIL pass marker missing AXI-clock-phase-ps=$phase_ps" >&2
    tail -n 24 "$log" >&2
    exit 1
  }
  grep -q 'UVM_ERROR *: *0' "$log"
  grep -q 'UVM_FATAL *: *0' "$log"
  if grep -q 'THERMO5_AXIL_PHASE_TRACE.*req_sync2=1 pending=0 boundary=1' "$log"; then
    ((trace_hits += 1))
  fi
  ((pass_count += 1))
done

(( trace_hits > 0 )) || { echo "ERROR: no public-stimulus trace hit for (1,0,1)" >&2; exit 1; }
echo "AXIL_BOUNDARY_BREADY_GAP_SWEEP_PASS runs=$pass_count target_trace_runs=$trace_hits bittrue_words=56"

report="$OUT/coverage_bready_gap_sweep"
vdbs=()
for phase_ps in $(seq 0 500 9500); do
  seed=$((435000 + phase_ps / 500))
  vdb="$OUT/cov_phase_${phase_ps}ps_seed${seed}.vdb"
  [[ -d "$vdb" ]] || { echo "ERROR: missing VDB: $vdb" >&2; exit 2; }
  vdbs+=("$vdb")
done
urg -full64 -dir "$SIMV.vdb" "${vdbs[@]}" \
  -report "$report" -dbname thermo5_axil_boundary_bready_gap_sweep \
  > "$OUT/urg_bready_gap_sweep.log" 2>&1
! grep -Eq 'Error-|Design Not Loaded' "$OUT/urg_bready_gap_sweep.log" || {
  echo "ERROR: URG merge failed; see $OUT/urg_bready_gap_sweep.log" >&2
  exit 1
}

python3 - "$report/mod16.html" <<'PY'
import re
import sys

html = open(sys.argv[1], encoding="utf-8").read()
match = re.search(
    r"LINE\s+315\s+EXPRESSION \(cfg_req_sync2.*?</pre>\s*<table.*?</table>",
    html,
    re.S,
)
if not match:
    raise SystemExit("ERROR: URG report does not contain the expected line-315 condition")
rows = re.findall(
    r'<tr class="(uRed|uGreen)"><td>([01])</td><td>([01])</td>'
    r'<td>([01])</td><td class="lf">(Covered|Not Covered)</td></tr>',
    match.group(0),
)
target = next((row for row in rows if row[1:4] == ("1", "0", "1")), None)
if target is None:
    raise SystemExit("ERROR: line-315 tuple (1,0,1) was not listed by URG")
print(f"line315_req_pending_boundary_1_0_1={target[4]}")
if target[4] != "Covered":
    raise SystemExit(3)
PY
