"""One command: same-build coverage, scoped formal, real bugs, normalized evidence."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time

import run_thermo5_frozen_regression as frozen

ROOT=frozen.ROOT

def failures(root):
    """Normalize checker/assertion diagnostics; identify expected negative controls."""
    records=[]
    for path in root.rglob('*.log'):
        if any(x in path.parts for x in ('csrc','simv.daidir')): continue
        log_text=path.read_text(errors='replace')
        text_lines=log_text.splitlines()
        for number,line in enumerate(text_lines,1):
            if re.search(r'^(?:UVM_ERROR|UVM_FATAL)\b.*\[|^Error:|^Fatal:|^Error-\[|^Warning-\[|^Error-[A-Z]|BUG_(?:STALE_REJECTION|RESET_COMPLETION)|DSM frame_start was not aligned',line):
                nearby='\n'.join(text_lines[max(0,number-2):number+2])
                expected=(frozen.EXPECTED_ASSERTION in nearby and
                    ('illegal_frame' in path.name or 'seven_case_regression' in path.name)) or (
                    'bugs' in path.parts and any(x in path.parts for x in ('stale_reject','reset_completion'))
                    and any(x in nearby for x in ('BUG_STALE_REJECTION','BUG_RESET_COMPLETION')))
                records.append({'log':str(path.relative_to(root)),'line':number,
                    'category':'EXPECTED_NEGATIVE_CONTROL' if expected else
                    'COMPILE_WARNING' if line.startswith('Warning-[') else 'CHECKER_OR_ASSERTION',
                    'message':line})
    return records

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out-dir',required=True)
    ap.add_argument('--xpm-root',required=True)
    ap.add_argument('--range-vectors',required=True)
    ap.add_argument('--range-words',type=int,default=2072)
    ap.add_argument('--gain-vectors',type=Path)
    ap.add_argument('--unbounded-counter',action='store_true')
    ap.add_argument('--residual-only',action='store_true')
    ap.add_argument('--endpoint-vectors',default=str(ROOT/'runs/uvm_thermo5_extreme_20261003'))
    ap.add_argument('--dry-run',action='store_true')
    args=ap.parse_args(); out=Path(args.out_dir).resolve()
    if ROOT/'runs' not in out.parents or out.exists(): ap.error('Use a new runs/ directory')
    out.mkdir(parents=True)
    start=frozen.source_state()
    jobs=[('coverage',[sys.executable,str(ROOT/'dv/uvm/sim/run_thermo5_gap_closure.py'),
            '--out-dir',str(out/'coverage'),'--xpm-root',args.xpm_root,
            '--range-vectors',args.range_vectors,'--range-words',str(args.range_words),
            '--endpoint-vectors',args.endpoint_vectors]),
          ('formal',[sys.executable,str(ROOT/'dv/uvm/formal/run_thermo5_scoped_formal.py'),
            '--out-dir',str(out/'formal')]),
          ('bugs',[sys.executable,str(ROOT/'dv/uvm/sim/run_commit_bug_repro.py'),
            '--simulator','vcs','--out-dir',str(out/'bugs')])]
    if args.gain_vectors: jobs[0][1].extend(['--gain-vectors',str(args.gain_vectors)])
    if args.unbounded_counter: jobs[1][1].append('--unbounded-counter')
    if args.residual_only: jobs[1][1].append('--residual-only')
    result={'created_utc':frozen.now(),'status':'DRY_RUN' if args.dry_run else 'FAIL',
            'source':start,'jobs':[],'errors':[],
            'scope':'frozen thermo5 digital DV; raw URG and scoped formal kept separate'}
    for name,argv in jobs:
        record={'name':name,'argv':argv,'status':'PLANNED'}
        if not args.dry_run:
            run=frozen.execute(argv,ROOT,out/(name+'_launcher.log'),False)
            record.update(run);record['status']='PASS' if run['exit_code']==0 else 'FAIL'
            if run['exit_code']: result['errors'].append(f'{name} failed; see {run["log"]}')
        result['jobs'].append(record)
    result['source_after']=frozen.source_state()
    if result['source_after']['rtl_dv_source_sha256']!=start['rtl_dv_source_sha256']:
        result['errors'].append('RTL/DV source digest changed during package run')
    diagnostics=failures(out)
    unexpected=[x for x in diagnostics if x['category']=='CHECKER_OR_ASSERTION']
    if unexpected: result['errors'].append(f'{len(unexpected)} unexpected checker/assertion diagnostics')
    (out/'diagnostics.json').write_text(json.dumps(diagnostics,indent=2)+'\n')
    result['diagnostics']=str(out/'diagnostics.json')
    if not args.dry_run and not result['errors']: result['status']='PASS'
    (out/'dv_package.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'errors':result['errors'],'manifest':str(out/'dv_package.json')}))
    return 0 if not result['errors'] else 1

if __name__=='__main__': raise SystemExit(main())
