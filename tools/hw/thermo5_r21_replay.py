#!/usr/bin/env python3.12
"""Rebuild inherited R20 coverage with one current executable; never add seeds.

Read original simulator argv from native siminfo.xml. Preserve input vectors,
scenario arguments and seeds; replace only executable and output destinations.
Expected-negative assertion runs remain separate from legal-only coverage.
"""
import argparse
import concurrent.futures
import gzip
import hashlib
import json
import re
import shlex
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def command_from_vdb(path):
    files=list(path.glob('snps/coverage/db/testdata/*/siminfo.xml'))
    if len(files)!=1: raise ValueError(f'Expected one test siminfo: {path}')
    raw=files[0].read_bytes()
    if raw.startswith(b'\x1f\x8b'): raw=gzip.decompress(raw)
    test=ET.fromstring(raw).find('srctest')
    return shlex.split(test.attrib['cmdline']), Path(test.attrib['workdir'])

def inherited_vdbs(latest,round20):
    data=json.loads((latest/'runs/thermo5_r17_precise_exclusion_20261109_raw_retry2/input_vdb_manifest.json').read_text())
    paths=[Path(x['path']) for x in data['tests']]
    supplement=json.loads((latest/'runs/thermo5_r17_final_residual_20261109_run5/supplemental_manifest.json').read_text())
    paths.extend(Path(x['path']) for x in supplement['supplemental_vdbs'])
    r18=json.loads((latest/'runs/thermo5_r18_counter_20261109_06/urg/thermo5_tx_r18_coverage_manifest.json').read_text())
    paths.append(Path(r18['new_test_vdb']['path']))
    r20=json.loads((ROOT/'docs/verification/data/thermo5-r20/thermo5_tx_r20_vdb_manifest.json').read_text())
    paths.extend(round20/x['artifact'] for x in r20['test_vdbs'][1:])
    if len(paths)!=580:raise ValueError(f'Expected 580 inherited tests, got {len(paths)}')
    return paths

def prepare(path,index,out):
    original, original_workdir=command_from_vdb(path)
    name=next(x.split('=',1)[1] for x in original if x.startswith('+UVM_TESTNAME='))
    negative=name in ('thermo5_sku_axil_illegal_frame_test','thermo5_sku_axil_mailbox_fault_test')
    label=f'{index:03d}_{name}'
    folder=out/('negative' if negative else 'legal')
    folder.mkdir(parents=True,exist_ok=True)
    cmd=[str(ROOT/'runs/product/simv')]
    skip=False
    for arg in original[1:]:
        if skip:skip=False;continue
        if arg in ('-cm_dir','-l'):skip=True;continue
        if arg.startswith('+VEC_DIR=') and not Path(arg.split('=',1)[1]).is_absolute():
            arg='+VEC_DIR='+str((original_workdir/arg.split('=',1)[1]).resolve())
        if arg.startswith('+THERMO5_TRACE_JSONL='):
            arg='+THERMO5_TRACE_JSONL='+str(folder/(label+'.jsonl'))
        cmd.append(arg)
    if '-no_save' not in cmd:cmd.append('-no_save')
    if '-cm' not in cmd:cmd.extend(['-cm','line+cond+fsm+tgl+branch+assert'])
    cmd.extend(['-cm_dir',str(folder/(label+'.vdb')),'-l',str(folder/(label+'.log'))])
    for arg in cmd:
        if arg.startswith('+VEC_DIR=') and not Path(arg.split('=',1)[1]).is_dir():
            raise ValueError('Original vector directory missing: '+arg)
    return dict(index=index,test=name,negative=negative,original_vdb=str(path),
                original_argv=original,argv=cmd,log=str(folder/(label+'.log')),
                vdb=str(folder/(label+'.vdb')))

def execute(record):
    log=Path(record['log']);stdout=log.with_suffix('.stdout')
    try:
        with stdout.open('w') as f:
            code=subprocess.run(record['argv'],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=180).returncode
        text=log.read_text(errors='replace') if log.exists() else stdout.read_text(errors='replace')
        error=re.search(r'UVM_ERROR\s*:\s*(\d+)',text)
        fatal=re.search(r'UVM_FATAL\s*:\s*(\d+)',text)
        assertion_errors=len(re.findall(r'^Error:',text,re.M))
        passed=(code==0 and error and fatal and int(error[1])==0 and int(fatal[1])==0
                and 'TEST_DONE' in text and '[SKU_PASS]' in text)
        if not record['negative'] and assertion_errors:passed=False
        return dict(**record,exit_code=code,status='PASS' if passed else 'FAIL',
                    assertion_error_messages=assertion_errors,
                    log_sha256=hashlib.sha256(log.read_bytes()).hexdigest() if log.exists() else None)
    except Exception as exc:
        return dict(**record,status='FAIL',error=str(exc))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--latest',type=Path,required=True)
    p.add_argument('--round20',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--execute',action='store_true')
    p.add_argument('--workers',type=int,default=2)
    args=p.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    records=[prepare(path,i,out) for i,path in enumerate(inherited_vdbs(args.latest,args.round20))]
    (out/'plan.json').write_text(json.dumps(records,indent=2)+'\n')
    print(f'REPLAY_PLAN tests={len(records)} new_seeds=0',flush=True)
    if args.execute:
        results=[]
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            for r in pool.map(execute,records):
                results.append(r)
                if len(results)%25==0 or r['status']!='PASS':
                    print(f"REPLAY {len(results)}/{len(records)} {r['status']} {r['test']}",flush=True)
                (out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
        failed=sum(r['status']!='PASS' for r in results)
        print(f'REPLAY_COMPLETE tests={len(results)} failures={failed}',flush=True)
        raise SystemExit(bool(failed))
