#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ $# -ne 1 || "$1" != runs/* ]]; then echo 'usage: run_cubic_stream_equiv.sh runs/NEW_DIR' >&2; exit 2; fi
out="$repo/$1";mkdir "$out"
sed 's/module dsm_interp_x2_centered_cubic_vector #(/module cubic_reference #(/' "$repo/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv" > "$out/ref.sv"
for candidate in a b; do
 sed 's/module dsm_interp_x2_centered_cubic_vector #(/module cubic_candidate #(/' "$repo/research/vcu118_arch/cubic_midpoint_candidate_${candidate}.sv" > "$out/candidate_${candidate}.sv"
 iverilog -g2012 -D SYNTHESIS -s tb_cubic_stream_equivalence -o "$out/simv_$candidate" "$out/ref.sv" "$out/candidate_${candidate}.sv" "$repo/dv/verif/integration/vcu118_arch/tb_cubic_stream_equivalence.sv" > "$out/compile_$candidate.log" 2>&1
 vvp "$out/simv_$candidate" > "$out/sim_$candidate.log" 2>&1
 grep -q CUBIC_STREAM_EQ_PASS "$out/sim_$candidate.log"
done
