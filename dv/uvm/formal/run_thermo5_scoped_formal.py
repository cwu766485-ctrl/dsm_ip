"""Run production-RTL reset/counter proofs with explicit scope and cover gates."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT=Path(__file__).resolve().parents[3]
SOURCES=('rtl/axis/dsm_reset_sync.sv','rtl/dpd/dpd_poly.v','rtl/dpd/dpd_memory_poly.v',
         'rtl/axis/dsm_async_fifo.sv','rtl/axis/dsm_axis14_to_core8_cdc.sv',
         'dv/uvm/formal/thermo5_gap_harness.sv','dv/uvm/formal/run_thermo5_gap_fpv.tcl')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out-dir',required=True)
    ap.add_argument('--unbounded-counter',action='store_true',
                    help='Also prove all 32 counter-bit transitions without a stream budget')
    ap.add_argument('--identity-and-residual',action='store_true',
                    help='Also prove identity arithmetic/latency and generic CDC residual legality')
    ap.add_argument('--residual-only',action='store_true',
                    help='Add the residual proof without the optional expensive arithmetic proof')
    ap.add_argument('--jobs',nargs='+',choices=('reset','counter','counter_unbounded','identity','cdc_residual'),
                    help='Run selected existing jobs for focused diagnosis')
    args=ap.parse_args(); out=Path(args.out_dir).resolve()
    if ROOT/'runs' not in out.parents or out.exists(): ap.error('Use a new runs/ directory')
    out.mkdir(parents=True)
    hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in SOURCES}
    result={'status':'FAIL','source_sha256':hashes,'jobs':[],'errors':[],
            'scope':{'reset':'runtime reset changes only on falling edge; active-edge collisions excluded',
                     'counter':'MAX_TAPS=1 identity; at most 2072 accepted inputs per reset epoch'}}
    kinds=('reset','counter','counter_unbounded') if args.unbounded_counter else ('reset','counter')
    if args.identity_and_residual:
        kinds+=('identity','cdc_residual')
        result['scope']['identity']='MAX_TAPS=1, USE_EXTERNAL_TAPS=1, identity; arbitrary signed payload and legal stalls'
        result['scope']['cdc_residual']='production generic FIFO CDC; separate clocks; constructed registered legal AXIS source; no runtime assumptions on DUT state'
    elif args.residual_only:
        kinds+=('cdc_residual',)
        result['scope']['cdc_residual']='production generic FIFO CDC; separate clocks; constructed registered legal AXIS source; no runtime assumptions on DUT state'
    if args.jobs:
        kinds=tuple(dict.fromkeys(args.jobs))
        if 'cdc_residual' in kinds:
            result['scope']['cdc_residual']='production generic FIFO CDC; exact 7:4 scaled clock periods; constructed registered legal AXIS source; no runtime assumptions on DUT state'
    if args.unbounded_counter:
        result['scope']['counter_unbounded']='MAX_TAPS=1 identity; no acceptance budget; transition proofs do not imply URG hits'
    for kind in kinds:
        top=f'thermo5_{kind}_harness' if kind in ('counter_unbounded','identity','cdc_residual') else f'thermo5_{kind}_gap_harness'
        work=out/kind; work.mkdir()
        env=os.environ.copy()
        env.update(THERMO5_FORMAL_TOP=top,THERMO5_FORMAL_OUT=str(work),THERMO5_FORMAL_REPO=str(ROOT))
        argv=['vcf','-batch','-fmode','FPV','-f',str(ROOT/'dv/uvm/formal/run_thermo5_gap_fpv.tcl')]
        started=time.monotonic(); log=work/'console.log'
        try:
            with log.open('w') as stream:
                code=subprocess.run(argv,cwd=work,env=env,stdout=stream,stderr=subprocess.STDOUT,
                                    timeout=420).returncode
            setup=(work/'setup.txt').read_text()
            properties=(work/'properties.txt').read_text()
            assertions=re.findall(r'^\s*\[\s*\d+\]\s+(\w+)\s+.*? -\s+(\S*\.a_\S+)',properties,re.M)
            covers=re.findall(r'^\s*\[\s*\d+\]\s+(covered|uncoverable|inconclusive|undetermined|unprocessed)\s+.*? -\s+(\S*\.c_\S+)',properties,re.M)
            expected_covers=5 if kind=='reset' else 9 if kind=='cdc_residual' else 4
            expected_assertions=35 if kind=='counter_unbounded' else 5 if kind=='identity' else 7 if kind=='cdc_residual' else 3
            ok=code==0 and len(assertions)==expected_assertions and all(s=='proven' for s,n in assertions)
            ok=ok and len(covers)==expected_covers and all(
                s==('uncoverable' if n.endswith('.c_collision_bin') else 'covered') for s,n in covers)
            ok=ok and not re.search(r':\s+[1-9]\d*\s*$',setup,re.M)
            banner=log.read_text()
            blackboxes=re.findall(r'Number of Black-Box Instances\s*=\s*(\d+)',banner)
            ok=ok and bool(blackboxes) and all(int(x)==0 for x in blackboxes)
            if kind=='reset':
                ok=ok and bool(re.search(r'# non_vacuous\s*:\s*3\b',properties))
            else:
                if kind=='counter_unbounded':
                    ok=ok and bool(re.search(r'# non_vacuous\s*:\s*35\b',properties))
                    ok=ok and bool(re.search(r'constrained\s+\(non_vacuous\).*\.asm_payload_stable',properties))
                elif kind=='counter':
                    ok=ok and bool(re.search(r'# non_vacuous\s*:\s*2\b',properties))
                elif kind=='cdc_residual':
                    ok=ok and bool(re.search(r'proven\s+\(non_vacuous\).*\.a_axis_stable',properties))
                else:
                    ok=ok and bool(re.search(r'constrained\s+\(non_vacuous\).*\.asm_payload_stable',properties))
            result['jobs'].append({'kind':kind,'top':top,'status':'PASS' if ok else 'FAIL',
                'argv':argv,'exit_code':code,'duration_seconds':round(time.monotonic()-started,2),
                'assertions':assertions,'covers':covers,'log':str(log),
                'setup':str(work/'setup.txt'),'properties':str(work/'properties.txt'),
                'black_box_instances':blackboxes,
                'tool_banner':next((x.strip() for x in log.read_text().splitlines() if 'Version V-' in x),'UNKNOWN')})
            if not ok: result['errors'].append(f'{kind}: assertion/cover/vacuity/setup gate failed')
        except Exception as exc:
            result['errors'].append(f'{kind}: {exc}')
    if not result['errors'] and len(result['jobs'])==len(kinds): result['status']='PASS'
    (out/'formal_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'errors':result['errors'],'manifest':str(out/'formal_summary.json')}))
    return 0 if result['status']=='PASS' else 1

if __name__=='__main__': raise SystemExit(main())
