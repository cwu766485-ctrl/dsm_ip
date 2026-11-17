#!/usr/bin/env python3
"""Read the existing Runtime run after its driver finishes; never alter its artifacts."""
import csv
import hashlib
import json
from pathlib import Path
import re
import sys
import time

root = Path(__file__).resolve().parents[2]
run = root / 'runs/vcu118_ppa_research_01/runtime'
driver = root / 'runs/vcu118_ppa_research_01_driver.log'
out = Path(sys.argv[1]).resolve()
if root / 'runs' not in out.parents:
    raise ValueError('output must be below this worktree runs/')
out.mkdir(parents=True, exist_ok=False)
while True:
    lines = driver.read_text(errors='replace').splitlines()
    result = next((m for line in lines if (m := re.fullmatch(r'CASE runtime EXIT (-?\d+)', line))), None)
    if result:
        break
    time.sleep(30)
status = int(result.group(1))
result_json = {'driver_exit': status, 'scope': 'OOC frontend product proxy; not physical Full Top or GTY signoff', 'status': 'BLOCKED'}
if status == 0:
    timing = (run / 'routed_timing_summary.rpt').read_text(errors='replace')
    util = (run / 'routed_utilization.rpt').read_text(errors='replace')
    power = (run / 'power_default_activity.rpt').read_text(errors='replace')
    paths = (run / 'setup_worst20.rpt').read_text(errors='replace')
    overall = re.search(r'WNS\(ns\).*?\n\s*-+(?:\s+-+)+\s*\n\s*([-\d.]+)\s+([-\d.]+)\s+\d+\s+\d+\s+([-\d.]+)\s+([-\d.]+)', timing, re.S)
    if not overall:
        raise ValueError('cannot parse routed timing summary')
    for key, value in zip(('setup_wns_ns', 'setup_tns_ns', 'hold_wns_ns', 'hold_tns_ns'), overall.groups()):
        result_json[key] = float(value)
    for label, key in [('CLB LUTs', 'lut'), ('CLB Registers', 'ff'), ('DSPs', 'dsp'), ('Block RAM Tile', 'bram_tiles')]:
        m = re.search(r'^\|\s*' + re.escape(label) + r'\s*\|\s*([\d.]+)', util, re.M)
        if not m:
            raise ValueError('cannot parse utilization ' + label)
        result_json[key] = float(m.group(1))
    result_json['power_w'] = float(re.search(r'Total On-Chip Power \(W\)\s*\|\s*([\d.]+)', power).group(1))
    for label, key in [('Source', 'worst_source'), ('Destination', 'worst_destination')]:
        result_json[key] = re.search(r'^\s*' + label + r':\s*(.+)$', paths, re.M).group(1).strip()
    result_json['status'] = 'FAIL' if result_json['setup_wns_ns'] < 0 or result_json['hold_wns_ns'] < 0 else 'BLOCKED'
    result_json['notes'] = 'OOC route only; CDC and physical clock/port constraints require review; vectorless power'
    names = ['routed.dcp', 'routed_timing_summary.rpt', 'routed_utilization.rpt', 'power_default_activity.rpt', 'setup_worst20.rpt', 'hold_worst20.rpt']
    result_json['sha256'] = {n: hashlib.sha256((run / n).read_bytes()).hexdigest() for n in names}
(out / 'summary.json').write_text(json.dumps(result_json, indent=2) + '\n')
flat = {k: v for k, v in result_json.items() if not isinstance(v, dict)}
with (out / 'summary.csv').open('x', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=list(flat))
    writer.writeheader()
    writer.writerow(flat)
print(json.dumps(result_json, indent=2), flush=True)
