#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
out="$root/runs/dpd_identity_exhaustive"
export VCS_HOME=${VCS_HOME:-/opt/Synopsys/vcs/V-2023.12-SP1}
test -x "$VCS_HOME/bin/vcs"
if [[ -z ${LM_LICENSE_FILE:-} && -z ${SNPSLMD_LICENSE_FILE:-} ]]; then
  echo 'ERROR: configure the Synopsys license environment in Rocky WSL' >&2
  exit 2
fi
mkdir -p "$out"
cd "$root"
"$VCS_HOME/bin/vcs" -full64 -sverilog -timescale=1ns/1ps \
  rtl/dpd/dpd_poly.v rtl/dpd/dpd_memory_poly.v \
  dv/verif/block/dpd/tb/tb_dpd_identity_exhaustive.sv \
  -top tb_dpd_identity_exhaustive -Mdir="$out/csrc" \
  -o "$out/simv" -l "$out/compile.log"
"$out/simv" -l "$out/run.log"
grep 'DPD_IDENTITY_EXHAUSTIVE_PASS' "$out/run.log"
