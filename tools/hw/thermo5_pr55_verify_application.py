#!/usr/bin/env python3.12
"""Fail closed on exact PR55 analysis application effects; never grant approval."""
import csv,gzip,hashlib,html,json,re
from pathlib import Path
import thermo5_audit_reports as audit
from thermo5_tx_run_native_analysis_exclusions import line_excluded_bins
ROOT=Path(__file__).resolve().parents[2]
DATA=ROOT/'docs/verification/data/thermo5-pr55-application'

def clean(s):return html.unescape(re.sub('<[^>]+>','',s)).strip()
def excluded_conditions(report):
    result=set()
    for p in report.glob('mod*.html'):
        for _,b,_ in audit.instance_blocks(p.read_text()):
            m=re.search(r'(?:Module Instance|\w+ Coverage for Instance)\s*:\s*<a[^>]*>(.*?)</a>',b,re.S)
            if not m:continue
            for c in re.finditer(r'<pre class="code">\s*LINE\s+(\d+)\s+(.*?)</pre>\s*<table.*?</table>',b,re.S):
                expr=' '.join(clean(c[2]).split())
                if 'EXPRESSION' not in expr:continue
                kind='subexpression' if expr.startswith('SUB-EXPRESSION') else 'expression'
                for row in re.findall(r'<tr class="wht">(.*?)</tr>',c[0],re.S):
                    cells=[clean(x) for x in re.findall(r'<td[^>]*>(.*?)(?:</td>|(?=<td|</tr>|$))',row,re.S)]
                    if cells and cells[-1]=='Excluded':result.add((clean(m[1]),int(c[1]),kind,'/'.join(cells[:-1])))
    return result

def excluded_toggles(report):
    result={}
    for p in report.glob('mod*.html'):
        for _,b,_ in audit.instance_blocks(p.read_text()):
            m=re.search(r'(?:Module Instance|\w+ Coverage for Instance)\s*:\s*<a[^>]*>(.*?)</a>',b,re.S)
            if not m:continue
            for detail in re.finditer(r'<caption><b>(?:Port Details|Signal Details)</b></caption>(.*?)(?=<caption>|<hr>|$)',b,re.S):
                for row in re.findall(r'<tr>(.*?)</tr>',detail[1],re.S):
                    cells=[clean(x) for x in re.findall(r'<td[^>]*>(.*?)(?:</td>|(?=<td|</tr>|$))',row,re.S)]
                    if len(cells)>=4:result[(clean(m[1]),cells[0])]=dict(one_to_zero=cells[2],zero_to_one=cells[3])
    return [dict(instance=k[0],signal=k[1],**v) for k,v in result.items()]

def metrics(p):
    return {x['metric']:{k:x[k] for k in ['total','covered']} for x in json.loads(p.read_text())['metrics'] if x['ownership']=='PROJECT_RTL'}

def main():
    rows=[x for x in csv.DictReader((ROOT/'docs/verification/data/thermo5-rtl-invariants/open87_review.csv').open()) if x['technical_decision']=='EXCLUSION_CANDIDATE']
    previous=[r for r in csv.DictReader((ROOT/'docs/verification/data/thermo5-stalled-reset/exact_dispositions_231.csv').open()) if r['final_disposition']=='EXCLUSION_CANDIDATE']
    mapping=json.loads((DATA/'native33.json').read_text());assert len({x['semantic_bin_id'] for x in mapping})==33
    checks={}
    for view,base,selected in [('parameter','raw',[r for r in rows if r['review_batch']!='LEGAL_FRAME_RESIDUAL_EIGHT']),('legal33','legal_raw',rows),('all33_diagnostic','raw',rows),('combined_whatif','whatif',rows),('previous141','raw',previous),('all174','raw',rows+previous),('full_whatif','whatif',rows+previous)]:
        report=ROOT/f'runs/pr55_exact/{view}/report';baseline=ROOT/f'runs/rtl_invariants/urg/{base}'
        expected_lines={(r['instance'],int(r['exact_urg_bin'].split(':')[0])) for r in selected if r['metric']=='line'}
        delta_lines=line_excluded_bins(report)-line_excluded_bins(baseline/'report');assert delta_lines==expected_lines,(view,delta_lines^expected_lines)
        expected_cond={(r['instance'],int(r['exact_urg_bin'].split(':')[0]),'subexpression' if ':subexpression:' in r['source_location'] else 'expression',r['exact_urg_bin'].split(':')[1]) for r in selected if r['metric']=='cond'}
        delta_cond=excluded_conditions(report)-excluded_conditions(baseline/'report');assert delta_cond==expected_cond,(view,delta_cond^expected_cond)
        toggles=excluded_toggles(report)
        for r in selected:
            if r['metric']!='toggle':continue
            n=json.loads(r['native_mapping'])[0];bit=n['selected_signal'];key='zero_to_one' if n['selected_direction']=='0_to_1' else 'one_to_zero'
            matches=[t for t in toggles if t['instance']==r['instance'] and (t['signal']==bit or '[' in bit and t['signal'].startswith(n['name']+'[') and int(bit.split('[')[1][:-1]) in range(min(map(int,re.findall(r'\d+',t['signal'].split('[')[1]))) ,max(map(int,re.findall(r'\d+',t['signal'].split('[')[1])))+1))]
            assert len(matches)==1 and matches[0][key]=='Excluded',(view,bit,matches)
        def branch_keys(path):
            return {(x['instance'],x['line'],x['decisions']) for x in csv.DictReader(path.open())}
        branch_removed=branch_keys(baseline/'inventory/branch_arms.csv')-branch_keys(ROOT/f'runs/pr55_exact/{view}/inventory/branch_arms.csv')
        expected_branch={(r['instance'],r['exact_urg_bin'].split(':')[0],r['exact_urg_bin'].split(':')[1]) for r in selected if r['metric']=='branch'}
        assert branch_removed==expected_branch,(view,branch_removed,expected_branch)
        before=metrics(baseline/'inventory/summary.json');after=metrics(ROOT/f'runs/pr55_exact/{view}/summary.json')
        expected={m:sum(r['metric']==m for r in selected) for m in before}
        for m in before:
            assert before[m]['covered']==after[m]['covered'],(view,'lost hit',m)
            assert before[m]['total']-after[m]['total']==expected[m],(view,m,expected)
        logs=(ROOT/f'runs/pr55_exact/{view}/urg.log').read_text()
        assert not re.search(r'warning|error|mismatch|checksum',logs,re.I)
        checks[view]={'exact_semantic_ids':[r['semantic_bin_id'] for r in selected],'applied_analysis_count':len(selected),'metric_denominator_delta':expected,'exact_line_set_verified':len(delta_lines),'exact_condition_set_verified':len(delta_cond),'toggle_directions_verified':sum(r['metric']=='toggle' for r in selected),'unexpected_exclusion_count':0,'covered_count_unchanged':True,'official_approval':False}
    # Unchanged historical inventory +141 prior +33 decision rows, disjoint by ID.
    with gzip.open(ROOT/'docs/verification/data/thermo5-final-exact-review/candidate_review_11419.csv.gz','rt') as f:old=list(csv.DictReader(f))
    prior=[r for r in csv.DictReader((ROOT/'docs/verification/data/thermo5-stalled-reset/exact_dispositions_231.csv').open()) if r['final_disposition']=='EXCLUSION_CANDIDATE']
    oldids={r['semantic_bin_id'] for r in old};priorids={r['semantic_bin_id'] for r in prior};newids={r['semantic_bin_id'] for r in rows}
    assert len(oldids)==11419 and len(priorids)==141 and len(newids)==33
    assert not (oldids&priorids or oldids&newids or priorids&newids)
    pack=[]
    for population,items in [('historical11419',old),('previous141',prior),('pr55_new33',rows)]:
        for r in items:pack.append({'semantic_bin_id':r['semantic_bin_id'],'population':population,'metric':r['metric'],'instance':r['instance'],'source_file':r['source_file'],'source_sha256':r['source_file_sha256'],'record_reference':('docs/verification/data/thermo5-final-exact-review/candidate_review_11419.csv.gz' if population=='historical11419' else 'docs/verification/data/thermo5-stalled-reset/exact_dispositions_231.csv' if population=='previous141' else 'docs/verification/data/thermo5-rtl-invariants/open87_review.csv'),'reviewer':'UNASSIGNED_INDEPENDENT','decision':'PENDING','approval_reference':'','official_waiver_ids':r.get('official_waiver_ids','')})
    with gzip.open(DATA/'approval_index_11593.csv.gz','wt',newline='') as f:w=csv.DictWriter(f,pack[0]);w.writeheader();w.writerows(pack)
    (DATA/'application_checks.json').write_text(json.dumps({'views':checks,'deduplicated_candidates':11593,'approved':0,'accepted_exceptions':0,'new_hits':0,'open87_official':87,'technical_unresolved':54},indent=2)+'\n')
    print('PASS:174 exact analysis effects;11593 unique pending IDs;no lost hits')
if __name__=='__main__':main()
