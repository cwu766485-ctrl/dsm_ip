#!/usr/bin/env python3.12
"""Bind R20 residual Condition bins to exact URG expressions and VCD edges.

Expression and subexpression identities are distinct even when their line and
operand vector coincide. VCD sampling uses values immediately before each
rising clock edge, not post-NBA values. No waiver or exclusion is written.
"""
import argparse
import csv
import gzip
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
import thermo5_audit_reports as audit

ROOT=Path(__file__).resolve().parents[2]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def vcd_edges(path):
    scope=[]; names={}; values={}; changes=[]; time=0; defined=False
    def flush():
        nonlocal values
        updated=dict(values)
        for code,value in changes:
            updated[code]=value
        clocks=[code for code,value in changes if value=="1" and
                values.get(code)=="0" and any(n.endswith(".clk") for n in names.get(code,()))]
        snapshots=[]
        for code in clocks:
            for clock in names[code]:
                if not clock.endswith(".clk"): continue
                prefix=clock[:-4]
                state={name[len(prefix)+1:]:values.get(c,"x")
                       for c,ns in names.items() for name in ns
                       if name.startswith(prefix+".") and "." not in name[len(prefix)+1:]}
                snapshots.append((time,prefix,state))
        values=updated
        return snapshots
    with path.open() as stream:
        for raw in stream:
            line=raw.strip()
            if not defined:
                fields=line.split()
                if line.startswith("$scope"): scope.append(fields[2])
                elif line.startswith("$upscope"): scope.pop()
                elif line.startswith("$var"):
                    names.setdefault(fields[3],[]).append(".".join(scope+[fields[4]]))
                elif line.startswith("$enddefinitions"): defined=True
            elif line.startswith("#"):
                yield from flush(); changes=[];time=int(line[1:])
            elif line and line[0] in "01xz": changes.append((line[1:],line[0]))
            elif line.startswith("b"):
                value,code=line[1:].split();changes.append((code,value))
    yield from flush()

def analyze_vcd(path):
    queues=defaultdict(Counter); examples={}; dpd=defaultdict(Counter)
    for time,scope,s in vcd_edges(path):
        def number(name):
            value=s.get(name,"x")
            return int(value,2) if re.fullmatch("[01]+",value) else None
        if number("rst_n")!=1: continue
        if "u_interp_" in scope:
            count=number("q_count");pop=number("pop_head");push=number("push_input")
            key=f"q={count},pop={pop},push={push},tail={number('q0_tail')},end={number('q0_end')}"
            queues[scope][key]+=1
            if count==1 and pop==1 and push==1:
                examples.setdefault(scope+":single_pop_push",dict(time_ps=time,state=s))
        elif scope.endswith(".u_dpd"):
            valid=s.get("valid_pipe","")
            # PIPE_STAGES=11: VCD omits leading zeros.
            v=int(valid,2)>>10 & 1 if re.fullmatch("[01]+",valid) else None
            si=number("sat_i");sq=number("sat_q")
            dpd[scope][f"valid={v},sat_i={si},sat_q={sq}"]+=1
            if v==1 and (si,sq) in ((0,1),(1,0)):
                examples.setdefault(scope+f":sat={si}/{sq}",dict(time_ps=time,state={
                    k:s.get(k) for k in ('valid_pipe','sat_i','sat_q','pipe_ce','out_ready')}))
    return dict(file=str(path),sha256=digest(path),
                queue_edges={k:dict(v) for k,v in queues.items()},
                dpd_edges={k:dict(v) for k,v in dpd.items()},examples=examples)

def condition_hits(ledger,report):
    conditions,*_=audit.condition_rows(report)
    hits=[]
    for row in ledger:
        if row['metric']!='cond': continue
        if digest(ROOT/row['source_file']) != row['source_file_sha256']:
            raise ValueError('Stale source hash: '+row['source_file'])
        line,operand=row['exact_urg_bin'].split(':')
        kind='SUB-EXPRESSION' if ':subexpression:' in row['source_location'] else 'EXPRESSION'
        matches=[c for c in conditions if c['instance']==row['instance'] and
                 c['line']==line and c['operand_bin']==operand and
                 c['expression'].startswith(kind)]
        if len(matches)>1:
            raise ValueError(f"Ambiguous exact Condition: {row['semantic_bin_id']}")
        if len(matches)==1 and matches[0]['status']=='Covered':
            hits.append({**row,'r21_status':'HIT','urg_expression':matches[0]['expression'],
                         'urg_page':str(report/matches[0]['module_file']),
                         'urg_page_sha256':digest(report/matches[0]['module_file'])})
    return hits

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--ledger',type=Path,required=True)
    p.add_argument('--report',type=Path,required=True)
    p.add_argument('--vcd',type=Path,action='append',default=[])
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    with gzip.open(args.ledger,'rt') as f: rows=list(csv.DictReader(f))
    result=dict(ledger_sha256=digest(args.ledger),hits=condition_hits(rows,args.report),
                witnesses=[analyze_vcd(v) for v in args.vcd])
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print('EXACT_CONDITION_HITS',len(result['hits']))
