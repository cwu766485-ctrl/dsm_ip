#!/usr/bin/env bash
# Reviewed Rocky/VCS entry point for the MATLAB-quantized QAM-OFDM UVM test.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
vector="$root/uvm_verif/refmodel/python/out/qam_ofdm_input.csv"
if [[ ! -f "$vector" ]]; then
  echo "ERROR: Missing $vector"
  echo "Run MATLAB export_uvm_qam_ofdm_vectors before this VCS task."
  exit 2
fi

vcs_wrapper="bash $root/uvm_verif/sim/vcs_login_wrapper.sh"
make -C "$root/uvm_verif/sim" vcs PYTHON=python3 VCS="$vcs_wrapper" COVERAGE=1
make -C "$root/uvm_verif/sim" vcs-run-only PYTHON=python3 VCS="$vcs_wrapper" COVERAGE=1 \
  UVM_TESTNAME=dsm_qam_ofdm_bittrue_test UVM_SEED="${UVM_SEED:-1}"
