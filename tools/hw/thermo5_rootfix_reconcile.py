#!/usr/bin/env python3
"""Reconcile native SpyGlass counts and PR61 root groups; never waive records."""
import argparse,csv,gzip,json,re,collections,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from thermo5_rdc_rootcause_audit import audit

def parse(report,goal):
 rows=[]
 for line in report.splitlines():
  m=re.match(r'^\[([^]]+)\]\s+(\S+)\s+(.*?)\b(SynthesisWarning|Error|Warning|Info|Fatal)\s+(\S+)\s+(\d+)\s+(\d+)\s+(.*)$',line)
  if not m:continue
  ident,rule,alias,sev,file,num,wt,msg=m.groups()
  rows.append(dict(goal=goal,message_id=ident,rule=rule,severity='Warning' if sev=='SynthesisWarning' else sev,source_file=file.split('/rtl/')[-1] if '/rtl/' in file else file,line=num,source=';'.join(re.findall(r"(?:from Flop|Source flop) '([^']+)'",msg)),destination=';'.join(re.findall(r"(?:to Flop|Destination flop) '([^']+)'",msg)),message=msg))
 return rows

def main():
 p=argparse.ArgumentParser();p.add_argument('--runs',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
 result={};allrows=[]
 for goal in ['setup','cdc','rdc']:
  rows=parse((a.runs/goal/'moresimple.rpt').read_text(),goal)
  log=(a.runs/goal/'console.log').read_text()
  m=re.search(r'Reported Messages:\s*(\d+) Fatals,\s*(\d+) Errors,\s*(\d+) Warnings,\s*(\d+) Infos',log);assert m,goal
  totals=dict(zip(['Fatal','Error','Warning','Info'],map(int,m.groups())))
  actual=collections.Counter(r['severity'] for r in rows);assert all(actual[k]==v for k,v in totals.items()),(goal,actual,totals)
  result[goal]=dict(counts=totals,rules=dict(collections.Counter(r['rule'] for r in rows)));allrows+=rows
 with gzip.open(a.out/'static_messages.csv.gz','wt',newline='')as f:
  w=csv.DictWriter(f,fieldnames=allrows[0],lineterminator='\n');w.writeheader();w.writerows(allrows)
 grouped=audit(a.out/'static_messages.csv.gz')
 result['groups']=len(grouped['root_groups']);result['categories']=grouped['root_category_counts'];result['rdc_records']=sum(g['count'] for g in grouped['root_groups'] if g['goal']=='rdc')
 assert result['rdc_records']==result['rdc']['rules']['Ar_resetcross01']
 (a.out/'reconciliation.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()
