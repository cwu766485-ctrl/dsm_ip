#!/usr/bin/env bash
set -euo pipefail

# Direct VCS regression for the reusable Memory-Poly ready/valid boundary.
# It intentionally does not use UVM: the DUT is a single datapath block and
# the testbench provides an exact unit-gain transaction oracle.
if [[ -z "${DSM_VCS_INTERACTIVE_ENV:-}" ]]; then
  export DSM_VCS_INTERACTIVE_ENV=1
  exec bash -ic 'exec "$@"' bash "$0" "$@"
fi

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work="$repo/verif/out_vcs_dpd_memory_poly_random"
mkdir -p "$work"

# `dpd_sat_signed` is the shared saturation helper declared at the end of
# dpd_poly.v. It is not a standalone source file.
vcs -full64 -sverilog -timescale=1ns/1ps \
  -o "$work/simv" \
  "$repo/rtl/dpd/dpd_poly.v" \
  "$repo/rtl/dpd/dpd_memory_poly.v" \
  "$repo/verif/block/dpd/tb/tb_dpd_memory_poly_random_protocol.sv" \
  -l "$work/compile.log"

"$work/simv" -l "$work/sim.log"
grep -Fq "DPD_MEMORY_RANDOM_PROTOCOL_PASS" "$work/sim.log"
if grep -Eqi '(^|[^A-Za-z])(fatal|error)[^A-Za-z]*[1-9]' "$work/sim.log"; then
  echo "ERROR: VCS log contains a nonzero error or fatal count" >&2
  exit 1
fi

echo "DPD_MEMORY_RANDOM_PROTOCOL_VCS_PASS"
