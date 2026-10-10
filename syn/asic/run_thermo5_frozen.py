"""Run mapped frozen thermo5 DC and actual RTL/netlist Formality with provenance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out-dir',type=Path,required=True)
    ap.add_argument('--db',type=Path,default=os.environ.get('DSM_ASIC_STDCELL_DB'))
    ap.add_argument('--equivalence-only',action='store_true')
    ap.add_argument('--mapped-run',type=Path,
                    help='Existing mapped DC run; equivalence outputs use a new --out-dir')
    args=ap.parse_args();out=args.out_dir.resolve()
    if not args.db or not args.db.is_file():ap.error('Provide permitted standard-cell --db')
    if ROOT/'runs' not in out.parents:ap.error('Output must be below runs/')
    if args.mapped_run and not args.equivalence_only:ap.error('--mapped-run requires --equivalence-only')
    if out.exists() and (not args.equivalence_only or args.mapped_run):ap.error('Use new run directory')
    mapped=args.mapped_run.resolve() if args.mapped_run else out
    if args.equivalence_only:
        if ROOT/'runs' not in mapped.parents:ap.error('Mapped input must be below runs/')
        if not (mapped/'netlist/thermo5_frozen_asic_syn.v').is_file() or not (mapped/'synthesis.svf').is_file():
            ap.error('Mapped netlist and synthesis SVF must exist')
    out.mkdir(parents=True,exist_ok=True)
    files=[ROOT/p for p in (ROOT/'syn/asic/thermo_frontend_dc_sources.f').read_text().splitlines() if p.strip()]
    files += [ROOT/'syn/rtl/thermo5_frozen_asic.sv',ROOT/'syn/asic/thermo5_frozen.sdc',ROOT/'syn/asic/dc_thermo5_frozen.tcl',ROOT/'syn/asic/fm_thermo5_frozen.tcl']
    digest=lambda: {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    before=digest();env=os.environ.copy();env.update(DSM_ASIC_STDCELL_DB=str(args.db.resolve()),DSM_ASIC_RUN_DIR=str(out))
    env['DSM_ASIC_MAPPED_RUN_DIR']=str(mapped)
    library_hash=hashlib.sha256(args.db.read_bytes()).hexdigest()
    artifacts={}
    if args.equivalence_only:
        original=mapped/'flow_manifest_mapping_initial.json'
        if not original.is_file():original=mapped/'flow_manifest.json'
        provenance=json.loads(original.read_text())
        if not any(j['status']=='PASS' and j['argv'][0]=='dc_shell' for j in provenance['jobs']):
            ap.error('Mapped input requires an actual DC PASS manifest')
        for p,h in before.items():
            if p.startswith('rtl/') or p.startswith('syn/rtl/') or p.endswith('.sdc'):
                if provenance['source_sha256'].get(p)!=h:ap.error('Source differs from mapping: '+p)
        if provenance['library_sha256']!=library_hash:ap.error('Library differs from mapping')
        for rel in ('netlist/thermo5_frozen_asic_syn.v','synthesis.svf'):
            artifacts[rel]=hashlib.sha256((mapped/rel).read_bytes()).hexdigest()
    jobs=[('fm_shell','fm_thermo5_frozen.tcl','THERMO5_RTL_NETLIST_EQUIVALENCE_PASS')]
    if not args.equivalence_only:jobs.insert(0,('dc_shell','dc_thermo5_frozen.tcl','THERMO5_FROZEN_MAPPED_COMPLETE'))
    result={'status':'FAIL','source_sha256':before,'library_sha256':library_hash,'jobs':[],
            'mapped_run':str(mapped),'mapped_artifact_sha256':artifacts,
            'scope':'equivalence-only' if args.equivalence_only else 'mapping-and-equivalence'}
    for tool,script,marker in jobs:
        log=out/(tool+'.log');argv=[tool,'-f',str(ROOT/'syn/asic'/script)]
        started=time.time()
        with log.open('w') as f:code=subprocess.run(argv,cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT).returncode
        text=log.read_text(errors='replace');ok=code==0 and marker in text and not any(l.startswith('Error:') for l in text.splitlines())
        result['jobs'].append({'argv':argv,'exit_code':code,'seconds':time.time()-started,'status':'PASS' if ok else 'FAIL','log':str(log),'tool_banner':text[:500]})
        if not ok:break
    result['source_after_sha256']=digest()
    result['mapped_artifacts_unchanged']=all(hashlib.sha256((mapped/rel).read_bytes()).hexdigest()==h
                                           for rel,h in artifacts.items())
    if all(j['status']=='PASS' for j in result['jobs']) and len(result['jobs'])==len(jobs) and digest()==before and result['mapped_artifacts_unchanged']:result['status']='PASS'
    (out/'flow_manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'manifest':str(out/'flow_manifest.json')}))
    return 0 if result['status']=='PASS' else 1

if __name__=='__main__':raise SystemExit(main())
