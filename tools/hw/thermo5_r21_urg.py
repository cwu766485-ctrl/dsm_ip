#!/usr/bin/env python3.12
"""Generate same-parent Raw/zero-approved Adjusted/What-if and assertion reports.

Requires the established runs/product, runs/replay_final and four focused VDBs.
Refuses any failed test or differing compile parent. Pending candidates are
applied only to the explicitly named What-if report.
"""
from pathlib import Path
import json,sys,gzip,hashlib,subprocess
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'tools/hw'))
import thermo5_tx_r17_supplemental_coverage as h
out=root/'runs/final_urg';out.mkdir(exist_ok=True)
r=json.load(open(root/'runs/replay_final/results.json'));retry=json.load(open(root/'runs/replay_final/retry360.json'));r=[retry if x['index']==360 else x for x in r];assert len(r)==580 and all(x['status']=='PASS' for x in r)
design=root/'runs/product/simv.vdb';parent=(design/'snps/coverage/db/auxiliary/vcmArguments.xml').read_bytes()
for x in r:
 p=Path(x['vdb'])/'snps/coverage/db/testdata/test/vcmArguments.xml';assert p.read_bytes()==parent,p
additional=[root/f'runs/{n}.vdb' for n in ('qonly','ionly','queue','sat_gap')]
for p in additional:assert (p/'snps/coverage/db/testdata/test/vcmArguments.xml').read_bytes()==parent
legal=[Path(x['vdb']) for x in r if not x['negative']]+additional
negative=[Path(x['vdb']) for x in r if x['negative']]
original=root/'docs/verification/data/thermo5-r20/analysis_only/r20_all_candidate_batches_plus_axil_bin.elfilelist'
elfilelist=out/'analysis.elfilelist';elfilelist.write_text(''.join(str(root/l.strip())+'\n' for l in original.read_text().splitlines() if l.strip()))
results={}
for label,tests,el in [('legal_raw',legal,None),('negative_only',negative,None),('raw',legal+negative,None),('approved_adjusted',legal+negative,None),('whatif',legal+negative,elfilelist)]:
 dest=out/label;dest.mkdir(exist_ok=True)
 cmd=['/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg','-full64','-dir',str(design),*map(str,tests),'-format','both','-report',str(dest/'report'),'-dbname',str(dest/'urg.vdb'),'-log',str(dest/'urg.log')]
 if el:cmd+=['-elfilelist',str(el),'-excl_strict']
 (dest/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
 with (dest/'console.log').open('w') as f:code=subprocess.run(cmd,cwd=root,stdout=f,stderr=subprocess.STDOUT).returncode
 assert code==0,(label,code)
 results[label]=h.residual.coverage_summary(dest/'report',dest/'inventory');print(label,results[label]['metrics'][:4],flush=True)
 (out/'summaries.json').write_text(json.dumps(results,indent=2)+'\n')
manifest=dict(tests=r,additional=[str(p) for p in additional],legal_count=len(legal),negative_count=len(negative),design=str(design),homogeneous_parent_sha256=hashlib.sha256(parent).hexdigest(),vdbs=[dict(path=str(p),**h.residual.tree_fingerprint(p)) for p in [design,*legal,*negative]])
(out/'vdb_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
