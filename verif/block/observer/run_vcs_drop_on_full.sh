#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DSM_VCS_INTERACTIVE_ENV:-}" ]]; then
  export DSM_VCS_INTERACTIVE_ENV=1
  exec bash -ic 'exec "$@"' bash "$0" "$@"
fi

repo="$(cd "$(dirname "$0")/../../.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/dsm_observer_drop.XXXXXX")"
trap 'rm -rf "$work"' EXIT

cd "$repo"
vcs -full64 -sverilog \
  rtl/dpd/dpd_observer_async_bridge.v \
  verif/block/observer/tb/tb_dpd_observer_async_bridge_drop.sv \
  -o "$work/simv" -l "$work/compile.log"
"$work/simv" -no_save -l "$work/run.log"
grep -q 'DPD_ASYNC_BRIDGE_DROP_PASS' "$work/run.log"
cat "$work/run.log"
