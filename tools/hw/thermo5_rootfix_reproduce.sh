#!/usr/bin/env bash
# Run from an isolated checkout; outputs below ignored runs/.
set -euo pipefail
: "${PYTHON:?Python 3.12 with reference model dependencies}"
: "${SPYGLASS_BIN:?path to sg_shell}"
: "${VCF_BIN:?path to vcf}"
root=$(git rev-parse --show-toplevel)
cd "$root"
out="$root/runs/cdc_rootfix_replay"
mkdir -p "$out"
"$PYTHON" tools/hw/thermo5_rdc_rootcause_audit.py docs/verification/data/thermo5-cdc-phase2/static_messages.csv.gz --out-dir "$out/baseline"
for pair in setup:cdc/cdc_setup_check cdc:cdc/cdc_verify_struct verify:cdc/cdc_verify rdc:rdc/rdc_verify_struct; do
 name=${pair%%:*};goal=${pair#*:};mkdir -p "$out/$name"
 THERMO5_STATIC_ROOT="$root" THERMO5_STATIC_OUT="$out/$name" THERMO5_STATIC_GOAL="$goal" "$SPYGLASS_BIN" -tcl dv/uvm/static/run_thermo5_axil_cdc.tcl > "$out/$name/console.log" 2>&1
done
"$PYTHON" tools/hw/thermo5_rootfix_reconcile.py --runs "$out" --out "$out/reconciled"
for proof in cdc_source_status rdc_fifo_epoch rdc_dpd_epoch rdc_async_epoch; do
 mkdir -p "$out/$proof"
 (cd "$out/$proof"; THERMO5_FORMAL_REPO="$root" THERMO5_FORMAL_OUT="$out/$proof" "$VCF_BIN" -batch -fmode FPV -f "$root/dv/uvm/formal/run_thermo5_$proof.tcl" > console.log 2>&1)
done
# Async epoch proof is bounded and may remain inconclusive; inspect properties.
