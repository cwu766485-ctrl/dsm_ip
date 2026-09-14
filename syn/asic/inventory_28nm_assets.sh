#!/usr/bin/env bash
set -euo pipefail

# Read-only inventory. No PDK file is copied or modified.
ROOT=${1:-/home/ray/ic/CIMForge}
OUT=${2:-"$PWD/syn/reports/28nm_asset_inventory_$(date +%Y%m%d_%H%M%S).txt"}
mkdir -p "$(dirname "$OUT")"
{
  echo "root=$ROOT"
  echo "generated=$(date -Is)"
  echo
  echo "[logic and timing databases]"
  find "$ROOT" -type f \( -iname '*.db' -o -iname '*.lib' -o -iname '*.db.gz' -o -iname '*.lib.gz' \) -printf '%p\t%s bytes\n' 2>/dev/null | sort
  echo
  echo "[physical views]"
  find "$ROOT" -type f \( -iname '*.lef' -o -iname '*.lef.gz' -o -iname '*.tf' -o -iname '*.tluplus' -o -iname '*.itf' -o -iname 'qrcTech*' \) -printf '%p\t%s bytes\n' 2>/dev/null | sort
  echo
  echo "[memory and macro candidates]"
  find "$ROOT" -type f \( -iname '*sram*' -o -iname '*rom*' -o -iname '*ram*' -o -iname '*macro*' -o -iname '*mem*' \) -printf '%p\t%s bytes\n' 2>/dev/null | sort
  echo
  echo "[library-name hints]"
  find "$ROOT" -type f \( -iname '*.db' -o -iname '*.lib' -o -iname '*.lef' \) -printf '%f\n' 2>/dev/null | grep -Ei '28|hpc|bwp|logic|std|sc|sram|rom|ram|macro|memory|io|pad|lv|iso' | sort -u || true
} | tee "$OUT"
echo "INVENTORY_OUTPUT=$OUT"
