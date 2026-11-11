#!/usr/bin/env python3.12
"""Verify three URG views; pass --execute to rebuild frozen589 plus directed VDB."""
import json,subprocess,sys,hashlib,gzip,xml.etree.ElementTree as ET
from pathlib import Path
sys.path.insert(0,'tools/hw')
from thermo5_tx_r17_residual_whatif import coverage_summary
out=Path('runs/dv_convergence_v2').resolve();test=out/'nonidentity_commit_stall/test.vdb'
parent=Path('runs/rtl_invariants/compile2/simv.vdb')
assert hashlib.sha256((parent/'snps/coverage/db/auxiliary/vcmArguments.xml').read_bytes()).hexdigest()=='421a36094a493a2345eff8f165a44197bff12bbcf32a09963a61628353bf599e'
info=list(test.glob('**/siminfo.xml'));assert len(info)==1
b=info[0].read_bytes();b=gzip.decompress(b) if b.startswith(b'\x1f\x8b') else b
assert ET.fromstring(b).find('srctest').attrib['cmdline'].startswith(str(Path('runs/rtl_invariants/compile2/simv').resolve())+' ')
res={}
for view,old in [('raw','runs/rtl_invariants/urg/raw/command.json'),('approved_adjusted','runs/rtl_invariants/urg/approved_adjusted/command.json'),('whatif','runs/pr55_exact/full_whatif/command.json')]:
 cmd=json.load(open(old));idx=next((i for i,x in enumerate(cmd) if x.startswith('-') and i>cmd.index('-dir')+1),len(cmd));cmd.insert(idx,str(test))
 folder=out/view;folder.mkdir(exist_ok=True)
 for flag,value in [('-report',str(folder/'report')),('-dbname',str(folder/'urg.vdb')),('-log',str(folder/'urg.log'))]:
  cmd[cmd.index(flag)+1]=value
 (folder/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
 if '--execute' in sys.argv:
  with (folder/'stdout').open('w') as f: code=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT).returncode
  assert code==0,(view,code)
 res[view]=coverage_summary(folder/'report',folder/'inventory');print(view,res[view].get('metrics'),flush=True)
(out/'coverage_summaries.json').write_text(json.dumps(res,indent=2)+'\n')
checks={}
for view in res:
 folder=out/view
 log=(folder/'urg.log').read_text()
 assert not __import__('re').search(r'warning|error|mismatch|checksum',log,__import__('re').I), view
 old=json.load(open('runs/rtl_invariants/coverage_summaries.json'))['raw'] if view!='whatif' else json.load(open('runs/pr55_exact/full_whatif/summary.json'))
 def metrics(summary):return {m['metric']:(m['covered'],m['total']) for m in summary['metrics'] if m['ownership']=='PROJECT_RTL'}
 assert metrics(old)==metrics(res[view]), (view,metrics(old),metrics(res[view]))
 checks[view]={'metric_delta':{k:0 for k in metrics(res[view])},'diagnostics':0,'same_frozen589_plus_directed':True,
               'command_sha256':hashlib.sha256((folder/'command.json').read_bytes()).hexdigest(),
               'urg_log_sha256':hashlib.sha256((folder/'urg.log').read_bytes()).hexdigest()}
input_sets=[]
for view in res:
 command=json.load(open(out/view/'command.json'));i=command.index('-dir')+1;j=next((j for j in range(i,len(command)) if command[j].startswith('-')),len(command));input_sets.append(set(command[i:j]))
assert input_sets[0]==input_sets[1]==input_sets[2] and len(input_sets[0])==591
(out/'vdb_manifest.json').write_text(json.dumps({'design_test_paths':sorted(input_sets[0]),'design_parent_count':1,'test_vdb_count':590,'same_inputs_all_views':True},indent=2)+'\n')
(out/'urg_checks.json').write_text(json.dumps(checks,indent=2)+'\n')
