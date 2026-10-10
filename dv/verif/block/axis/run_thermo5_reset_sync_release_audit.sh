#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
OUT="${1:-$ROOT/runs/thermo5_reset_bin_audit_20261006_05}"
TB="$ROOT/dv/verif/block/axis/tb_thermo5_reset_sync_release_audit.sv"
RTL="$ROOT/rtl/axis/dsm_reset_sync.sv"

test ! -e "$OUT" || { echo "ERROR: output path already exists: $OUT" >&2; exit 2; }
mkdir -p "$OUT"
cd "$ROOT"
{
  printf 'utc='; date -u +%FT%TZ
  printf 'host='; hostname
  printf 'VCS_HOME=%s\n' "${VCS_HOME:-UNSET}"
  printf 'VCS_ARCH_OVERRIDE=%s\n' "${VCS_ARCH_OVERRIDE:-UNSET}"
  printf 'vcs='; command -v vcs
  vcs -ID 2>&1 | head -n 8 || true
  printf 'urg='; command -v urg
} > "$OUT/tool_manifest.txt"

vcs -full64 -sverilog -timescale=1ns/1ps \
  -cm line+cond+assert -top thermo5_sku_uvm_tb \
  -Mdir="$OUT/csrc" -o "$OUT/simv" \
  "$RTL" "$TB" -l "$OUT/compile.log"

"$OUT/simv" -cm line+cond+assert -cm_dir "$OUT/reset_sync.vdb" \
  -l "$OUT/run.log"
grep -q 'RESET_SYNC_AUDIT_PASS source_epochs=2 core_epochs=2 source_release_edges=2 core_release_edges=2 source_1_0_samples=0 core_1_0_samples=0' "$OUT/run.log"

urg -full64 -dir "$OUT/simv.vdb" "$OUT/reset_sync.vdb" \
  -report "$OUT/urg" -dbname thermo5_reset_sync_audit \
  > "$OUT/urg.log" 2>&1
! grep -Eq 'Error-|Design Not Loaded' "$OUT/urg.log"

echo "RESET_SYNC_URG_REPORT=$OUT/urg"
echo "RESET_SYNC_AUDIT_LOG=$OUT/run.log"
