#!/usr/bin/env python3.12
"""Same final compile:590 replay plus four P0 tests;three independent URG views."""
import json,subprocess,sys,hashlib,gzip,re,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/hw'))
from thermo5_tx_r17_residual_whatif import coverage_summary
from thermo5_r21_witness import condition_hits

def main():
 base=ROOT/'runs/dv_convergence_v3';parent=base/'compile/simv.vdb'
 records=json.loads((base/'replay_results.json').read_text())
 records += [json.loads((base/name/'result.json').read_text()) for name in ['overlap','long64','long96','reset']]
 assert len(records)==594 and all(x['status']=='PASS' for x in records)
 for r in records:
  info=list(Path(r['vdb']).glob('**/siminfo.xml'));assert len(info)==1
  b=info[0].read_bytes();b=gzip.decompress(b) if b.startswith(b'\x1f\x8b') else b
  assert ET.fromstring(b).find('srctest').attrib['cmdline'].startswith(str(base/'compile/simv')+' ')
 summaries={};checks={}
 for view in ['raw','approved_adjusted','whatif','legal_raw','negative_only']:
  out=base/view;out.mkdir(exist_ok=True)
  selected=[r for r in records if not r['negative']] if view=='legal_raw' else [r for r in records if r['negative']] if view=='negative_only' else records
  cmd=['/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg','-full64','-dir',str(parent)]+[r['vdb'] for r in selected]+['-format','both','-report',str(out/'report'),'-dbname',str(out/'urg.vdb'),'-log',str(out/'urg.log')]
  if view=='whatif':
   old=json.load(open(ROOT/'runs/dv_convergence_v2/whatif/command.json'))
   cmd += ['-elfilelist',old[old.index('-elfilelist')+1],'-excl_strict']
  (out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
  if '--execute' in sys.argv:
   with (out/'stdout').open('w') as f:code=subprocess.run(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT).returncode
   assert code==0,(view,code)
  text=(out/'urg.log').read_text();assert not re.search(r'warning|error|mismatch|checksum',text,re.I),(view,text)
  summaries[view]=coverage_summary(out/'report',out/'inventory');checks[view]={'tests':len(selected),'diagnostics':0,'command':cmd,'urg_log_sha256':hashlib.sha256((out/'urg.log').read_bytes()).hexdigest()}
 def metrics(s):return {m['metric']:m for m in s['metrics'] if m['ownership']=='PROJECT_RTL'}
 baseline=json.load(open(ROOT/'runs/dv_convergence_v2/coverage_summaries.json'))
 delta={}
 for view in ['raw','approved_adjusted','whatif']:
  old,new=metrics(baseline[view]),metrics(summaries[view]);delta[view]={}
  for metric in old:
   assert new[metric]['total']==old[metric]['total'],(view,metric,'denominator drift')
   assert new[metric]['covered']>=old[metric]['covered'],(view,metric,'lost hit')
   delta[view][metric]=new[metric]['covered']-old[metric]['covered']
 assert metrics(summaries['raw'])==metrics(summaries['approved_adjusted'])
 import csv
 ledger=list(csv.DictReader((ROOT/'docs/verification/data/thermo5-pr55-application/v2/coverage_exact_triage_v2.csv').open()))
 open48=[r for r in ledger if r['v2_status']=='UNRESOLVED']
 hits=condition_hits(open48,base/'raw/report')
 manifest={'tests':594,'legal':590,'expected_negative':4,'same_compile':True,'product_sha':'635be681046b3ab7d6fdda7f4e9818d7226efd66',
 'compile_argument_sha256':hashlib.sha256((parent/'snps/coverage/db/auxiliary/vcmArguments.xml').read_bytes()).hexdigest(),
 'actual_delta':delta,'remaining48_condition_hits':hits,'approved_exclusions':0,'accepted_exceptions':0,
 'new_formal':'NOT_RUN;no new hypothesis for existing inconclusive obligations','views':checks}
 out=ROOT/'docs/verification/data/thermo5-dv-v3'
 (out/'coverage_summaries.json').write_text(json.dumps(summaries,indent=2)+'\n')
 (out/'vdb_urg_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('PASS',delta,'exact48conditionhits',len(hits),flush=True)
if __name__=='__main__':main()
