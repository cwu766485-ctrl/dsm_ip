#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SIMV="${1:?usage: run_thermo5_xpm_fwft_edge_sweep.sh SIMV VECTORS OUT_DIR}"
VECTORS="${2:?usage: run_thermo5_xpm_fwft_edge_sweep.sh SIMV VECTORS OUT_DIR}"
OUT_DIR="${3:?usage: run_thermo5_xpm_fwft_edge_sweep.sh SIMV VECTORS OUT_DIR}"

case "$OUT_DIR" in
  "$ROOT"/runs/*) ;;
  *) echo "ERROR: OUT_DIR must be a unique directory beneath $ROOT/runs" >&2; exit 2 ;;
esac
[[ -x "$SIMV" ]] || { echo "ERROR: simulator not executable: $SIMV" >&2; exit 2; }
[[ -f "$VECTORS/tid32_thermo5_frontend_i.mem" ]] || {
  echo "ERROR: vector set missing: $VECTORS" >&2; exit 2;
}
[[ ! -e "$OUT_DIR" ]] || { echo "ERROR: output directory already exists: $OUT_DIR" >&2; exit 2; }
mkdir -p "$OUT_DIR"

trials=0
hits=0
seed=620000
summary="$OUT_DIR/edge_sweep_summary.tsv"
printf 'source_phase_ps\treset_delay\tstage1_edge_samples\tstage1_reset_edges\tstage1_to_invalid\tstatus\tlog\n' > "$summary"

for source_phase_ps in {0..7500..500}; do
  for reset_delay in {0..24}; do
    log="$OUT_DIR/phase_${source_phase_ps}_delay_${reset_delay}.log"
    "$SIMV" \
      +UVM_TESTNAME=thermo5_sku_fifo_reset_phase_test \
      "+VEC_DIR=$VECTORS" "+ntb_random_seed=$seed" \
      +FIFO_RESET_PREFETCH_ONLY +FIFO_RESET_EDGE_OBSERVE \
      "+FIFO_RESET_DELAY=$reset_delay" "+SOURCE_CLOCK_PHASE_PS=$source_phase_ps" \
      -no_save -l "$log" >/dev/null 2>&1

    grep -q 'THERMO5_FIFO_RESET_PHASE_UVM_PASS' "$log" || {
      echo "ERROR: directed reset trial failed: $log" >&2; exit 1;
    }
    grep -Eq 'UVM_ERROR *: *0' "$log" && grep -Eq 'UVM_FATAL *: *0' "$log" || {
      echo "ERROR: UVM error/fatal in reset trial: $log" >&2; exit 1;
    }
    read -r stage1_edges reset_edges transition_hits < <(
      sed -n 's/.*fwft_stage1_edges=\([0-9][0-9]*\).*fwft_stage1_reset_edges=\([0-9][0-9]*\).*fwft_stage1_to_invalid=\([0-9][0-9]*\).*/\1 \2 \3/p' "$log" | tail -n 1
    )
    [[ -n "${transition_hits:-}" ]] || {
      echo "ERROR: edge counters missing from reset trial: $log" >&2; exit 1;
    }
    status=NO_TARGET_TRANSITION
    if (( transition_hits > 0 )); then
      status=TARGET_TRANSITION_HIT
      hits=$((hits + 1))
      echo "FWFT_STAGE1_RESET_EDGE_HIT phase_ps=$source_phase_ps delay=$reset_delay log=$log"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$source_phase_ps" "$reset_delay" "$stage1_edges" "$reset_edges" \
      "$transition_hits" "$status" "$log" >> "$summary"
    trials=$((trials + 1))
    seed=$((seed + 1))
  done
done

echo "THERMO5_FWFT_EDGE_SWEEP_COMPLETE trials=$trials transition_hits=$hits summary=$summary"
