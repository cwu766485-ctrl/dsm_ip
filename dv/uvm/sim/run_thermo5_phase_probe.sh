#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
fifo_impl=${THERMO5_FIFO_IMPL:-generic}
case "$fifo_impl" in
  generic) run_dir="$root/runs/uvm_thermo5_i2_d1" ;;
  xpm) run_dir="$root/runs/uvm_thermo5_i2_d1_xpm" ;;
  *) echo 'ERROR: THERMO5_FIFO_IMPL must be generic or xpm' >&2; exit 2 ;;
esac
bin="$run_dir/simv"
vectors="$root/runs/uvm_thermo5_i2_d1/vectors"
out="$run_dir/phase_probe"
test -x "$bin"
test -f "$vectors/tid32_thermo5_frontend_pa3.mem"
mkdir -p "$out"
printf 'beat,hold,stall_percent,seed,i1_out_empty,i2_s1_empty,result\n'
for beat in 1 4 8 16; do
  for hold in 0 20 80 200; do
    for stall in 25 90; do
      log="$out/b${beat}_h${hold}_s${stall}.log"
      "$bin" +UVM_TESTNAME=thermo5_sku_bubble_backpressure_test \
        +VEC_DIR="$vectors" +ntb_random_seed=2 \
        +BUBBLE_GAP_BEAT="$beat" +BUBBLE_GAP_CYCLES=80 \
        +BUBBLE_HOLD_PA_CYCLES="$hold" +BUBBLE_STALL_PERCENT="$stall" \
        -l "$log" >/dev/null 2>&1 || true
      line=$(grep 'THERMO5_BUBBLE_BACKPRESSURE_UVM_PASS' "$log" | tail -1 || true)
      if [[ -n "$line" ]]; then
        i1=$(sed -n 's/.*i1_out_empty=\([0-9]*\).*/\1/p' <<< "$line")
        i2=$(sed -n 's/.*i2_s1_empty=\([0-9]*\).*/\1/p' <<< "$line")
        printf '%s,%s,%s,2,%s,%s,PASS\n' "$beat" "$hold" "$stall" "$i1" "$i2"
      else
        printf '%s,%s,%s,2,,,FAIL\n' "$beat" "$hold" "$stall"
      fi
    done
  done
done
