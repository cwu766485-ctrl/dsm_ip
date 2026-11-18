#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ $# -ne 1 || "$1" != runs/* ]]; then echo 'usage: run_de_candidate3_directed.sh runs/NEW_DIR' >&2; exit 2; fi
out="$repo/$1"; mkdir "$out"
for name in tb_cfg_axil_reset_candidate2 tb_cfg_core_reset_candidate2 tb_cfg_candidate2_axil_response tb_cfg_candidate2_b_stalled tb_cfg_candidate2_mode_reset tb_cfg_candidate2_mode_readback; do
 sed 's/thermo5_dpd_axi_lite_cfg_epoch_candidate2/thermo5_dpd_axi_lite_cfg_epoch_candidate3/g' "$repo/research/vcu118_arch/$name.sv" > "$out/$name.sv"
 iverilog -g2012 -D SYNTHESIS -s "$name" -o "$out/$name.simv" "$repo/rtl/axis/dsm_reset_sync.sv" "$repo/research/vcu118_arch/thermo5_dpd_axi_lite_cfg_epoch_candidate3.sv" "$out/$name.sv" > "$out/$name.compile.log" 2>&1
 (cd "$out" && vvp "$name.simv" > "$name.simulation.log" 2>&1)
done
name=tb_cfg_candidate3_axil_mode_witness
iverilog -g2012 -D SYNTHESIS -s "$name" -o "$out/$name.simv" "$repo/rtl/axis/dsm_reset_sync.sv" "$repo/research/vcu118_arch/thermo5_dpd_axi_lite_cfg_epoch_candidate3.sv" "$repo/research/vcu118_arch/$name.sv" > "$out/$name.compile.log" 2>&1
(cd "$out" && vvp "$name.simv" > "$name.simulation.log" 2>&1)
grep -q CANDIDATE3_AXIL_ONLY_RESET_CHANGES_CORE_MODE_WITNESS "$out/$name.simulation.log"
echo 'Six directed scenarios completed; the seventh is a mode-change witness, NOT product PASS.'
