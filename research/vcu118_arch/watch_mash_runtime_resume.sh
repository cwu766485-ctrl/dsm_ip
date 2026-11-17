#!/usr/bin/env bash
# Watch an already-started MASH controller, recovering Runtime only after any
# orphaned candidate Vivado has finished. Run from the research worktree.
set -u
if [[ $# -ne 2 || "$1" != runs/* ]]; then echo 'usage: watch_mash_runtime_resume.sh runs/QUEUE TARGET_PID' >&2; exit 2; fi
queue="$1";target="$2"
while [[ ! -f "$queue/pid" || ! -f "$queue/control.ps1" ]]; do sleep 1; done
printf 'ready\n' > "$queue/watchdog_ready"
controller=$(cat "$queue/pid")
while kill -0 "$controller" 2>/dev/null; do sleep 10; done
if [[ -f "$queue/suspend_attempted" && ! -f "$queue/done" ]]; then
 # Fixed unique queue name used by this run; only that Vivado process counts.
 while powershell.exe -NoProfile -Command '$p=Get-CimInstance Win32_Process | Where-Object {$_.Name -eq "vivado.exe" -and $_.CommandLine -like "*mash_candidates_preempt_02*"}; if($p){exit 0}else{exit 1}' >/dev/null 2>&1; do sleep 10; done
 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$PWD/$queue/control.ps1")" resume "$target" > "$queue/watchdog_resume.log" 2>&1
fi
