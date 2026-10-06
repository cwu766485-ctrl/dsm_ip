#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
matrix="${THERMO5_PAYLOAD_ROOT:-$root/runs/uvm_thermo5_payload_20261003}"
seeds=(101 202 303)
test -d "$matrix" || { echo "ERROR: missing payload root $matrix" >&2; exit 2; }
for seed in "${seeds[@]}"; do
  dir="$matrix/vectors_seed$seed"
  for plane in 0 1 2 3; do
    test -s "$dir/tid32_thermo5_frontend_pa${plane}.mem" || {
      echo "ERROR: missing golden plane $plane for payload seed $seed" >&2; exit 2;
    }
  done
  sha256sum "$dir"/*.mem > "$matrix/seed${seed}_sha256.txt"
done
for fifo in generic xpm; do
  if [[ "$fifo" == xpm ]]; then
    : "${THERMO5_XPM_ROOT:?Set THERMO5_XPM_ROOT to the Vivado install root}"
  fi
  make -C "$root/dv/uvm/sim" thermo5-vcs \
    THERMO5_FIFO_IMPL="$fifo" THERMO5_XPM_ROOT="${THERMO5_XPM_ROOT:-}" \
    THERMO5_VECTORS="$matrix/vectors_seed101"
  for seed in "${seeds[@]}"; do
    make -C "$root/dv/uvm/sim" thermo5-vcs-run-only \
      THERMO5_FIFO_IMPL="$fifo" THERMO5_XPM_ROOT="${THERMO5_XPM_ROOT:-}" \
      THERMO5_VECTORS="$matrix/vectors_seed$seed" \
      THERMO5_TESTNAME=thermo5_sku_bittrue_test UVM_SEED="$seed" \
      THERMO5_EXTRA_ARGS=+STRESS_PA_READY THERMO5_COVERAGE=0
    echo "THERMO5_PAYLOAD_PASS fifo=$fifo payload_seed=$seed vectors=$matrix/vectors_seed$seed"
  done
done
