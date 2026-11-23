#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
: "${VCS_HOME:?Set VCS_HOME to the licensed VCS installation}"
: "${VIVADO_ROOT:?Set VIVADO_ROOT to the Vivado installation containing data/ip/xpm}"
export PATH="$VCS_HOME/bin:$PATH"
export VCS_ARCH_OVERRIDE="${VCS_ARCH_OVERRIDE:-linux}"

out_root="${THERMO5_XPM_RESET_OUT:-$repo_root/runs/thermo5_xpm_reset_epoch_$(date +%Y%m%d_%H%M%S)}"
if [[ -e "$out_root" ]]; then
  printf 'Refusing to overwrite existing run directory: %s\n' "$out_root" >&2
  exit 2
fi
mkdir -p "$out_root/build/csrc" "$out_root/smoke" "$out_root/sweep"

simv="$out_root/build/simv"
vcs -full64 -sverilog -timescale=1ns/1ps \
  -top tb_thermo5_xpm_reset_epoch_random -top glbl \
  "$repo_root/rtl/axis/dsm_reset_sync.sv" \
  "$repo_root/rtl/axis/dsm_xpm_async_fifo.sv" \
  "$VIVADO_ROOT/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
  "$VIVADO_ROOT/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
  "$VIVADO_ROOT/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
  "$VIVADO_ROOT/data/verilog/src/glbl.v" \
  "$repo_root/dv/verif/axis/tb_thermo5_xpm_reset_epoch_random.sv" \
  -Mdir="$out_root/build/csrc" -o "$simv" -l "$out_root/build/compile.log"

run_trial() {
  local label="$1" axis_phase="$2" core_phase="$3" release_delay="$4" seed="$5"
  local run_dir="$6" log_name="$7"
  mkdir -p "$run_dir"
  (
    cd "$run_dir"
    "$simv" -no_save \
      "+AXIS_PHASE_PS=$axis_phase" \
      "+CORE_PHASE_PS=$core_phase" \
      "+RELEASE_DELAY_PS=$release_delay" \
      "+SEED=$seed" "+ntb_random_seed=$seed" \
      -l "$log_name"
  )
  if ! grep -q 'THERMO5_XPM_RESET_EPOCH_RANDOM_PASS' "$run_dir/$log_name"; then
    printf 'Missing PASS marker in %s\n' "$run_dir/$log_name" >&2
    return 1
  fi
  if [[ "$label" != smoke ]]; then
    printf '%s\t%s\t%s\t%s\t%s\tPASS\n' \
      "$label" "$axis_phase" "$core_phase" "$release_delay" "$seed" \
      >> "$out_root/sweep/summary.tsv"
  fi
}

run_trial smoke 113 251 127 101 "$out_root/smoke" run.log
printf 'trial\taxis_phase_ps\tcore_phase_ps\trelease_delay_ps\tseed\tresult\n' \
  > "$out_root/sweep/summary.tsv"
for trial in $(seq 0 15); do
  axis_phase=$(((113 + 487 * trial) % 8000))
  core_phase=$(((251 + 977 * trial) % 4571))
  release_delay=$(((127 + 613 * trial) % 4000))
  seed=$((710000 + trial))
  run_trial "$trial" "$axis_phase" "$core_phase" "$release_delay" "$seed" \
    "$out_root/sweep" "trial_${trial}.log"
done

printf 'XPM reset/epoch sweep PASS: %s\n' "$out_root/sweep/summary.tsv"
