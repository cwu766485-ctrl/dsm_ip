#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
export VCS_HOME=${VCS_HOME:-/opt/Synopsys/vcs/V-2023.12-SP1}
vcs="$VCS_HOME/bin/vcs"
python=${PYTHON:-python3}
[[ -x "$vcs" ]] || { echo "ERROR: VCS not found at $vcs" >&2; exit 2; }

for order in 3 5 7; do
  out="$root/runs/dsm_v13_round4/block_dpd/poly_order$order"
  vectors="$out/vectors"
  mkdir -p "$out"
  "$python" "$root/dv/verif/block/dpd/refmodel/generate_dpd_poly_closure_vectors.py" \
    --order "$order" --output-dir "$vectors"
  "$vcs" -full64 -sverilog -timescale=1ns/1ps \
    -cm line+cond+fsm+tgl+branch "+define+DPD_POLY_ORDER=$order" \
    -Mdir="$out/csrc" -o "$out/simv" \
    "$root/rtl/dpd/dpd_poly.v" \
    "$root/dv/verif/block/dpd/tb/tb_dpd_poly_closure.sv" \
    -top tb_dpd_poly_closure -l "$out/compile.log"
  "$out/simv" \
    "+VECTOR_FILE=$vectors/dpd_poly_order$order.csv" \
    +VECTOR_COUNT=72 "+EXPECTED_SATURATIONS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["expected_output_saturations"])' "$vectors/manifest.json")" \
    -cm line+cond+fsm+tgl+branch -cm_dir "$out/coverage.vdb" -l "$out/run.log"
  grep -F "DPD_POLY_CLOSURE_PASS order=$order" "$out/run.log"
done

echo "DPD_POLY_CLOSURE_VCS_PASS"
