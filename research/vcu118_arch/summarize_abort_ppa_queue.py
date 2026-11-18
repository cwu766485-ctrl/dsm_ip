#!/usr/bin/env python3
"""Wait for isolated abort-PPA queue and summarize only completed native reports."""
from pathlib import Path
import csv,hashlib,json,re,sys,time
root=Path(__file__).resolve().parents[2]
if len(sys.argv)!=3:raise SystemExit('usage: summarize_abort_ppa_queue.py runs/QUEUE runs/NEW_DIR')
queue=(root/sys.argv[1]).resolve();out=(root/sys.argv[2]).resolve()
if root/'runs' not in queue.parents or root/'runs' not in out.parents:raise ValueError('paths must be below runs')
out.mkdir(parents=True,exist_ok=False)
while not (queue/'done').exists():time.sleep(30)
status=json.loads((queue/'results.json').read_text()) if (queue/'results.json').exists() else {}
rows=[]; hashes={}
for case in ('ef1','mash'):
 row={'case':case,'status':'BLOCKED','scope':'OOC prototype; CDC, parent clock/IO, GT/PA and reset signoff open'};d=queue/(case+'_implementation')
 needed=['routed.dcp','routed_timing_summary.rpt','routed_utilization.rpt','setup_worst20.rpt','hold_worst20.rpt','power_default_activity.rpt','exceptions.rpt']
 if not status.get(case,{}).get('valid_run') or any(not (d/f).is_file() for f in needed):row['reason']='missing validated completion or native reports';rows.append(row);continue
 t=(d/'routed_timing_summary.rpt').read_text(errors='replace');u=(d/'routed_utilization.rpt').read_text(errors='replace');p=(d/'power_default_activity.rpt').read_text(errors='replace');paths=(d/'setup_worst20.rpt').read_text(errors='replace')
 m=re.search(r'WNS\(ns\).*?\n\s*-+(?:\s+-+)+\s*\n\s*([-\d.]+)\s+([-\d.]+)\s+\d+\s+\d+\s+([-\d.]+)\s+([-\d.]+)',t,re.S)
 if not m:raise ValueError('timing parse failed '+case)
 for k,v in zip(('setup_wns_ns','setup_tns_ns','hold_wns_ns','hold_tns_ns'),m.groups()):row[k]=v
 for label,key in [('CLB LUTs','lut'),('CLB Registers','ff'),('DSPs','dsp'),('Block RAM Tile','bram'),('CARRY8','carry8')]:
  m=re.search(r'^\|\s*'+re.escape(label)+r'\s*\|\s*([\d.]+)',u,re.M)
  if not m:raise ValueError('util parse failed '+case+' '+label)
  row[key]=m.group(1)
 row['power_w']=re.search(r'Total On-Chip Power \(W\)\s*\|\s*([\d.]+)',p).group(1)
 row['worst_path']=re.search(r'^\s*Source:\s*(.+)$',paths,re.M).group(1).strip()+' -> '+re.search(r'^\s*Destination:\s*(.+)$',paths,re.M).group(1).strip()
 row['status']='FAIL' if float(row['setup_wns_ns'])<0 or float(row['hold_wns_ns'])<0 or float(row['setup_tns_ns'])!=0 else 'BLOCKED'
 row['reason']='native timing violations' if row['status']=='FAIL' else 'OOC timing nonnegative; physical/CDC qualification incomplete'
 hashes[case]={f:hashlib.sha256((d/f).read_bytes()).hexdigest() for f in needed};rows.append(row)
cols=['case','status','setup_wns_ns','setup_tns_ns','hold_wns_ns','hold_tns_ns','lut','ff','dsp','bram','carry8','power_w','worst_path','scope','reason']
with (out/'ppa_summary.csv').open('x',newline='') as f:w=csv.DictWriter(f,fieldnames=cols);w.writeheader();w.writerows(rows)
(out/'evidence_sha256.json').write_text(json.dumps(hashes,indent=2)+'\n');print('ABORT_PPA_SUMMARY_COMPLETE',flush=True)
