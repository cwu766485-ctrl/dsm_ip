#!/usr/bin/env python3
"""Fixed-seed full-chain RTL QAM regression using captured weighted PA words."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--seeds',default='281001,281003,281007,281009')
    p.add_argument('--symbols',type=int,default=32)
    args=p.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    root=Path(__file__).resolve().parents[3];model=Path(__file__).resolve().parent
    env=dict(os.environ,PYTHONPATH=str(root/'dv/uvm/refmodel/python'),PYTHONDONTWRITEBYTECODE='1')
    summary={'symbols_per_seed':args.symbols,'rms_drive':.09,'runs':[]}
    for seed in map(int,args.seeds.split(',')):
        source=out/('source_'+str(seed));capture=out/('capture_'+str(seed))
        commands=[
            [sys.executable,str(model/'thermo5_mash_axis_qam.py'),'prepare','--run-dir',str(source),'--seed',str(seed),'--symbols',str(args.symbols),'--rms-drive','0.09'],
            [sys.executable,str(model/'run_mash_capture.py'),'--input-run',str(source),'--output',str(capture),'--correct-residue'],
            [sys.executable,str(model/'thermo5_mash_axis_qam.py'),'evaluate','--run-dir',str(capture),'--seed',str(seed),'--symbols',str(args.symbols),'--rms-drive','0.09'],
        ]
        for index,command in enumerate(commands):
            with (out/('%d_%d.log'%(seed,index))).open('w') as log:
                result=subprocess.run(command,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
            if result.returncode:raise SystemExit('Regression failed: '+str(out/('%d_%d.log'%(seed,index))))
        metric=json.loads((capture/'qam256_rtl_capture_metrics.json').read_text())
        summary['runs'].append({'seed':seed,'evm_percent':metric['evm_percent'],
            'sndr_db':metric['sndr_db'],'bit_errors':metric['bit_errors'],'bits':metric['bits_compared'],
            'status':metric['digital_qam_gate'],'capture':str(capture),'commands':commands})
        summary['total_bits']=sum(r['bits'] for r in summary['runs'])
        summary['total_bit_errors']=sum(r['bit_errors'] for r in summary['runs'])
        summary['aggregate_ber']=summary['total_bit_errors']/summary['total_bits']
        (out/'regression_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps(summary['runs'][-1]),flush=True)


if __name__=='__main__':main()
