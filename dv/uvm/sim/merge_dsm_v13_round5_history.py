#!/usr/bin/env python3
"""Merge replayed Round 3 random and Round 4 VDBs per frozen SKU build."""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--round4-replay', type=Path, required=True)
    ap.add_argument('--history-replay', type=Path, required=True)
    ap.add_argument('--directed-replay', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--urg', type=Path, required=True)
    args = ap.parse_args()
    base = args.round4_replay.resolve()
    historical = args.history_replay.resolve()
    output = args.output.resolve()
    if ROOT / 'runs' not in output.parents or output.exists():
        ap.error('output must be a new directory below runs/')
    r4 = json.loads((base / 'round4_urg/summary.json').read_text())
    history = json.loads((historical / 'summary.json').read_text())
    directed = json.loads((args.directed_replay.resolve() / 'summary.json').read_text())
    if (r4['status'] != 'PASS' or history['status'] != 'PASS' or len(history['cases']) != 15
            or directed['status'] != 'PASS' or len(directed['cases']) != 31):
        raise SystemExit('replay inputs incomplete')
    output.mkdir(parents=True)
    result = {'schema': 'dsm_v13_round5_cumulative_urg_v1', 'status': 'OPEN',
              'scope': 'Round 4 replay plus Round 3 directed and random; other historical tests remain OPEN',
              'configurations': {}}
    for config in ('ef1_product', 'ef2_product', 'mash11_product', 'ef1_axil', 'ef2_axil', 'mash11_axil'):
        old = r4['configurations'][config]
        cases = [c for c in history['cases'] + directed['cases'] if c['configuration'] == config]
        if any(c['status'] != 'PASS' or hashlib.sha256(Path(c['log']).read_bytes()).hexdigest()!=c['log_sha256'] for c in cases):
            raise SystemExit('historical case failed or log hash mismatch: ' + config)
        vdbs = list(old['test_vdbs']) + [c['vdb'] for c in cases]
        design = old['design_vdb']
        if not all(Path(v).is_dir() for v in [design, *vdbs]):
            raise SystemExit('missing VDB: ' + config)
        report = output / config
        command = [str(args.urg), '-full64', '-dir', design, *vdbs, '-report', str(report),
                   '-dbname', 'dsm_v13_r5_' + config]
        proc = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, check=False)
        (output / (config + '.log')).write_text(proc.stdout, encoding='utf-8')
        passed = proc.returncode == 0 and (report / 'hierarchy.html').is_file()
        result['configurations'][config] = {'status': 'PASS' if passed else 'FAIL',
            'returncode': proc.returncode, 'round4_vdb_count': len(old['test_vdbs']),
            'historical_vdb_count': len(cases), 'design_vdb': design, 'test_vdbs': vdbs,
            'report': str(report), 'command': command}
        (output / 'summary.json').write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
        print(f'{config}: {"PASS" if passed else "FAIL"} vdbs={len(vdbs)}', flush=True)
        if not passed:
            raise SystemExit('URG merge failed: ' + config)
    result['status'] = 'PASS'
    (output / 'summary.json').write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')

if __name__ == '__main__':
    main()
