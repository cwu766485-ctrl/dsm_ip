#!/usr/bin/env bash
# Exact cfg request/pending/boundary=101 witness with legal Identity COMMIT.
set -euo pipefail
: "${THERMO5_SIMV:?Set current frozen-product executable}"
: "${THERMO5_VECTORS:?Set independent 112-word two-frame Identity vectors}"
: "${THERMO5_OUT:?Set fresh output directory}"
mkdir -p "$THERMO5_OUT"
"$THERMO5_SIMV" +UVM_TESTNAME=thermo5_sku_axil_frame_replacement_test \
  "+VEC_DIR=$THERMO5_VECTORS" +CORE_WORDS=112 +PACKET_BEATS=32 \
  +ntb_random_seed=190042 +THERMO5_BOUNDARY_COMMIT +THERMO5_AXIL_PHASE_TRACE \
  +THERMO5_COMMIT_DELAY_CYCLES=29 +AXIL_CLOCK_PHASE_PS=5000 \
  "+THERMO5_WITNESS_VCD=$THERMO5_OUT/witness.vcd" \
  -cm line+cond+fsm+tgl+branch+assert -cm_dir "$THERMO5_OUT/test.vdb" \
  -no_save -l "$THERMO5_OUT/test.log"
python3.12 - "$THERMO5_OUT/test.log" <<'PY'
import re,sys
from pathlib import Path
s=Path(sys.argv[1]).read_text()
assert 'THERMO5_AXIL_FRAME_REPLACEMENT_UVM_PASS' in s
assert re.search(r'THERMO5_AXIL_PHASE_TRACE .*req_sync2=1 pending=0 boundary=1',s)
assert re.search(r'UVM_ERROR\s*:\s*0\b',s)
assert re.search(r'UVM_FATAL\s*:\s*0\b',s)
print('BOUNDARY_COMMIT_PRODUCT_ORACLE_PASS; verify native Condition12 vector101 in URG')
PY
