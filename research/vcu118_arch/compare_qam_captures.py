#!/usr/bin/env python3
"""Compare the active PA planes of three full-chain runtime captures."""
import argparse
import hashlib
import json
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference', type=Path, required=True)
    p.add_argument('--candidate', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    if a.out.exists():
        raise FileExistsError(a.out)
    reference_files = {p.name for p in a.reference.glob('phase*_pa*.mem')}
    candidate_files = {p.name for p in a.candidate.glob('phase*_pa*.mem')}
    if not reference_files or reference_files != candidate_files:
        raise ValueError('Capture file sets are empty or differ')
    comparisons = []
    for name in sorted(reference_files):
        reference, candidate = digest(a.reference / name), digest(a.candidate / name)
        comparisons.append({'file': name, 'reference_sha256': reference,
                            'candidate_sha256': candidate, 'equal': reference == candidate})
    a.out.write_text(json.dumps(comparisons, indent=2) + '\n')
    if not all(row['equal'] for row in comparisons):
        raise SystemExit('QAM PA captures differ')
    print(f'QAM_ALL_PHASE_PA_SHA256_PASS files={len(comparisons)}')


if __name__ == '__main__':
    main()
