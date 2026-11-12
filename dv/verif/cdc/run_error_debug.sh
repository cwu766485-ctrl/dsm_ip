#!/usr/bin/env bash
# Focused diagnostics; do not merge these block/illustrative results into URG.
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
out=${1:?Use a new absolute output directory below runs/}
case "$out" in "$root"/runs/*) ;; *) exit 2 ;; esac
if test -e "$out"; then echo 'Output already exists' >&2; exit 2; fi
mkdir -p "$out/hazard" "$out/mailbox"
cd "$root"
python3.12 - "$root" "$out" <<'PY'
import sys
from pathlib import Path
r,o=map(Path,sys.argv[1:])
s=[str(r/x.strip()) for x in (r/'dv/uvm/sim/thermo5_sku_filelist.f').read_text().splitlines() if x.strip().startswith('rtl/')]
(o/'hazard/sources.f').write_text('\n'.join(s)+'\n'+str(r/'dv/verif/cdc/tb_thermo5_prefill_cdc_hazard.sv')+'\n')
PY
vcs -full64 -sverilog -timescale=1ns/1ps -top tb_thermo5_prefill_cdc_hazard -f "$out/hazard/sources.f" -Mdir="$out/hazard/csrc" -o "$out/hazard/simv" > "$out/hazard/compile.log" 2>&1
(cd "$out/hazard"; ./simv > test.log 2>&1)
rg -q PREFILL_HAZARD_REPRO_PASS "$out/hazard/test.log"
vcs -full64 -sverilog -top tb_thermo5_mailbox_reset_contract rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv dv/verif/cdc/tb_thermo5_mailbox_reset_contract.sv -Mdir="$out/mailbox/csrc" -o "$out/mailbox/simv" > "$out/mailbox/compile.log" 2>&1
(cd "$out/mailbox"; ./simv > test.log 2>&1)
rg -q MAILBOX_RESET_CONTRACT_REPRO_PASS "$out/mailbox/test.log"
