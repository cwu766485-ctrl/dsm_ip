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
    comparisons = []
    for phase, arch, planes in ((0, 1, 4), (1, 2, 2), (2, 0, 4)):
        for plane in range(planes):
            name = f'phase{phase}_arch{arch}_pa{plane}.mem'
            reference, candidate = digest(a.reference / name), digest(a.candidate / name)
            comparisons.append({'file': name, 'reference_sha256': reference,
                                'candidate_sha256': candidate, 'equal': reference == candidate})
    a.out.write_text(json.dumps(comparisons, indent=2) + '\n')
    if not all(row['equal'] for row in comparisons):
        raise SystemExit('QAM PA captures differ')
    print(f'QAM_ACTIVE_PA_SHA256_PASS planes={len(comparisons)}')


if __name__ == '__main__':
    main()
