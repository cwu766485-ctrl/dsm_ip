#!/usr/bin/env python3
"""Report round-local URG deltas; deliberately fail closed on missing bin audit."""
from __future__ import annotations
import argparse
import csv
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/verification/data/dsm-v13-round5'
spec = importlib.util.spec_from_file_location('round2_parser', ROOT / 'dv/uvm/sim/generate_dsm_v13_round2_evidence.py')
r2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r2)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--baseline-run', type=Path, required=True)
    ap.add_argument('--cumulative-urg', type=Path, required=True)
    ap.add_argument('--history-replay', type=Path, required=True)
    ap.add_argument('--directed-replay', type=Path, required=True)
    args = ap.parse_args()
    baseline = args.baseline_run.resolve()
    cumulative = args.cumulative_urg.resolve()
    history = args.history_replay.resolve()
    merge = json.loads((cumulative / 'summary.json').read_text())
    history_summary = json.loads((history / 'summary.json').read_text())
    directed = args.directed_replay.resolve()
    directed_summary = json.loads((directed / 'summary.json').read_text())
    if merge['status'] != 'PASS' or history_summary['status'] != 'PASS' or directed_summary['status'] != 'PASS':
        raise SystemExit('input runs did not PASS')
    configs = ('ef1_product', 'ef2_product', 'mash11_product', 'ef1_axil', 'ef2_axil', 'mash11_axil')
    rows = []
    decreases = []
    for config in configs:
        old_path = baseline / 'urg' / config / 'hierarchy.html'
        new_path = cumulative / config / 'hierarchy.html'
        old, new = r2.parse_dut_code(old_path), r2.parse_dut_code(new_path)
        for metric in ('line', 'branch', 'cond', 'toggle', 'fsm', 'assert'):
            before, after = old.get(metric), new.get(metric)
            if before is None or after is None:
                raise SystemExit(f'{config}: missing {metric} value')
            delta = float(after)-float(before)
            if delta < -0.005:
                decreases.append(f'{config}/{metric}')
            rows.append({'configuration': config, 'metric': metric, 'round4_percent': before,
                         'cumulative_raw_percent': after, 'delta_percentage_points': f'{delta:+.2f}',
                         'status': 'DECREASE' if delta < -0.005 else 'NO_PERCENT_DECREASE',
                         'round4_hierarchy_sha256': sha(old_path), 'cumulative_hierarchy_sha256': sha(new_path),
                         'note': 'Percentage check only; not a native-bin non-regression proof.'})
    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / 'round5_raw_coverage_progress.csv').open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader(); writer.writerows(rows)
    result = {'schema': 'dsm_v13_round5_progress_v1', 'status': 'OPEN',
              'cumulative_urg': 'PASS', 'round4_replayed_cases': 50,
              'round3_random_replayed_cases': len(history_summary['cases']),
              'round3_directed_replayed_cases': len(directed_summary['cases']),
              'round4_mash_wrapper_core_vdb_reused': True,
              'same_config_vdb_counts': {k: v['round4_vdb_count'] + v['historical_vdb_count'] for k,v in merge['configurations'].items()},
              'percentage_decreases': decreases,
              'exact_hit_set_nonregression': 'OPEN_NO_NATIVE_BIN_IDENTITIES',
              'all_round1_to_round4_cases_replayed': False,
              'code_coverage_100_percent_adjusted': False,
              'final_signoff': False, 'code_exclusions_applied': 0,
              'historical_random_summary_sha256': sha(history / 'summary.json'),
              'historical_directed_summary_sha256': sha(directed / 'summary.json'),
              'cumulative_urg_summary_sha256': sha(cumulative / 'summary.json')}
    (OUT / 'round5_progress_summary.json').write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    print(json.dumps(result, indent=2, sort_keys=True))
    if decreases:
        raise SystemExit('percentage coverage decreased; investigate')

if __name__ == '__main__':
    main()
