#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo"
out="${1:-runs/thermo5_interp1_empty_blocked_20261006}"

if [[ -e "$out" ]]; then
  echo "ERROR: output directory already exists: $out" >&2
  exit 2
fi

make -C dv/uvm/sim thermo5-vcs-run \
  THERMO5_FIFO_IMPL=generic \
  THERMO5_OUT="$repo/$out" \
  THERMO5_VECTORS="$repo/runs/uvm_thermo5_i2_d1/vectors" \
  THERMO5_TESTNAME=thermo5_sku_interp1_empty_blocked_test \
  THERMO5_EXTRA_ARGS= \
  UVM_SEED=610071 \
  THERMO5_COVERAGE=1

vdb="$out/cov_thermo5_sku_interp1_empty_blocked_test_seed610071.vdb"
test -d "$out/simv.vdb"
test -d "$vdb"

urg -full64 -dir "$out/simv.vdb" "$vdb" \
  -report "$out/urg" -dbname thermo5_interp1_empty_blocked \
  >"$out/urg.log" 2>&1
! grep -Eq 'Error-|Design Not Loaded' "$out/urg.log" || {
  echo "ERROR: targeted URG reported a load or merge error" >&2
  exit 1
}

python3.12 tools/hw/thermo5_audit_reports.py /dev/null "$out/urg" "$out/audit"
python3.12 -c 'import csv,sys; rows=[r for r in csv.DictReader(open(sys.argv[1], newline="", encoding="utf-8")) if r["instance"]=="thermo5_sku_uvm_tb.dut.u_frontend.u_interp_1" and r["line"]=="71" and r["operand_bin"]=="1/0"]; print("\n".join(str(r) for r in rows)); sys.exit(0 if any(r["status"]=="Covered" for r in rows) else 1)' \
  "$out/audit/urg_condition_bins.csv"

echo "THERMO5_INTERP1_EMPTY_BLOCKED_PASS log=$out/thermo5_sku_interp1_empty_blocked_test_seed610071.log vdb=$vdb report=$out/urg audit=$out/audit/urg_condition_bins.csv"
