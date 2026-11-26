#!/usr/bin/env python3
"""Audit the frozen Round 4 module reports without inventing instance bins."""
from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASELINE = ROOT / 'docs/verification/data/dsm-v13-round4/round4_raw_open_rtl_bins.csv'
OUT = ROOT / 'docs/verification/data/dsm-v13-round5'
spec = importlib.util.spec_from_file_location('round2_parser', ROOT / 'dv/uvm/sim/generate_dsm_v13_round2_evidence.py')
r2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r2)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, rows):
    with path.open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def metadata(page):
    source = page.read_text(encoding='utf-8', errors='replace')
    title = re.search(r'<title>Unified Coverage Report :: Module :: ([^<]+)</title>', source)
    if not title:
        raise ValueError('missing URG module title: ' + str(page))
    instances = []
    rows = r2.read_rows(page)
    for row in rows:
        if not row or not row[0]['links']:
            continue
        for link in row[0]['links']:
            if re.fullmatch(r'mod\d+(?:_\d+)?\.html#inst_tag_\d+', link):
                cells = r2.text_cells(row)
                if len(cells) == 8:
                    instances.append((cells, link))
    if not instances:
        raise ValueError('missing module instance table: ' + str(page))
    return title.group(1), instances


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--round4-run', type=Path, required=True)
    args = ap.parse_args()
    report_root = args.round4_run.resolve()
    rows = list(csv.DictReader(BASELINE.open(newline='', encoding='utf-8')))
    if len(rows) != 2463:
        raise SystemExit('Round 4 inventory count differs from frozen 2463 rows')
    reports = {}
    inventory = []
    instances = []
    for index, row in enumerate(rows, 1):
        ref = row['evidence'].split('#', 1)[0]
        match = re.search(r'/urg/([^/]+)/(mod\d+\.html)$', ref)
        if not match:
            raise SystemExit('unrecognized evidence path: ' + ref)
        config, page_name = match.groups()
        key = (config, page_name)
        if key not in reports:
            page = report_root / 'urg' / config / page_name
            module, inst = metadata(page)
            reports[key] = (module, inst, sha(page))
            for cells, link in inst:
                instances.append({'configuration': row['configuration'], 'module': module,
                    'instance': cells[0], 'score_percent': cells[1], 'line_percent': cells[2],
                    'condition_percent': cells[3], 'toggle_percent': cells[4], 'fsm_percent': cells[5],
                    'branch_percent': cells[6], 'assertion_percent': cells[7],
                    'evidence': f'urg/{config}/{link}', 'report_sha256': reports[key][2],
                    'scope': 'URG instance percentage; no instance-level bin extraction claimed'})
        module, inst, page_hash = reports[key]
        identity = [row['configuration'], module, row['coverage_type'], row['source_location'],
                    row['rtl_expression'], row['uncovered_bin'], page_name]
        inventory.append({'baseline_row': index, 'configuration': row['configuration'],
            'module': module, 'source_location': row['source_location'],
            'coverage_type': row['coverage_type'], 'rtl_expression': row['rtl_expression'],
            'uncovered_detail': row['uncovered_bin'], 'legacy_coverage_id': row['coverage_id'],
            'definition_fingerprint': hashlib.sha256(json.dumps(identity, ensure_ascii=True).encode()).hexdigest(),
            'module_instance_count': len(inst), 'scope': 'MODULE_PAGE_ORIGIN_UNVERIFIED',
            'instance_bin_status': 'OPEN_NOT_EXTRACTED', 'native_bin_id': '',
            'report': f'urg/{config}/{page_name}', 'report_sha256': page_hash})
    fingerprints = Counter(row['definition_fingerprint'] for row in inventory)
    legacy = Counter((row['configuration'], row['legacy_coverage_id']) for row in inventory)
    OUT.mkdir(parents=True, exist_ok=True)
    write(OUT / 'round5_baseline_definition_inventory.csv', inventory)
    write(OUT / 'round5_baseline_instance_percentages.csv', instances)
    summary = {'schema': 'dsm_v13_round5_baseline_audit_v1', 'status': 'OPEN',
        'baseline_commit': '2d2364f575d15bd2a3dafed4d45473db8cabbff1',
        'baseline_inventory_sha256': sha(BASELINE), 'baseline_records': len(inventory),
        'definition_duplicate_fingerprints': sum(n-1 for n in fingerprints.values() if n>1),
        'legacy_id_colliding_records': sum(n for n in legacy.values() if n>1),
        'module_pages': len(reports), 'reported_instances': len(instances),
        'module_record_counts': dict(Counter(row['module'] for row in inventory)),
        'type_record_counts': dict(Counter(row['coverage_type'] for row in inventory)),
        'warning': 'Module-page records are not native exact instance bins; denominator reconciliation, parameters, native identities and history non-regression remain OPEN.',
        'adjusted_code_closure': False, 'approved_code_exclusions': 0}
    (OUT / 'round5_baseline_audit.json').write_text(json.dumps(summary, indent=2, sort_keys=True)+'\n', encoding='utf-8')
    print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
