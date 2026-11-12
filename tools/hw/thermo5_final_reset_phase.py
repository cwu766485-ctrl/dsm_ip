#!/usr/bin/env python3.12
"""Two fixed clock-phase reset witnesses on the frozen Generic product compile."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/hw'))
from thermo5_r21_replay import execute

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--execute',action='store_true');a=p.parse_args()
 base=ROOT/'runs/final_cdc_reset';base.mkdir(exist_ok=True)
 template=json.loads((ROOT/'runs/dv_convergence_v3/reset/plan.json').read_text())
 for src,axil in [(137,311),(3999,4999)]:
  out=base/f'pending_reset_src{src}_axil{axil}';out.mkdir(exist_ok=True)
  argv=template['argv'][:]
  for i,v in enumerate(argv):
   if v.startswith('+THERMO5_TRACE_JSONL='):argv[i]='+THERMO5_TRACE_JSONL='+str(out/'test.jsonl')
   elif v.startswith('+THERMO5_WITNESS_VCD='):argv[i]='+THERMO5_WITNESS_VCD='+str(out/'test.vcd')
   elif v=='-cm_dir':argv[i+1]=str(out/'test.vdb')
   elif v=='-l':argv[i+1]=str(out/'test.log')
  argv += [f'+SOURCE_CLOCK_PHASE_PS={src}',f'+AXIL_CLOCK_PHASE_PS={axil}']
  record=dict(template,argv=argv,log=str(out/'test.log'),vdb=str(out/'test.vdb'))
  (out/'plan.json').write_text(json.dumps(record,indent=2)+'\n')
  if not a.execute:continue
  result=execute(record);(out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
  if result['status']!='PASS':raise SystemExit(str(result))
  cmd=[sys.executable,str(ROOT/'dv/uvm/refmodel/python/check_thermo5_monitor_trace.py'),str(out/'test.jsonl')]
  with (out/'oracle.log').open('w') as f:code=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,cwd=ROOT).returncode
  (out/'oracle_result.json').write_text(json.dumps({'exit_code':code,'command':cmd,'sha256':hashlib.sha256((out/'oracle.log').read_bytes()).hexdigest()},indent=2)+'\n')
  if code:raise SystemExit('oracle failure')
  print(out.name,'licensed UVM and independent oracle PASS',flush=True)
if __name__=='__main__':main()
