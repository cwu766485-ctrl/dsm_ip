#!/usr/bin/env python3.12
"""Run the source-bound FIFO/Gain composition; retain reports, hashes and scope."""
import argparse, hashlib, json, os, re, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out-dir',type=Path,required=True)
    ap.add_argument('--execute',action='store_true')
    args=ap.parse_args(); out=args.out_dir.resolve()
    if not out.is_relative_to(ROOT/'runs') or out.exists(): ap.error('Use a new directory below runs/')
    tcl=ROOT/'dv/uvm/formal/run_thermo5_gain_fifo_v5.tcl'
    command=['/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf','-batch','-fmode','FPV','-f',str(tcl)]
    if not args.execute: print(json.dumps(command)); return
    out.mkdir(parents=True)
    env=dict(os.environ,THERMO5_FORMAL_REPO=str(ROOT),THERMO5_FORMAL_OUT=str(out))
    sources=['rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv','rtl/frontend/dsm_frame_gain_vector.sv','dv/uvm/formal/thermo5_gain_fifo_v5_harness.sv','dv/uvm/formal/run_thermo5_gain_fifo_v5.tcl']
    result={'command':command,'source_hashes':{p:digest(ROOT/p) for p in sources},'scope':'Reset-initialized clock-sampled procedural operands; arbitrary enable/valid/data/metadata/ready; no legal-input assumption. No all-event continuous-expression claim.'}
    with (out/'vcf.log').open('w') as log:
        try: result['exit_code']=subprocess.run(command,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300).returncode
        except subprocess.TimeoutExpired: result['exit_code']=None; result['timeout']=True
    props=(out/'properties.txt').read_text() if (out/'properties.txt').exists() else ''
    result['assertions']=dict((name,status) for status,name in re.findall(r'^\s*\[\s*\d+\]\s+(proven|falsified|inconclusive)\s+(?:\(non_vacuous\)\s+)?-\s+(\S+)',props,re.M))
    result['properties_sha256']=digest(out/'properties.txt') if props else None
    result['pass']=result.get('exit_code')==0 and len(result['assertions'])==4 and all(v=='proven' for v in result['assertions'].values()) and len(re.findall(r'^\s*\[\s*\d+\]\s+uncoverable\s+-',props,re.M))==2 and len(re.findall(r'^\s*\[\s*\d+\]\s+covered\s+',props,re.M))==3
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2)); raise SystemExit(0 if result['pass'] else 1)
if __name__=='__main__': main()
