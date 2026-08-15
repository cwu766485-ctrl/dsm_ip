#!/usr/bin/env bash
set -euo pipefail

report_dir="uvm_verif/formal/out/dsm_ip_fpv"
runtime_dir="${DSM_FPV_RUNTIME_DIR:-/tmp/dsm_ip_fpv_runtime}"
repo_dir="$PWD"
mkdir -p "$report_dir"
rm -f "$report_dir/report_fv.txt" "$report_dir/report_engines.txt" \
  "$report_dir/report_fv_setup.txt"
rm -rf "$report_dir/counterexamples"
rm -rf "$report_dir/counterexample_fsdb"
rm -rf "$runtime_dir"
mkdir -p "$runtime_dir"

if ! command -v vcf >/dev/null 2>&1; then
  echo "ERROR: vcf is not available after loading the interactive EDA environment." >&2
  exit 127
fi

echo "VCF=$(command -v vcf)"
echo "VCF_RUN_BEGIN=$(date --iso-8601=seconds)"

set +e
cd "$runtime_dir"
vcf -batch -fmode FPV \
  -x "puts VCF_TCL_BEGIN; cd {$repo_dir}; if {[catch {source uvm_verif/formal/run_dsm_ip_fpv.tcl} err]} {puts stderr \$err; exit 1}; exit"
vcf_status=$?
set -e

cd "$repo_dir"
if [[ -f "$runtime_dir/vcf.log" ]]; then
  cp "$runtime_dir/vcf.log" "$report_dir/vcf.log"
fi

report="$report_dir/report_fv.txt"
setup_report="$report_dir/report_fv_setup.txt"
if [[ "$vcf_status" -eq 0 ]]; then
  if [[ ! -s "$setup_report" ]]; then
    echo "ERROR: VC Formal did not produce $setup_report." >&2
    vcf_status=3
  elif grep -q 'Model is incorrect due to design/setup issues' "$setup_report"; then
    echo "ERROR: VC Formal setup report contains unresolved setup violations." >&2
    vcf_status=4
  elif grep -Eq ':[[:space:]]+[1-9][0-9]*[[:space:]]*$' "$setup_report"; then
    echo "ERROR: VC Formal setup report contains a nonzero violation count." >&2
    vcf_status=4
  elif [[ ! -s "$report" ]]; then
    echo "ERROR: VC Formal did not produce $report." >&2
    vcf_status=5
  elif grep -Eq -- '- # (falsified|inconclusive|undetermined|unprocessed)[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$report"; then
    echo "ERROR: VC Formal report contains unresolved or failing properties." >&2
    vcf_status=6
  fi
fi
echo "VCF_EXIT_STATUS=$vcf_status"
exit "$vcf_status"
