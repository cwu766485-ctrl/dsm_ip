#!/usr/bin/env bash
# Public asynchronous reset after legal RUN and PA backpressure.
set -euo pipefail
: "${THERMO5_SIMV:?Set frozen-product executable with stalled reset test}"
: "${THERMO5_VECTORS:?Set independent56-word Identity vectors with3 frame starts}"
: "${THERMO5_OUT:?Set fresh output directory}"
extra_args=()
if [[ "${THERMO5_RESET_AT_READY_TAIL:-0}" == 1 ]]; then
  extra_args+=(+THERMO5_RESET_AT_READY_TAIL)
fi
mkdir -p "$THERMO5_OUT"
"$THERMO5_SIMV" +UVM_TESTNAME=thermo5_sku_axil_stalled_reset_test \
  "+VEC_DIR=$THERMO5_VECTORS" +CORE_WORDS=56 +ntb_random_seed=1045100 \
  "+THERMO5_WITNESS_VCD=$THERMO5_OUT/witness.vcd" \
  -cm line+cond+fsm+tgl+branch+assert -cm_dir "$THERMO5_OUT/test.vdb" \
  "${extra_args[@]}" -no_save -l "$THERMO5_OUT/test.log"
python3.12 - "$THERMO5_OUT/test.log" <<'PY'
import re,sys
from pathlib import Path
s=Path(sys.argv[1]).read_text()
assert 'THERMO5_STALLED_RESET_PASS' in s
assert re.search(r'UVM_ERROR\s*:\s*0\b',s)
assert re.search(r'UVM_FATAL\s*:\s*0\b',s)
print('STALLED_RESET_ORACLE_PASS; check exact native reset-event tuples in URG')
PY
