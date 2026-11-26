#!/usr/bin/env python3
"""Replay the Round 3 directed Product/AXI-Lite URG inputs on new binaries."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import shlex
import subprocess
from pathlib import Path
import run_dsm_v13_round4_urg as r4

ROOT = Path(__file__).resolve().parents[3]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--round3-urg-summary',type=Path,required=True)
    ap.add_argument('--build-run',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args()
    out=args.output.resolve()
    if ROOT/'runs' not in out.parents or out.exists():
        ap.error('output must be a new directory below runs/')
    baseline=json.loads(args.round3_urg_summary.read_text())
    if baseline['status']!='PASS': raise SystemExit('baseline URG did not pass')
    out.mkdir(parents=True)
    result={'schema':'dsm_v13_round5_directed_history_v1','status':'OPEN','cases':[]}
    for config,record in baseline['configurations'].items():
        if config=='mash11_wrapper_core': continue
        for vdb in record['test_vdbs'][:record['directed_test_vdb_count']]:
            vdb=Path(vdb)
            old_log=vdb.parent/(vdb.stem.removeprefix('cov_')+'.log')
            first=old_log.read_text(encoding='utf-8',errors='replace').splitlines()[0]
            if not first.startswith('Command: '): raise SystemExit('missing command '+str(old_log))
            command=shlex.split(first.removeprefix('Command: '))
            test=next((a.split('=',1)[1] for a in command if a.startswith('+UVM_TESTNAME=')),None)
            markers=r4.CASES[config]['positive_markers']
            marker=next((value for name,value in markers.items() if test and name.startswith(test+'_seed')),None)
            if not marker:
                marker=next((value for other in r4.CASES.values()
                             for name,value in other.get('positive_markers', {}).items()
                             if test and name.startswith(test+'_seed')),None)
            negative='illegal_frame' in vdb.name
            if not marker and not negative: raise SystemExit('missing checker marker for '+str(old_log))
            case=out/config/vdb.stem
            case.mkdir(parents=True)
            command[0]=str(args.build_run.resolve()/config/'simv')
            command[command.index('-cm_dir')+1]=str(case/'coverage.vdb')
            command[command.index('-l')+1]=str(case/'simulation.log')
            run=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,check=False)
            log=case/'simulation.log'
            contents=log.read_text(errors='replace') if log.is_file() else ''
            if negative:
                ok=all(m in contents for m in r4.CASES[config]['negative_markers'])
            else:
                ok=(marker in contents and re.search(r'UVM_ERROR\s*:\s*0\b',contents) is not None
                    and re.search(r'UVM_FATAL\s*:\s*0\b',contents) is not None)
            passed=run.returncode==0 and ok and (case/'coverage.vdb').is_dir()
            result['cases'].append({'configuration':config,'source_vdb':str(vdb),'test':test,
                'expected_negative':negative,'status':'PASS' if passed else 'FAIL','returncode':run.returncode,
                'log':str(log),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest() if log.is_file() else None,
                'vdb':str(case/'coverage.vdb'),'command':command})
            (out/'summary.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
            print(config,vdb.name,'PASS' if passed else 'FAIL',flush=True)
            if not passed: raise SystemExit('replay failed: '+str(log))
    result['status']='PASS'
    (out/'summary.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print('historical directed replay PASS cases='+str(len(result['cases'])))

if __name__=='__main__': main()
