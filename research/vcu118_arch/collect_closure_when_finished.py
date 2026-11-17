#!/usr/bin/env python3
"""Summarize completed EF1/MASH runs into a fresh directory; keep inputs read-only."""
from pathlib import Path
import csv,hashlib,json,re,sys,time
root=Path(__file__).resolve().parents[2]
out=(root/sys.argv[1]).resolve()
if root/'runs' not in out.parents:raise ValueError('output must be in runs')
out.mkdir(parents=True,exist_ok=False)
while not (root/'runs/mash_candidates_preempt_02/done').exists():time.sleep(30)
base=root/'docs/verification/vcu118_timing_live_20261117/updated_ppa_matrix.csv'
with base.open(newline='') as f:r=csv.DictReader(f);rows=list(r);fields=r.fieldnames
runs={'EF1 CDC bounded candidate A':root/'runs/ef1_cdc_candidate_preempt_03/implementation',
      'MASH cubic candidate A':root/'runs/mash_candidates_preempt_02/implementation_a',
      'MASH cubic candidate B':root/'runs/mash_candidates_preempt_02/implementation_b'}
hashes={}
ef1_result=root/'runs/ef1_cdc_candidate_preempt_03/result.json'
mash_result=root/'runs/mash_candidates_preempt_02/results.json'
validity={'EF1 CDC bounded candidate A':json.loads(ef1_result.read_text()).get('valid_run',False) if ef1_result.exists() else False}
mash_status=json.loads(mash_result.read_text()) if mash_result.exists() else {}
validity['MASH cubic candidate A']=mash_status.get('a',{}).get('valid_run',False)
validity['MASH cubic candidate B']=mash_status.get('b',{}).get('valid_run',False)
for x in rows:
 if x['case'] not in runs:continue
 d=runs[x['case']]
 if not validity[x['case']]:x['status']='BLOCKED';x['worst_path']='controller did not validate completed run';continue
 needed=['routed.dcp','routed_timing_summary.rpt','routed_utilization.rpt','power_default_activity.rpt','setup_worst20.rpt','hold_worst20.rpt']
 if any(not (d/n).is_file() for n in needed):x['status']='BLOCKED';x['worst_path']='implementation incomplete; inspect original log';continue
 timing=(d/'routed_timing_summary.rpt').read_text(errors='replace');util=(d/'routed_utilization.rpt').read_text(errors='replace');power=(d/'power_default_activity.rpt').read_text(errors='replace');paths=(d/'setup_worst20.rpt').read_text(errors='replace')
 m=re.search(r'WNS\(ns\).*?\n\s*-+(?:\s+-+)+\s*\n\s*([-\d.]+)\s+([-\d.]+)\s+\d+\s+\d+\s+([-\d.]+)\s+([-\d.]+)',timing,re.S)
 if not m:raise ValueError('timing parse failed '+str(d))
 for k,v in zip(('setup_wns_ns','setup_tns_ns','hold_wns_ns','hold_tns_ns'),m.groups()):x[k]=v
 for label,k in [('CLB LUTs','lut'),('CLB Registers','ff'),('DSPs','dsp'),('Block RAM Tile','bram_tiles'),('CARRY8','carry8')]:
  m=re.search(r'^\|\s*'+re.escape(label)+r'\s*\|\s*([\d.]+)',util,re.M)
  if not m:raise ValueError('util parse failed '+label)
  x[k]=m.group(1)
 x['power_w']=re.search(r'Total On-Chip Power \(W\)\s*\|\s*([\d.]+)',power).group(1)
 src=re.search(r'^\s*Source:\s*(.+)$',paths,re.M).group(1).strip();dst=re.search(r'^\s*Destination:\s*(.+)$',paths,re.M).group(1).strip()
 x['worst_path']=src+' -> '+dst
 x['status']='FAIL' if float(x['setup_wns_ns'])<0 or float(x['hold_wns_ns'])<0 else 'BLOCKED'
 x['evidence']=str(d.relative_to(root))+'; OOC only; physical/CDC review needed'
 hashes[x['case']]={n:hashlib.sha256((d/n).read_bytes()).hexdigest() for n in needed}
with (out/'updated_ppa_matrix.csv').open('x',newline='') as f:w=csv.DictWriter(f,fields);w.writeheader();w.writerows(rows)
(out/'evidence_sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
print('CLOSURE_SUMMARY_COMPLETE',out,flush=True)
