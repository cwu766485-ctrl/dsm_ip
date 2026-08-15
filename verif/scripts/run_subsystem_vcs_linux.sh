#!/usr/bin/env bash
set -euo pipefail

# Formal subsystem regression path.  Focused SV testbenches are compiled by
# VCS; AXI control is exercised through the existing UVM environment.
ROOT=/mnt/e/workspace/chip/dsm_ip
PYTHON=${PYTHON:-python3.12}
VCS=${VCS:-vcs}
# The Windows bridge invokes non-interactive bash, while the local EDA tool
# environment is initialised by the interactive shell.  Re-exec once without
# copying any site-specific paths or credentials into this repository.
if [[ -z "${DSM_VCS_INTERACTIVE_ENV:-}" ]]; then
  export DSM_VCS_INTERACTIVE_ENV=1
  exec bash -ic 'exec "$@"' bash "$0" "$@"
fi
OUT="$ROOT/verif/out_vcs_subsystem"
UVM_SIM="$ROOT/uvm_verif/sim"

cd "$ROOT"
test -n "${VCS_HOME:-}" && test -x "$VCS_HOME/bin/vcsMsgReport" || {
  echo "ERROR: VCS tool environment is not initialized" >&2
  exit 127
}
test -n "${LM_LICENSE_FILE:-}${SNPSLMD_LICENSE_FILE:-}" || {
  echo "ERROR: VCS license environment is not initialized" >&2
  exit 127
}
rm -rf "$OUT"
mkdir -p "$OUT"
mkdir -p "$OUT/tx_frontend" "$OUT/if_dsm"

run_focused_tb() {
  local name=$1
  local top=$2
  local marker=$3
  local tb=$4
  shift 4
  local work="$OUT/$name"

  mkdir -p "$work"
  "$VCS" -full64 -sverilog -timescale=1ns/1ps "$@" "$tb" -top "$top" \
    -Mdir="$work/csrc" -o "$work/simv" -l "$work/compile.log"
  (
    cd "$work"
    ./simv -no_save -l run.log
  )
  grep -q "$marker" "$work/run.log"
  printf '%s,PASS\n' "$name" >> "$OUT/subsystem_summary.csv"
}

printf 'subsystem,result\n' > "$OUT/subsystem_summary.csv"

"$PYTHON" uvm_verif/refmodel/python/generate_tx_frontend_vectors.py \
  --inputs 97 --mode 1 --output "$OUT/tx_frontend/tx_frontend_equivalence.csv"
run_focused_tb \
  tx_frontend tb_tx_frontend_python_bittrue TX_FRONTEND_PYTHON_BITTRUE_PASS \
  "$ROOT/verif/subsystem/tx_frontend/tb/tb_tx_frontend_python_bittrue.sv" \
  rtl/dpd/dpd_poly.v rtl/dpd/dpd_lut.v rtl/dpd/dpd_memory_poly.v \
  rtl/dpd/dpd_frontend.v rtl/interp/dsm_interp_fir_fixed.sv \
  rtl/interp/dsm_interp2_halfband.sv rtl/interp/dsm_interp_frontend.sv

"$PYTHON" uvm_verif/refmodel/python/generate_bp_ef2_vectors.py \
  --samples 4096 --output "$OUT/if_dsm/bp_ef2_equivalence.csv"
run_focused_tb \
  if_dsm tb_if_dsm_python_bittrue IF_DSM_PYTHON_BITTRUE_PASS \
  "$ROOT/verif/subsystem/if_dsm/tb/tb_if_dsm_python_bittrue.sv" \
  rtl/dsm/singlebit/dsm_core_ef2.sv rtl/tx_bandpass_if/bp_fs4_iq_mixer.sv \
  rtl/tx_bandpass_if/dsm_core_bp_ef2.sv rtl/tx_bandpass_if/dsm_core_bp_single.sv \
  rtl/tx_bandpass_if/tx_bp_if_top.sv

run_focused_tb \
  feedback tb_feedback_bridge_observer FEEDBACK_SUBSYSTEM_PASS \
  "$ROOT/verif/subsystem/feedback/tb/tb_feedback_bridge_observer.sv" \
  uvm_verif/formal/dsm_axi_protocol_sva.sv rtl/dpd/dpd_observer_async_bridge.v \
  rtl/dpd/dpd_observer.v

make -C "$UVM_SIM" vcs PYTHON="$PYTHON" COVERAGE=1
for test_seed in \
  dsm_memory_dpd_bittrue_test:1 \
  dsm_memory_dpd_safety_test:1 \
  dsm_axi_protocol_test:1 \
  dsm_axi_protocol_test:7 \
  dsm_axi_protocol_test:31 \
  dsm_control_stress_test:1 \
  dsm_control_stress_test:7 \
  dsm_control_stress_test:31; do
  test_name=${test_seed%:*}
  seed=${test_seed#*:}
  make -C "$UVM_SIM" vcs-run-only \
    UVM_TESTNAME="$test_name" UVM_SEED="$seed" COVERAGE=1
done
printf 'control,PASS\n' >> "$OUT/subsystem_summary.csv"

cat "$OUT/subsystem_summary.csv"
echo "SUBSYSTEM_VCS_SIGNOFF_PASS"
