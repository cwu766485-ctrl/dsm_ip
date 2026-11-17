#!/usr/bin/env bash
# Guard an already-suspended Runtime run, avoiding concurrent orphaned Vivado.
set -u
if [[ $# -ne 2 || "$1" != runs/* ]]; then echo 'usage: watch_ef1_runtime_resume.sh runs/QUEUE TARGET_PID' >&2; exit 2; fi
queue="$1";target="$2"
while [[ ! -f "$queue/pid" || ! -f "$queue/control.ps1" ]]; do sleep 1; done
printf 'ready\n' > "$queue/watchdog_ready_02"
controller=$(cat "$queue/pid")
while kill -0 "$controller" 2>/dev/null; do sleep 10; done
if [[ ! -f "$queue/done" ]]; then
 while powershell.exe -NoProfile -Command '$p=Get-CimInstance Win32_Process | Where-Object {$_.Name -eq "vivado.exe" -and $_.CommandLine -like "*ef1_cdc_candidate_preempt_03*"}; if($p){exit 0}else{exit 1}' >/dev/null 2>&1; do sleep 10; done
 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$PWD/$queue/control.ps1")" resume "$target" > "$queue/watchdog_resume_02.log" 2>&1
fi
