#!/usr/bin/env python3
"""Conservatively group native CDC/RDC messages; no classifications or waivers."""
from pathlib import Path
from collections import Counter
import argparse,csv,json,re
p=argparse.ArgumentParser();p.add_argument('--rdc',type=Path,required=True);p.add_argument('--cdc',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
def norm(s):
 s=re.sub(r'\[[^\]]+\]','[*]',s).replace('\\','');return re.sub(r'\s+','',s)
def parent(s):return norm(s).rsplit('.',1)[0]
counts=Counter();rdc=0;unparsed=[]
pat=re.compile(r"^\[(\S+)\]\s+(Ar_resetcross01)\s+Error\s+.*?Unsynchronized reset crossing detected from Flop '(.+?)' \((Reset|Set): '(.+?)'\) to Flop '(.+?)' (?:\((.+?)\) )?\(Reset: '(.+?)'\), that are clocked by '(.+?)'\. Reason: (.+)$")
for line in a.rdc.read_text(errors='replace').splitlines():
 if re.match(r'^\[\S+\]\s+Ar_resetcross01\s+Error',line):
  rdc+=1;m=pat.match(line)
  if not m:
   m2=re.search(r"from Flop '(.+?)' \((Reset|Set): '(.+?)', Clock: '(.+?)'\) to Flop '(.+?)' \((Reset|Set): '(.+?)', Clock: '(.+?)'\)\. Reason: (.+)$",line)
   if not m2:unparsed.append(line);continue
   src,sk,srst,sclk,dst,dk,drst,dclk,reason=m2.groups()
   counts[('Ar_resetcross01',sk+':'+norm(srst),dk+':'+norm(drst),parent(src),parent(dst),'ASYNC_Q->D',norm(sclk)+'->'+norm(dclk),reason)]+=1
   continue
  ident,rule,src,srtype,srst,dst,kind,drst,clk,reason=m.groups();counts[(rule,srtype+":"+norm(srst),norm(drst),parent(src),parent(dst),kind or "Q->D",norm(clk),reason)]+=1
with (a.out/'rdc_groups.csv').open('w',newline='') as f:
 w=csv.writer(f);w.writerow(['rule','source_reset','destination_reset','source_hierarchy','destination_hierarchy','crossing','clock','tool_reason','count','disposition']);
 for k,v in counts.most_common():w.writerow([*k,v,'OPEN_REVIEW'])
cdc=Counter();section=('','')
for line in a.cdc.read_text(errors='replace').splitlines():
 if line.startswith('Source Clock:'):section=(line.split(':',1)[1].strip(),section[1])
 elif line.startswith('Destination Clock:'):section=(section[0],line.split(':',1)[1].strip())
 m=re.match(r'^\s*\d+\s+(CDC-\d+)\s+(Info|Warning|Critical)\s+.*?\s+\d+\s+\S+\s+(\S+)\s+(\S+)\s*$',line)
 if m:
  rule,severity,src,dst=m.groups();cdc[(rule,severity,*section,parent(src),parent(dst))]+=1
with (a.out/'cdc_groups.csv').open('w',newline='') as f:
 w=csv.writer(f);w.writerow(['rule','severity','source_clock','destination_clock','source_hierarchy','destination_hierarchy','count','disposition']);
 for k,v in cdc.most_common():w.writerow([*k,v,'OPEN_REVIEW'])
summary={'rdc_error_total':rdc,'rdc_parsed':sum(counts.values()),'rdc_unparsed':len(unparsed),'rdc_groups':len(counts),'cdc_parsed_rows':sum(cdc.values()),'cdc_groups':len(cdc),'cdc15_rows':sum(v for k,v in cdc.items() if k[0]=='CDC-15')};(a.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(a.out/'unparsed_rdc.txt').write_text('\n'.join(unparsed));print(json.dumps(summary))
if unparsed or rdc!=10539 or summary['cdc15_rows']!=101:raise SystemExit('count mismatch: inspect inputs')
