#!/usr/bin/env bash
# Run after compiling the frozen centered-cubic AXI-Lite product filelist.
# Vectors must be the independent 112-word, two-frame identity fixture.
set -euo pipefail
: "${THERMO5_SIMV:?Set THERMO5_SIMV to the current product executable}"
: "${THERMO5_VECTORS:?Set THERMO5_VECTORS to the 112-word identity fixture}"
: "${THERMO5_OUT:?Set THERMO5_OUT to a fresh run directory}"
mkdir -p "$THERMO5_OUT"
"$THERMO5_SIMV" +UVM_TESTNAME=thermo5_sku_axil_frame_replacement_test \
  "+VEC_DIR=$THERMO5_VECTORS" +CORE_WORDS=112 +PACKET_BEATS=32 \
  +ntb_random_seed=210042 +THERMO5_SOURCE_GAP_BEAT=32 \
  +THERMO5_SOURCE_GAP_CYCLES=11 +THERMO5_REQUIRE_SINGLE_REPLACEMENT \
  "+THERMO5_WITNESS_VCD=$THERMO5_OUT/witness.vcd" \
  -cm line+cond+fsm+tgl+branch+assert -cm_dir "$THERMO5_OUT/test.vdb" \
  -no_save -l "$THERMO5_OUT/test.log"
python3.12 - "$THERMO5_OUT/test.log" <<'PY'
import re, sys
from pathlib import Path
log = Path(sys.argv[1]).read_text()
assert re.search(r'FRAME_REPLACEMENT_UVM_PASS stage1=[1-9]\d* stage2=[1-9]\d*', log)
assert re.search(r'UVM_ERROR\s*:\s*0\b', log)
assert re.search(r'UVM_FATAL\s*:\s*0\b', log)
print('EXACT_SINGLE_REPLACEMENT_PASS: both stages and four-plane oracle')
PY
