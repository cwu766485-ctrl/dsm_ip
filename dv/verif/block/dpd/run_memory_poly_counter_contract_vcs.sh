#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
vcs_bin="${VCS_HOME:?Set VCS_HOME to the licensed VCS installation}/bin/vcs"
out="${THERMO5_OUT:-$repo/runs/dpd_memory_poly_counter_contract_vcs}"
mkdir -p "$out"

"$vcs_bin" -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
  -top tb_dpd_memory_poly_counter_contract -Mdir="$out/csrc" -o "$out/simv" \
  "$repo/rtl/dpd/dpd_poly.v" \
  "$repo/rtl/dpd/dpd_memory_poly.v" \
  "$repo/dv/verif/block/dpd/tb/tb_dpd_memory_poly_counter_contract.sv" \
  -l "$out/compile.log"

"$out/simv" -l "$out/sim.log"
grep -Fq "DPD_MEMORY_COUNTER_CONTRACT_PASS" "$out/sim.log"
if grep -Eqi '(^|[^A-Za-z])(fatal|error)[^A-Za-z]*[1-9]' "$out/sim.log"; then
  echo "ERROR: counter-contract VCS log contains a nonzero error or fatal count" >&2
  exit 1
fi
echo "DPD_MEMORY_COUNTER_CONTRACT_VCS_PASS"
