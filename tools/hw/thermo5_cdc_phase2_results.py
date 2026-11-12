#!/usr/bin/env python3.12
"""Parse actual static messages and block witnesses; never apply waivers."""
import collections,csv,gzip,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'runs/cdc_phase2';OUT=ROOT/'docs/verification/data/thermo5-cdc-phase2'

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 OUT.mkdir(parents=True,exist_ok=True);result={};allrows=[]
 for goal in ['setup','cdc','rdc']:
  report=RUN/goal/'moresimple.rpt';log=(RUN/goal/'console.log').read_text()
  rows=[]
  for line in report.read_text().splitlines():
   m=re.match(r'^\[([^]]+)\]\s+(\S+)\s+(.*?)\b(SynthesisWarning|Error|Warning|Info|Fatal)\s+(\S+)\s+(\d+)\s+(\d+)\s+(.*)$',line)
   if not m:continue
   ident,rule,alias,severity,file,number,weight,message=m.groups()
   if severity=='SynthesisWarning':severity='Warning'
   sources=re.findall(r"(?:from Flop|Source flop) '([^']+)'",message)
   destinations=re.findall(r"(?:to Flop|Destination flop) '([^']+)'",message)
   row=dict(goal=goal,message_id=ident,rule=rule,severity=severity,source_file=file.replace(str(ROOT)+'/',''),line=number,source=';'.join(sources),destination=';'.join(destinations),message=message,disposition='OPEN_REVIEW_REQUIRED',approval_reference='')
   rows.append(row)
  summary=re.search(r'Reported Messages:\s*(\d+) Fatals,\s*(\d+) Errors,\s*(\d+) Warnings,\s*(\d+) Infos',log)
  assert summary,(goal,'missing goal completion')
  counts=dict(zip(['Fatal','Error','Warning','Info'],map(int,summary.groups())))
  observed=collections.Counter(r['severity'] for r in rows)
  assert all(observed[k]==v for k,v in counts.items()),(goal,counts,observed)
  result[goal]=dict(counts=counts,rule_counts=dict(collections.Counter(r['rule'] for r in rows)),report_sha256=digest(report),console_sha256=digest(RUN/goal/'console.log'),waivers=0)
  allrows+=rows
  with gzip.open(OUT/f'{goal}_moresimple.rpt.gz','wb') as f:f.write(report.read_bytes())
 with gzip.open(OUT/'static_messages.csv.gz','wt',newline='') as f:
  w=csv.DictWriter(f,fieldnames=allrows[0],lineterminator='\n');w.writeheader();w.writerows(allrows)
 priority=(RUN/'priority_cross/test.log').read_text();fifo=(RUN/'fifo/test.log').read_text()
 assert 'DONE_W1C_PRIORITY_PASS collisions=1 functional_cross=100.00' in priority
 assert 'GENERIC_FIFO_EPOCH_PASS' in fifo
 result['block_tests']={'done_w1c':'PASS;105000ps epoch0;actual simultaneous RHS sampled;subsequent clear/readback;DECERR/SLVERR','generic_fifo':'PASS;full16words/pending_write/reset/discard_old_epoch/64word_continuous_replay','scope':'BLOCK_ONLY;no product-level cross or URG claim','watchdogs':'PASS','log_sha256':{'priority':digest(RUN/'priority_cross/test.log'),'fifo':digest(RUN/'fifo/test.log')}}
 result['xpm']={'status':'BLOCKED_REAL_MODELS_MISSING','searched':['/opt','/usr/local','/home/ray','/mnt (recursive file search)','/mnt/d/Xilinx/Vivado (directory contains dsm_out_bits.coe only)'],'required':['data/verilog/src/glbl.v','data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv','data/ip/xpm/xpm_memory/hdl/xpm_memory.sv','data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv'],'substitute_used':False}
 result['product']={'rtl_diff_frozen':'EMPTY','product_sha':'635be681046b3ab7d6fdda7f4e9818d7226efd66','new_product_urg_hits':0,'new_approved_exclusions':0,'counter930':'OPEN','technical46':'OPEN','coverage':'No new product VDB;retain measured PR59 same-parent596 raw/official/whatif','static_signoff':'OPEN'}
 for goal in ['priority_cross','fifo']:
  (OUT/f'{goal}_test.log').write_bytes((RUN/goal/'test.log').read_bytes())
 (OUT/'results.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({k:v.get('counts',{}) for k,v in result.items() if k in ['setup','cdc','rdc']},indent=2))
if __name__=='__main__':main()
