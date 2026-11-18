#!/usr/bin/env python3
"""Group reviewed SpyGlass RDC records by hierarchy for triage, never waive."""
import argparse, csv, collections, json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('input',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
with a.input.open(newline='') as f: rows=list(csv.DictReader(f))
counts=collections.Counter();groups=collections.Counter()
for row in rows:
    cone=row['source_hierarchy']+' '+row['destination_hierarchy']
    if 'u_stage1' in cone: key='MASH stage1 related'
    elif 'u_interp2_to_tid_fifo' in cone: key='interpolator2 FIFO payload related'
    elif 'u_interp_to_dpd_elastic' in cone: key='interpolator1 elastic payload related'
    elif 'u_async_fifo' in cone: key='async FIFO related'
    elif 'u_cfg' in cone: key='configuration other'
    elif 'u_backend' in cone: key='backend other'
    else: key='other'
    counts[key]+=int(row['count']);groups[key]+=1
if sum(counts.values()) != 45778 or len(rows)!=239: raise SystemExit('unexpected input scope; inspect before classifying')
result={'scope':'Runtime Generic FIFO research reset candidate; hierarchy triage, not root-cause proof or waiver','messages':sum(counts.values()),'groups':len(rows),'categories':[{ 'hierarchy':k,'messages':v,'groups':groups[k], 'disposition':'OPEN_REVIEW'} for k,v in counts.most_common()]}
with a.output.open('x') as f:json.dump(result,f,indent=2);f.write('\n')
print(json.dumps(result,indent=2))
