#!/usr/bin/env bash
set -euo pipefail

# Rebuild the reviewed frozen-SKU line-coverage report from one exact merged
# VDB. URG efile entries carry elaborated-instance checksums, so no output of
# this script is checked in or reused with another VDB.
if [[ -z "${DSM_VCS_INTERACTIVE_ENV:-}" ]]; then
  export DSM_VCS_INTERACTIVE_ENV=1
  exec bash -ic 'exec "$@"' bash "$0" "$@"
fi

# This script lives in uvm_verif/sim/coverage.  Three parent directories are
# required to reach the repository root; four would select the parent of repo.
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo"

vdb="${1:-uvm_verif/sim/dsm_uvm_merged.vdb}"
report_root="${2:-uvm_verif/sim/out/vcs/coverage_triage}"
template="$report_root/template"
exclusions="$report_root/exclusions/frozen_performance_sku.line.elfile"
reviewed="$report_root/reviewed"

if [[ ! -d "$vdb" ]]; then
  # The merged database is generated output and intentionally ignored by Git.
  # Recreate it only from the guarded 300-run CSV/VDB set, not from an
  # arbitrary subset of runs.
  echo "INFO: merged VDB not found; rebuilding it from the guarded extended regression" >&2
  bash uvm_verif/sim/run_ip_extended_coverage_linux.sh
fi

if [[ ! -d "$vdb" ]]; then
  echo "ERROR: merged VDB still not found after rebuild: $vdb" >&2
  echo "       Verify the 300-run regression and inspect uvm_verif/sim/out/vcs/ip_extended_regression.csv" >&2
  exit 2
fi

rm -rf "$template" "$reviewed"
mkdir -p "$report_root/exclusions"

# This triage flow generates line-only exclusions.  Some historical merged
# VDBs contain no FSM coverage shape below the DUT hierarchy; asking URG for
# every default metric then emits a partial HTML report but no
# fullexclude.line template.  Limit this invocation to the only metric the
# generated elfile is allowed to waive.
urg -full64 -dir "$vdb" -metric line -dump full_exclusions -report "$template"
bash uvm_verif/sim/coverage/generate_frozen_sku_elfile.sh \
  "$template/fullexclude.line" "$exclusions"
# Retain every DUT metric present in this frozen VDB, but do not request the
# absent FSM shape.  The elfile above remains line-only by construction.
urg -full64 -dir "$vdb" -metric line+cond+tgl+branch+assert \
  -elfile "$exclusions" -report "$reviewed"

echo "FROZEN_SKU_COVERAGE_TRIAGE_PASS report=$reviewed exclusions=$exclusions"
