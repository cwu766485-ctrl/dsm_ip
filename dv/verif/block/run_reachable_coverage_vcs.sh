#!/usr/bin/env bash
set -euo pipefail

# Set VCS_HOME and LM_LICENSE_FILE in the invoking environment. The generated
# VDBs are intentionally separate from frozen-SKU UVM coverage.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
: "${VCS_HOME:?Set VCS_HOME externally}"
: "${LM_LICENSE_FILE:?Set LM_LICENSE_FILE externally}"
vcs="${VCS_HOME}/bin/vcs"
urg="${VCS_HOME}/bin/urg"
out="${root}/runs/uvm_thermo5_i2_d1"
cd "${root}"

run_one() {
  local name="$1" top="$2" marker="$3"
  shift 3
  local dir="${out}/reachable_${name}"
  mkdir -p "${dir}"
  "${vcs}" -full64 -sverilog -timescale=1ns/1ps \
    -cm line+cond+branch+tgl -top "${top}" "$@" \
    -Mdir="${dir}/csrc" -o "${dir}/simv" -l "${dir}/compile.log"
  "${dir}/simv" -no_save -cm line+cond+branch+tgl \
    -cm_dir "${dir}/run.vdb" -l "${dir}/run.log"
  grep -q "${marker}" "${dir}/run.log"
  if grep -Eq 'Fatal:|Error:' "${dir}/run.log"; then
    echo "ERROR: ${name} contained a simulator failure" >&2
    return 1
  fi
  "${urg}" -full64 -dir "${dir}/simv.vdb" "${dir}/run.vdb" \
    -report "${dir}/coverage" -dbname "reachable_${name}" \
    >"${dir}/coverage_merge.log" 2>&1
  echo "REACHABLE_${name^^}_PASS report=${dir}/coverage"
}

run_one interp tb_interp_x2_vector_reachable INTERP_X2_REACHABLE_PASS \
  rtl/interp/dsm_interp_x2_polyphase_vector.sv \
  dv/verif/block/interp/tb/tb_interp_x2_vector_reachable.sv
run_one dpd tb_dpd_memory_reachable DPD_MEMORY_REACHABLE_PASS \
  rtl/dpd/dpd_poly.v rtl/dpd/dpd_memory_poly.v \
  dv/verif/block/dpd/tb/tb_dpd_memory_reachable.sv
