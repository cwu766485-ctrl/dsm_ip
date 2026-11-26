#!/usr/bin/env python3
"""Replay Round 3 random campaigns using Round 5 same-configuration binaries."""
from __future__ import annotations
import argparse
import hashlib
import json
import shlex
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--round3-run', type=Path, required=True)
    parser.add_argument('--build-run', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    base = args.round3_run.resolve()
    builds = args.build_run.resolve()
    out = args.output.resolve()
    if ROOT / 'runs' not in out.parents or out.exists():
        parser.error('output must be a new directory under runs/')
    out.mkdir(parents=True)
    result = {'schema': 'dsm_v13_round5_historical_random_replay_v1', 'status': 'OPEN', 'cases': []}
    manifest = out / 'summary.json'
    for campaign, suffix, marker in (
        ('product_random_matrix_b', 'product', 'DSM_V13_PRODUCT_RANDOM_PASS'),
        ('axil_random', 'axil', 'THERMO5_TX_RANDOM_PACKET_PASS'),
    ):
        source = json.loads((base / campaign / 'regression_summary.json').read_text())
        if source['status'] != 'PASS':
            raise SystemExit('historical campaign summary did not PASS')
        for sku, info in source['sku_results'].items():
            for case in info['campaigns']:
                command = shlex.split(case['commands']['simulate'])
                config = ('mash11' if sku == 'mash11' else sku) + '_' + suffix
                command[0] = str(builds / config / 'simv')
                vectors = Path(next(x.split('=', 1)[1] for x in command if x.startswith('+VEC_DIR=')))
                for name, expected in case['vectors_sha256'].items():
                    if not (vectors / name).is_file() or digest(vectors / name) != expected:
                        raise SystemExit(f'historical vector missing or changed: {vectors / name}')
                case_dir = out / config / f"{campaign}_{case['seed']}"
                case_dir.mkdir(parents=True)
                command[command.index('-cm_dir') + 1] = str(case_dir / 'coverage.vdb')
                command[command.index('-l') + 1] = str(case_dir / 'simulation.log')
                completed = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                           stderr=subprocess.STDOUT, text=True, check=False)
                log = case_dir / 'simulation.log'
                contents = log.read_text(encoding='utf-8', errors='replace') if log.exists() else ''
                expected_marker = ('DSM_V13_PRODUCT_RESET_RANDOM_PASS'
                                   if '+THERMO5_RANDOM_RESET_CASE' in command else marker)
                passed = (completed.returncode == 0 and expected_marker in contents
                          and 'UVM_ERROR :    0' in contents and 'UVM_FATAL :    0' in contents
                          and (case_dir / 'coverage.vdb').is_dir())
                item = {'campaign': campaign, 'configuration': config, 'seed': case['seed'],
                        'status': 'PASS' if passed else 'FAIL', 'returncode': completed.returncode,
                        'log': str(log), 'log_sha256': digest(log) if log.exists() else None,
                        'vdb': str(case_dir / 'coverage.vdb'), 'command': command}
                result['cases'].append(item)
                manifest.write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
                print(f"{config} {campaign} seed={case['seed']} {item['status']}", flush=True)
                if not passed:
                    raise SystemExit('replay failed; see ' + str(log))
    result['status'] = 'PASS'
    manifest.write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    print(f"historical random replay PASS cases={len(result['cases'])}")

if __name__ == '__main__':
    main()
