#!/usr/bin/env bash
# Run under the Rocky EDA environment; output must be a fresh runs/ directory.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ $# -ne 1 ]]; then echo 'usage: run_ef2_32lane_formal.sh runs/NEW_DIR' >&2; exit 2; fi
case "$1" in runs/*) ;; *) echo 'output must be below runs/' >&2; exit 2;; esac
out="$repo/$1"
mkdir "$out"
export THERMO5_FORMAL_REPO="$repo" THERMO5_FORMAL_OUT="$out"
cd "$out"
exec vcf -batch -fmode FPV -f "$repo/research/vcu118_arch/formal_ef2_32lane.tcl"
