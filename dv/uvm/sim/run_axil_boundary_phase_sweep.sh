#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel)"
OUT_ARG="${1:-runs/thermo5_axil_boundary_phase_generic_20261012}"
if [[ "$OUT_ARG" = /* ]]; then
  OUT="$OUT_ARG"
else
  OUT="$ROOT/$OUT_ARG"
fi
SIMV="$OUT/simv"
VEC="$ROOT/runs/uvm_thermo5_i2_d1/vectors"

[[ -x "$SIMV" ]] || { echo "ERROR: compiled simv not found: $SIMV" >&2; exit 2; }
[[ -f "$VEC/tid32_thermo5_frontend_pa3.mem" ]] || {
  echo "ERROR: frozen-SKU MATLAB vectors not found: $VEC" >&2
  exit 2
}

pass_count=0
for aw_gap in 0 1; do
  for offset in $(seq 0 28); do
    seed=$((423000 + aw_gap * 100 + offset))
    log="$OUT/phase_v2_aw${aw_gap}_off${offset}.log"
    vdb="$OUT/cov_boundary_aw${aw_gap}_off${offset}_seed${seed}.vdb"
    pass_marker="THERMO5_AXIL_BOUNDARY_PHASE_UVM_PASS offset=$offset aw_gap=$aw_gap w_gap=0 gap_beat=-1 gap_cycles=0 start_after_beats=4 commit_on_run=0 commit_after_run_cycles=-1 boundary=external-handshake identity=bittrue"
    if [[ ! -d "$vdb" ]] || ! grep -q "$pass_marker" "$log" 2>/dev/null; then
      if ! "$SIMV" \
        +UVM_TESTNAME=thermo5_sku_axil_boundary_phase_test \
        +VEC_DIR="$VEC" +ntb_random_seed="$seed" \
        -cm line+cond+fsm+tgl+branch+assert -cm_dir "$vdb" -no_save \
        +AXIL_BOUNDARY_OFFSET="$offset" \
        +AXIL_BOUNDARY_AW_GAP="$aw_gap" +AXIL_BOUNDARY_W_GAP=0 \
        -l "$log" > /dev/null 2>&1; then
        echo "FAIL aw_gap=$aw_gap offset=$offset seed=$seed (simulator exit)" >&2
        tail -n 20 "$log" >&2
        exit 1
      fi
    fi
    grep -q "$pass_marker" "$log" || {
      echo "FAIL aw_gap=$aw_gap offset=$offset seed=$seed (pass marker missing)" >&2
      tail -n 20 "$log" >&2
      exit 1
    }
    grep -q 'UVM_ERROR *: *0' "$log"
    grep -q 'UVM_FATAL *: *0' "$log"
    ((pass_count += 1))
  done
done

echo "AXIL_BOUNDARY_PHASE_SWEEP_PASS runs=$pass_count legal_external_commits=1" \
  "word_count=56 bittrue=PASS"

report="$OUT/coverage_phase_aw_sweep_v2"
vdbs=()
for aw_gap in 0 1; do
  for offset in $(seq 0 28); do
    seed=$((423000 + aw_gap * 100 + offset))
    vdbs+=("$OUT/cov_boundary_aw${aw_gap}_off${offset}_seed${seed}.vdb")
  done
done
for vdb in "${vdbs[@]}"; do
  [[ -d "$vdb" ]] || { echo "ERROR: missing phase-sweep VDB: $vdb" >&2; exit 2; }
done
urg -full64 -dir "$OUT/simv.vdb" "${vdbs[@]}" \
  -report "$report" -dbname thermo5_axil_boundary_phase_aw_sweep \
  > "$OUT/urg_phase_aw_sweep.log" 2>&1
! grep -Eq 'Error-|Design Not Loaded' "$OUT/urg_phase_aw_sweep.log" || {
  echo "ERROR: URG merge failed; see $OUT/urg_phase_aw_sweep.log" >&2
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
    raise SystemExit("ERROR: line-315 target tuple (1,0,1) was not listed by URG")
print(f"line315_req_pending_boundary_1_0_1={target[4]}")
if target[4] != "Covered":
    raise SystemExit(3)
PY
