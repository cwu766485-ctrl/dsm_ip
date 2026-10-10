"""Parse SpyGlass rows; errors/blackboxes fail, warnings retain review status."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('report', type=Path)
    args = ap.parse_args()
    content = args.report.read_text(errors='replace')
    rows = []
    for line in content.splitlines():
        if not re.match(r'^\[[^]]+\]\s+', line):
            continue
        columns = re.split(r'\s{2,}', line.strip())
        severity = next((s for s in ('Error','Fatal','Warning','Info','SynthesisWarning') if s in columns), 'UNKNOWN')
        rows.append({'id':columns[0], 'rule':columns[1], 'severity':severity, 'raw':line})
    total = re.search(r'Total Number of Generated Messages\s*:\s*(\d+)', content)
    counts = Counter(r['severity'] for r in rows)
    failed = not total or len(rows)!=int(total[1]) or counts['Error'] or counts['Fatal'] or counts['UNKNOWN']
    result = {'status':'FAIL' if failed else 'ERROR_FREE_WARNINGS_REVIEW_REQUIRED',
              'counts':dict(counts), 'waivers_applied':False,
              'report_sha256':hashlib.sha256(args.report.read_bytes()).hexdigest(), 'messages':rows}
    (args.report.parent/'lint_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='messages'}))
    return 1 if failed else 0


if __name__=='__main__': raise SystemExit(main())
