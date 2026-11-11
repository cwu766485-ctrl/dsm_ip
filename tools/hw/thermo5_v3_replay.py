#!/usr/bin/env python3.12
"""Rebind existing590 scenarios to final v3 compile without adding seeds."""
import argparse,json,sys,concurrent.futures
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/hw'))
from thermo5_r21_replay import execute
import gzip,xml.etree.ElementTree as ET,shlex

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--execute',action='store_true');a=p.parse_args()
 base=ROOT/'runs/dv_convergence_v3';folder=base/'replay';folder.mkdir(exist_ok=True)
 records=json.loads((ROOT/'runs/rtl_invariants/replay_results.json').read_text())
 for index,name in [(586,'boundary_commit'),(587,'stalled_reset3'),(588,'ready_tail3')]:
  log=ROOT/'runs/rtl_invariants'/name/'test.log';info=list(log.with_suffix('.vdb').glob('**/siminfo.xml'));assert len(info)==1
  b=info[0].read_bytes();b=gzip.decompress(b) if b.startswith(b'\x1f\x8b') else b
  records.append(dict(index=index,test=name,negative=False,argv=shlex.split(ET.fromstring(b).find('srctest').attrib['cmdline'])))
 records.append(json.loads((ROOT/'runs/dv_convergence_v2/nonidentity_commit_stall/result.json').read_text()))
 fresh=[]
 for old in records:
  argv=[str(base/'compile/simv')];skip=False
  for a in old['argv'][1:]:
   if skip:skip=False;continue
   if a in ('-cm_dir','-l'):skip=True;continue
   if a.startswith('+THERMO5_TRACE_JSONL='):a='+THERMO5_TRACE_JSONL='+str(folder/f'{old["index"]}.jsonl')
   if a.startswith('+THERMO5_WITNESS_VCD='):a='+THERMO5_WITNESS_VCD='+str(folder/f'{old["index"]}.vcd')
   argv.append(a)
  argv+=['-cm_dir',str(folder/f'{old["index"]}.vdb'),'-l',str(folder/f'{old["index"]}.log')]
  fresh.append(dict(index=old['index'],test=old['test'],negative=old['negative'],argv=argv,log=str(folder/f'{old["index"]}.log'),vdb=str(folder/f'{old["index"]}.vdb')))
 assert len(fresh)==590
 (base/'replay_plan.json').write_text(json.dumps(fresh,indent=2)+'\n')
 if not a.execute:
  print('PLAN590;pass --execute to replay final compile');return
 with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:results=list(pool.map(execute,fresh))
 (base/'replay_results.json').write_text(json.dumps(results,indent=2)+'\n')
 print('REPLAY',len(results),'PASS',sum(x['status']=='PASS' for x in results),flush=True)
 for x in results:
  if x['status']!='PASS':print(x['index'],x['test'],x['status'])
 if any(x['status']!='PASS' for x in results):raise SystemExit(1)
if __name__=='__main__':main()
