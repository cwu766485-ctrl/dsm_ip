#!/usr/bin/env python3.12
"""Merge fixed two phase-reset witnesses with unchanged594 baseline, five views."""
import json,subprocess,sys,re,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/hw'))
from thermo5_tx_r17_residual_whatif import coverage_summary
base=ROOT/'runs/final_cdc_reset';old=ROOT/'runs/dv_convergence_v3'
records=json.loads((old/'replay_results.json').read_text())+[json.loads((old/n/'result.json').read_text()) for n in ['overlap','long64','long96','reset']]
records += [json.loads((p/'result.json').read_text()) for p in sorted(base.glob('pending_reset*'))]
assert len(records)==596 and all(r['status']=='PASS' for r in records)
summaries={};checks={}
for view in ['raw','approved_adjusted','whatif','legal_raw','negative_only']:
 out=base/view;out.mkdir(exist_ok=True)
 cmd=json.loads((old/view/'command.json').read_text())
 if view!='negative_only':
  i=cmd.index('-format');cmd[i:i]=[r['vdb'] for r in records[-2:]]
 for flag,name in [('-report','report'),('-dbname','urg.vdb'),('-log','urg.log')]:cmd[cmd.index(flag)+1]=str(out/name)
 (out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
 with (out/'stdout').open('w') as f:code=subprocess.run(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT).returncode
 assert code==0
 log=(out/'urg.log').read_text();assert not re.search(r'warning|error|mismatch|checksum',log,re.I)
 summaries[view]=coverage_summary(out/'report',out/'inventory');checks[view]={'command':cmd,'log_sha256':hashlib.sha256((out/'urg.log').read_bytes()).hexdigest(),'diagnostics':0}
metrics=lambda s:{x['metric']:(x['covered'],x['total']) for x in s['metrics'] if x['ownership']=='PROJECT_RTL'}
baseline=json.loads((ROOT/'docs/verification/data/thermo5-dv-v3/coverage_summaries.json').read_text())
delta={}
for view in ['raw','approved_adjusted','whatif']:
 delta[view]={}
 for m,(c,t) in metrics(summaries[view]).items():
  bc,bt=metrics(baseline[view])[m];assert t==bt and c>=bc;delta[view][m]=c-bc
assert metrics(summaries['raw'])==metrics(summaries['approved_adjusted'])
(base/'coverage.json').write_text(json.dumps({'tests':596,'new_legal_tests':2,'same_compile_parent':str(old/'compile/simv.vdb'),'delta':delta,'summaries':summaries,'views':checks},indent=2)+'\n')
print(delta)
