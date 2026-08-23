#!/usr/bin/env bash
set -euo pipefail

# Merge exactly the passing runs from the extended system-UVM regression.
# Keep the tag extraction in Bash so Windows PowerShell quoting cannot alter
# the AWK expression or silently omit newly added testcases.
if [[ -z "${DSM_VCS_INTERACTIVE_ENV:-}" ]]; then
  export DSM_VCS_INTERACTIVE_ENV=1
  exec bash -ic 'exec "$@"' bash "$0" "$@"
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR/../.."

summary=uvm_verif/sim/out/vcs/ip_extended_regression.csv
if [[ ! -f "$summary" ]]; then
  echo "ERROR: missing $summary; run run_ip_extended_regression_linux.sh first" >&2
  exit 2
fi

tags="$(awk -F, 'NR > 1 && $4 == "PASS" { print $3 }' "$summary" | sort -u | tr '\n' ' ')"
tag_count="$(wc -w <<< "$tags")"
if [[ "$tag_count" -ne 300 ]]; then
  echo "ERROR: expected 300 passing extended-regression tags, found $tag_count" >&2
  exit 2
fi

echo "Merging $tag_count passing VCS coverage databases"
merge_args=("RUN_TAGS=$tags")
if [[ -n "${URG_ELFILE:-}" ]]; then
  merge_args+=("URG_ELFILE=$URG_ELFILE")
fi
make -C uvm_verif/sim coverage-merge "${merge_args[@]}"
