#!/usr/bin/env python3.12
"""Run four fixed, purpose-specific P0 scenarios; no seed expansion."""
import argparse,json,subprocess,sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/hw'))
from thermo5_r21_replay import execute

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--execute',action='store_true');p.add_argument('--case',choices=['overlap','long64','long96','reset'],action='append');a=p.parse_args()
 failures=[]
 base=ROOT/'runs/dv_convergence_v3'
 for i,(name,test,words,beats) in enumerate([('overlap','thermo5_sku_axil_p0_overlap_test',112,64),('long64','thermo5_sku_axil_graceful_stop_test',112,64),('long96','thermo5_sku_axil_graceful_stop_test',168,96),('reset','thermo5_sku_axil_p0_reset_test',56,32)]):
  if a.case and name not in a.case:continue
  out=base/name;out.mkdir(exist_ok=True)
  argv=[str(base/'compile/simv'),'+UVM_TESTNAME='+test,'+VEC_DIR='+str(base/'vectors'/name),'+ntb_random_seed=930000','+CORE_WORDS='+str(words),'+PACKET_BEATS='+str(beats),'+THERMO5_TRACE_JSONL='+str(out/'test.jsonl'),'+THERMO5_WITNESS_VCD='+str(out/'test.vcd'),'-cm','line+cond+fsm+tgl+branch+assert','-no_save','-cm_dir',str(out/'test.vdb'),'-l',str(out/'test.log')]
  if name=='reset':argv.remove('+PACKET_BEATS=32')
  record=dict(index=590+i,test=test,negative=False,argv=argv,log=str(out/'test.log'),vdb=str(out/'test.vdb'))
  (out/'plan.json').write_text(json.dumps(record,indent=2)+'\n')
  if not a.execute:continue
  result=execute(record)
  (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
  print(name,result['status'],flush=True)
  if result['status']!='PASS':failures.append(name)
  if result['status']=='PASS':
   cmd=[sys.executable,str(ROOT/'dv/uvm/refmodel/python/check_thermo5_monitor_trace.py'),str(out/'test.jsonl')]
   with (out/'oracle.log').open('w') as f:code=subprocess.run(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT).returncode
   print(name,'oracle',code,flush=True)
   if code:failures.append(name+' oracle')
   (out/'oracle_result.json').write_text(json.dumps({'command':cmd,'exit_code':code,'log_sha256':hashlib.sha256((out/'oracle.log').read_bytes()).hexdigest()},indent=2)+'\n')
 if failures:raise SystemExit('P0 failed: '+', '.join(failures))
if __name__=='__main__':main()
